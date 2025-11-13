package spanintentprocessor

import (
	"context"
	"fmt"
	"math"
	"math/rand"
	"sort"
	"sync"
	"time"

	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/ptrace"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.uber.org/zap"

	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor/cache"
	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor/internal/utility"
)

type spanIntentProcessor struct {
	logger          *zap.Logger
	cfg             *Config
	nextConsumer    consumer.Traces
	mu              sync.Mutex
	tdigestMutex    sync.Mutex
	traceDataBuffer map[pcommon.TraceID]*traceData
	tdigestMap      map[string]*utility.TDigest
	quantileEMAMap  map[string]*quantileEMA // smoothed q75/q95 for categorization
	emaAlpha        float64
	seenTraceIDs    map[pcommon.TraceID]struct{}
	sampledTraces   cache.Cache[bool]
	unsampledTraces cache.Cache[bool]
	stopCh          chan struct{}

	// Metrics instruments
	mSpansReceived           metric.Int64Counter
	mNewTraceIDReceived      metric.Int64Counter
	mTraceBufferSize         metric.Int64UpDownCounter
	mSampledCacheHits        metric.Int64Counter
	mSampledCacheMisses      metric.Int64Counter
	mUnsampledCacheHits      metric.Int64Counter
	mUnsampledCacheMisses    metric.Int64Counter
	mTracesClassifiedTotal   metric.Int64Counter
	mTracesProcessed         metric.Int64Counter
	mTracesSampled           metric.Int64Counter
	mTracesUnsampled         metric.Int64Counter
	mErrorsTotal             metric.Int64Counter
	mProcessingDuration      metric.Int64Histogram
	mSamplingDecisionLatency metric.Int64Histogram
}

type traceData struct {
	resourceAttrs pcommon.Map
	spans         []ptrace.Span
}

func newSpanIntentProcessor(
	logger *zap.Logger,
	cfg *Config,
	nextConsumer consumer.Traces,
	meter metric.Meter,
) (*spanIntentProcessor, error) {
	// Use processor ID from config for context/logging/metrics
	processorID := cfg.ID.String()
	logger.Info("Starting spanintentprocessor", zap.String("id", processorID))

	// Create metric instruments from the meter
	mSpansReceived, err := meter.Int64Counter("processor.spanintent.spans_received")
	if err != nil {
		return nil, err
	}
	mNewTraceIDReceived, err := meter.Int64Counter("processor.spanintent.new_trace_id_received")
	if err != nil {
		return nil, err
	}
	mTraceBufferSize, err := meter.Int64UpDownCounter("processor.spanintent.trace_buffer_size")
	if err != nil {
		return nil, err
	}
	mSampledCacheHits, err := meter.Int64Counter("processor.spanintent.sampled_cache_hits")
	if err != nil {
		return nil, err
	}
	mSampledCacheMisses, err := meter.Int64Counter("processor.spanintent.sampled_cache_misses")
	if err != nil {
		return nil, err
	}
	mUnsampledCacheHits, err := meter.Int64Counter("processor.spanintent.unsampled_cache_hits")
	if err != nil {
		return nil, err
	}
	mUnsampledCacheMisses, err := meter.Int64Counter("processor.spanintent.unsampled_cache_misses")
	if err != nil {
		return nil, err
	}
	mTracesClassifiedTotal, err := meter.Int64Counter("processor.spanintent.traces_classified_total")
	if err != nil {
		return nil, err
	}
	mTracesProcessed, err := meter.Int64Counter("processor.spanintent.traces_processed")
	if err != nil {
		return nil, err
	}
	mTracesSampled, err := meter.Int64Counter("processor.spanintent.traces_sampled")
	if err != nil {
		return nil, err
	}
	mTracesUnsampled, err := meter.Int64Counter("processor.spanintent.traces_unsampled")
	if err != nil {
		return nil, err
	}
	mErrorsTotal, err := meter.Int64Counter("processor.spanintent.errors_total")
	if err != nil {
		return nil, err
	}
	mProcessingDuration, err := meter.Int64Histogram("processor.spanintent.processing_duration_ms")
	if err != nil {
		return nil, err
	}
	mSamplingDecisionLatency, err := meter.Int64Histogram("processor.spanintent.sampling_decision_latency_us")
	if err != nil {
		return nil, err
	}

	sampledCache, err := cache.NewCache[bool](cfg.SampledTracesCacheSize)
	if err != nil {
		return nil, err
	}
	unsampledCache, err := cache.NewCache[bool](cfg.UnsampledTracesCacheSize)
	if err != nil {
		return nil, err
	}

	return &spanIntentProcessor{
		logger:          logger,
		cfg:             cfg,
		nextConsumer:    nextConsumer,
		traceDataBuffer: make(map[pcommon.TraceID]*traceData),
		tdigestMap:      make(map[string]*utility.TDigest),
		quantileEMAMap:  make(map[string]*quantileEMA),
		emaAlpha:        0.8, // smoothing factor for latency categorization
		sampledTraces:   sampledCache,
		unsampledTraces: unsampledCache,
		stopCh:          make(chan struct{}),

		mSpansReceived:           mSpansReceived,
		mNewTraceIDReceived:      mNewTraceIDReceived,
		mTraceBufferSize:         mTraceBufferSize,
		mSampledCacheHits:        mSampledCacheHits,
		mSampledCacheMisses:      mSampledCacheMisses,
		mUnsampledCacheHits:      mUnsampledCacheHits,
		mUnsampledCacheMisses:    mUnsampledCacheMisses,
		mTracesClassifiedTotal:   mTracesClassifiedTotal,
		mTracesProcessed:         mTracesProcessed,
		mTracesSampled:           mTracesSampled,
		mTracesUnsampled:         mTracesUnsampled,
		mErrorsTotal:             mErrorsTotal,
		mProcessingDuration:      mProcessingDuration,
		mSamplingDecisionLatency: mSamplingDecisionLatency,
	}, nil
}

type quantileEMA struct {
	Q75         float64
	Q95         float64
	Initialized bool
}

func (p *spanIntentProcessor) Start(ctx context.Context, host component.Host) error {
	// go p.runTickLoop()
	p.logger.Info("Processor Started: spanintentprocessor")
	return nil
}

func (p *spanIntentProcessor) Shutdown(ctx context.Context) error {
	close(p.stopCh)
	return nil
}

func (p *spanIntentProcessor) init() {
	p.seenTraceIDs = make(map[pcommon.TraceID]struct{})
	rand.Seed(time.Now().UnixNano())
}

func (p *spanIntentProcessor) processTraces(ctx context.Context, td ptrace.Traces) (ptrace.Traces, error) {
	resourceSpans := td.ResourceSpans()
	p.logger.Info("Entering processTraces")

	// Initialize the categories
	normalSet := make(map[pcommon.TraceID]struct{})
	degradedSet := make(map[pcommon.TraceID]struct{})
	failedSet := make(map[pcommon.TraceID]struct{})

	tracesToProcess := make(map[pcommon.TraceID]*traceData)
	tracesToForwardImmediately := make(map[pcommon.TraceID]*traceData)

	startTime := time.Now()

	for i := 0; i < resourceSpans.Len(); i++ {
		rs := resourceSpans.At(i)
		resourceAttrs := rs.Resource().Attributes()
		ils := rs.ScopeSpans()

		for j := 0; j < ils.Len(); j++ {
			spans := ils.At(j).Spans()

			for k := 0; k < spans.Len(); k++ {
				span := spans.At(k)
				traceID := span.TraceID()
				p.mSpansReceived.Add(ctx, 1)

				p.mu.Lock()
				if sampled, ok := p.sampledTraces.Get(traceID); ok && sampled {
					p.mSampledCacheHits.Add(ctx, 1)
					traceDataItem := getOrCreateTrace(traceID, resourceAttrs, tracesToForwardImmediately)
					traceDataItem.spans = append(traceDataItem.spans, span)
					p.mu.Unlock()
					continue
				}
				if unsampled, ok := p.unsampledTraces.Get(traceID); ok && unsampled {
					p.mUnsampledCacheHits.Add(ctx, 1)
					p.mu.Unlock()
					continue
				}

				traceDataItem := getOrCreateTrace(traceID, resourceAttrs, tracesToProcess)
				traceDataItem.spans = append(traceDataItem.spans, span)
				p.mu.Unlock()
				
				// Analyze the span latencies and categorize based on the quantile
				serviceName := "unknown"
				if attr, ok := traceDataItem.resourceAttrs.Get("service.name"); ok && attr.Type() == pcommon.ValueTypeStr {
					serviceName = attr.Str()
				}

				key := fmt.Sprintf("%s_%s", serviceName, span.Name())
				latencyMs := float64(span.EndTimestamp()-span.StartTimestamp()) / 1e6

				p.tdigestMutex.Lock()

				td, ok := p.tdigestMap[key]
				if !ok {
					td = utility.NewTDigest(100)
					p.tdigestMap[key] = td
				}
				td.Add(latencyMs, 1)
				q75 := td.Quantile(0.75)
				q95 := td.Quantile(0.95)
				ema, exists := p.quantileEMAMap[key]
				if !exists {
					p.quantileEMAMap[key] = &quantileEMA{
						Q75:         q75,
						Q95:         q95,
						Initialized: true,
					}
				} else {
					alpha := p.emaAlpha
					ema.Q75 = alpha*q75 + (1-alpha)*ema.Q75
					ema.Q95 = alpha*q95 + (1-alpha)*ema.Q95
				}
				p.tdigestMutex.Unlock()

				// Check if the span is failed to categorize the trace
				if attr, ok := span.Attributes().Get("http.status_code"); ok {
					if attr.Type() == pcommon.ValueTypeInt && attr.Int() != 200 {
						failedSet[traceID] = struct{}{}
						continue
					}
				}

				if ema, ok := p.quantileEMAMap[key]; ok && ema.Initialized {
					switch {
					case latencyMs < ema.Q75:
						normalSet[traceID] = struct{}{}
					case latencyMs < ema.Q95:
						degradedSet[traceID] = struct{}{}
					default:
						failedSet[traceID] = struct{}{}
					}
				} else {
					normalSet[traceID] = struct{}{}
				}

			}
		}
	}

	p.processTracesForSampling(normalSet, degradedSet, failedSet, tracesToProcess)

	for tid, data := range tracesToForwardImmediately {
		p.forwardTrace(tid, data.spans, data.resourceAttrs)
	}

	p.mSamplingDecisionLatency.Record(ctx, int64(time.Since(startTime)/time.Millisecond))
	return td, nil
}

func (p *spanIntentProcessor) processTracesForSampling(
	normalSet, degradedSet, failedSet map[pcommon.TraceID]struct{},
	tracesToProcess map[pcommon.TraceID]*traceData,
) {
	p.logger.Info("Entering processTracesForSampling")

	// Step 1: De-duplication of trace IDs across categories
	for tid := range failedSet {
		delete(normalSet, tid)
		delete(degradedSet, tid)
	}
	for tid := range degradedSet {
		delete(normalSet, tid)
	}

	// Update Metrics with the count in each category
	p.mTracesClassifiedTotal.Add(context.Background(), int64(len(normalSet)),
		metric.WithAttributes(attribute.String("classification_category", "normal")))
	p.mTracesClassifiedTotal.Add(context.Background(), int64(len(degradedSet)),
		metric.WithAttributes(attribute.String("classification_category", "degraded")))
	p.mTracesClassifiedTotal.Add(context.Background(), int64(len(failedSet)),
		metric.WithAttributes(attribute.String("classification_category", "failed")))

	categorySets := map[string]map[pcommon.TraceID]struct{}{
		"normal":   normalSet,
		"degraded": degradedSet,
		"failed":   failedSet,
	}

	// Step 2: Initialize t-digests per category for better latency range representation
	digests := map[string]*utility.TDigest{
		"normal":   utility.NewTDigest(),
		"degraded": utility.NewTDigest(),
		"failed":   utility.NewTDigest(),
	}

	// Step 3: Process each category to sample the traces
	for category, set := range categorySets {
		if len(set) == 0 {
			continue
		}

		traceMaxLatency := make(map[pcommon.TraceID]float64)
		digest := digests[category]

		// Compute max latency per trace and add to digest
		for tid := range set {
			trace := tracesToProcess[tid]
			maxLatency := 0.0
			for _, span := range trace.spans {
				latency := float64(span.EndTimestamp()-span.StartTimestamp()) / 1e6
				if latency > maxLatency {
					maxLatency = latency
				}
			}
			traceMaxLatency[tid] = maxLatency
			digest.Add(maxLatency, 1)
		}

		if digest.Count() == 0 {
			continue
		}

		// Dynamically determine number of bins (2–6) based on latency quantile heuristic (to be robust)
		minBins, maxBins := 2, 6

		// Use digest quantiles to assess spread and skew
		p10 := digest.Quantile(0.10)
		p50 := digest.Quantile(0.50)
		p90 := digest.Quantile(0.90)

		// Compute a normalized spread ratio relative to median latency
		spreadRatio := (p90 - p10) / (p50 + 1e-9)

		// Normalize spreadRatio roughly into [0, 1] range
		// Once the 90th percentile is about 1.5× further from the 10th percentile than the median, that’s already high variability
		spreadNorm := math.Min(spreadRatio/1.5, 1.0)

		// Map normalized spread to dynamic number of bins
		numBins := minBins + int(math.Round(spreadNorm*float64(maxBins-minBins)))
		if numBins < minBins {
			numBins = minBins
		}
		if numBins > maxBins {
			numBins = maxBins
		}

		// Compute bin edges using t-digest quantiles
		binEdges := make([]float64, numBins+1)
		for i := 0; i <= numBins; i++ {
			q := float64(i) / float64(numBins)
			binEdges[i] = digest.Quantile(q)
		}

		// Step 4: Assign traces to bins
		bins := make([][]pcommon.TraceID, numBins)
		for tid, lat := range traceMaxLatency {
			idx := numBins - 1
			for i := 0; i < numBins; i++ {
				if lat <= binEdges[i+1] {
					idx = i
					break
				}
			}
			bins[idx] = append(bins[idx], tid)
		}

		// Step 5: Sampling with weighted bias per bin
		totalTracesInCategory := len(set)
		categoryBudget := int(float64(totalTracesInCategory) * p.cfg.SamplingPercentage)
		if categoryBudget == 0 {
			categoryBudget = 1
		}

		// Latency bias factor
		BETA := 0.25

		for binIdx, bin := range bins {
			if len(bin) == 0 {
				continue
			}

			// Determine bin budget proportional to bin size
			binBudget := int(math.Max(1,
				math.Round(float64(categoryBudget)*float64(len(bin))/float64(totalTracesInCategory))))

			// Compute weighted probabilities based on latency
			maxLatency := 0.0
			for _, tid := range bin {
				if traceMaxLatency[tid] > maxLatency {
					maxLatency = traceMaxLatency[tid]
				}
			}

			weights := make([]float64, len(bin))
			for i, tid := range bin {
				lat := traceMaxLatency[tid]
				weights[i] = math.Max((1.0-BETA)+BETA*(lat/maxLatency), 0.01)
			}

			// Weighted reservoir sampling
			selected := weightedSample(bin, weights, binBudget)

			// Update the metrics to mark sampled and unsampled traces
			for _, tid := range bin {
				if selected[tid] {
					p.sampledTraces.Put(tid, true)
					p.mTracesSampled.Add(context.Background(), 1, metric.WithAttributes(
						attribute.String("sampling_category", category),
						attribute.Int("latency_bin", binIdx),
					))
					trace := tracesToProcess[tid]
					p.forwardTrace(tid, trace.spans, trace.resourceAttrs)
				} else {
					p.unsampledTraces.Put(tid, true)
					p.mTracesUnsampled.Add(context.Background(), 1, metric.WithAttributes(
						attribute.String("sampling_category", category),
						attribute.Int("latency_bin", binIdx),
					))
				}
			}
		}
	}
}

// Function to perform weighted random sampling
func weightedSample(traces []pcommon.TraceID, weights []float64, k int) map[pcommon.TraceID]bool {
	selected := make(map[pcommon.TraceID]bool)
	if k >= len(traces) {
		for _, tid := range traces {
			selected[tid] = true
		}
		return selected
	}

	// Weighted roulette selection
	totalWeight := 0.0
	cumWeights := make([]float64, len(weights))
	for i, w := range weights {
		totalWeight += w
		cumWeights[i] = totalWeight
	}

	rand.Seed(time.Now().UnixNano())
	for len(selected) < k {
		r := rand.Float64() * totalWeight
		idx := sort.Search(len(cumWeights), func(i int) bool { return cumWeights[i] >= r })
		if idx >= 0 && idx < len(traces) {
			selected[traces[idx]] = true
		}
	}
	return selected
}

func getOrCreateTrace(
	traceID pcommon.TraceID,
	resourceAttrs pcommon.Map,
	traceMap map[pcommon.TraceID]*traceData,
) *traceData {
	if data, exists := traceMap[traceID]; exists {
		return data
	}

	attrCopy := pcommon.NewMap()
	resourceAttrs.CopyTo(attrCopy)

	traceDataItem := &traceData{
		resourceAttrs: attrCopy,
		spans:         []ptrace.Span{},
	}

	traceMap[traceID] = traceDataItem
	return traceDataItem
}

func (p *spanIntentProcessor) Capabilities() consumer.Capabilities {
	return consumer.Capabilities{MutatesData: true}
}

func (p *spanIntentProcessor) ConsumeTraces(ctx context.Context, td ptrace.Traces) error {
	p.logger.Info("spanintentprocessor received traces")
	_, err := p.processTraces(ctx, td)
	return err
}

func (p *spanIntentProcessor) forwardTrace(traceID pcommon.TraceID, spans []ptrace.Span, resourceAttrs pcommon.Map) {
	td := ptrace.NewTraces()
	rs := td.ResourceSpans().AppendEmpty()
	resourceAttrs.CopyTo(rs.Resource().Attributes())

	ilss := rs.ScopeSpans().AppendEmpty()
	spansSlice := ilss.Spans()
	for _, span := range spans {
		span.CopyTo(spansSlice.AppendEmpty())
	}
	if err := p.nextConsumer.ConsumeTraces(context.Background(), td); err != nil {
		p.logger.Warn("failed to forward trace", zap.Error(err))
		p.mErrorsTotal.Add(context.Background(), 1, metric.WithAttributes(attribute.String("error_type", "forwarding_failed")))
	}
}
