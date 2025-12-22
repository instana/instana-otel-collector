// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package spanintentprocessor // import "github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor"

import (
	"context"
	"fmt"
	"math/rand"
	"sync"
	"time"

	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/ptrace"
	"go.opentelemetry.io/collector/processor"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	"go.uber.org/zap"

	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor/cache"
	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor/internal/metadata"
	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor/internal/utility"
)

type spanIntentProcessor struct {
	ctx context.Context

        set       processor.Settings
        telemetry *metadata.TelemetryBuilder
        logger    *zap.Logger

	//logger          *zap.Logger
	//cfg             *Config
	nextConsumer    consumer.Traces
	mu              sync.Mutex
	tdigestMutex    sync.Mutex
	//traceDataBuffer map[pcommon.TraceID]*traceData
	tdigestMap      map[string]*utility.TDigest
	quantileEMAMap  map[string]*quantileEMA // smoothed q75/q95 for categorization
	emaAlpha        float64
	seenTraceIDs    map[pcommon.TraceID]struct{}
	sampledTraces   cache.Cache[bool]
	unsampledTraces cache.Cache[bool]
	samplingBiasNormal	float64
	samplingBiasDegraded	float64
	samplingBiasOutlier	float64
	samplingPercentage	float64
	rng          *rand.Rand
	stopCh          chan struct{}

	// Metrics instruments
	/*mSpansReceived           metric.Int64Counter
	mNewTraceIDReceived      metric.Int64Counter
	mTraceBufferSize         metric.Int64UpDownCounter
	mSampledCacheHits        metric.Int64Counter
	mSampledCacheMisses      metric.Int64Counter
	mUnsampledCacheHits      metric.Int64Counter
	mUnsampledCacheMisses    metric.Int64Counter
	mTracesClassifiedTotal   metric.Int64Counter
	mTracesSampled           metric.Int64Counter
	mTracesUnsampled         metric.Int64Counter
	mErrorsTotal             metric.Int64Counter
	mProcessingDuration      metric.Int64Histogram
	mSamplingDecisionLatency metric.Int64Histogram*/
}

type traceData struct {
	resourceAttrs pcommon.Map
	spans         []ptrace.Span
	maxLatency    float64
}

/*func newSpanIntentProcessor(
	logger *zap.Logger,
	cfg *Config,
	nextConsumer consumer.Traces,
	meter metric.Meter,
) (*spanIntentProcessor, error) {
	// Use processor ID from config for context/logging/metrics
	processorID := cfg.ID.String()*/
func newSpanIntentProcessor(ctx context.Context, set processor.Settings, nextConsumer consumer.Traces, cfg Config) (processor.Traces, error) {
        telemetrySettings := set.TelemetrySettings
        telemetry, err := metadata.NewTelemetryBuilder(telemetrySettings)
        if err != nil {
                return nil, err
        }

	//logger.Info("Starting spanintentprocessor", zap.String("id", processorID))

	// Create metric instruments from the meter
	/*mSpansReceived, err := meter.Int64Counter("processor.spanintent.spans_received")
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
	}*/

	nopCache := cache.NewNopDecisionCache[bool]()
        sampledCache := nopCache
        unsampledCache := nopCache
        if cfg.SampledTracesCacheSize > 0 {
                sampledCache, err = cache.NewLRUDecisionCache[bool](cfg.SampledTracesCacheSize)
                if err != nil {
                        return nil, err
                }
        }
        if cfg.UnsampledTracesCacheSize > 0 {
                unsampledCache, err = cache.NewLRUDecisionCache[bool](cfg.UnsampledTracesCacheSize)
                if err != nil {
                        return nil, err
                }
        }

	return &spanIntentProcessor{
		ctx:                ctx,
		set:                set,
		telemetry:          telemetry,
		logger:          telemetrySettings.Logger, //logger,
		//cfg:             cfg,
		nextConsumer:    nextConsumer,
		//traceDataBuffer: make(map[pcommon.TraceID]*traceData),
		tdigestMap:      make(map[string]*utility.TDigest),
		quantileEMAMap:  make(map[string]*quantileEMA),
		seenTraceIDs:	make(map[pcommon.TraceID]struct{}),
		emaAlpha:        0.8, // smoothing factor for latency categorization
		sampledTraces:   sampledCache,
		unsampledTraces: unsampledCache,
		samplingBiasNormal:	cfg.SamplingBias.Normal,
		samplingBiasDegraded:	cfg.SamplingBias.Degraded,
		samplingBiasOutlier:	cfg.SamplingBias.Outlier,
		samplingPercentage:	cfg.SamplingPercentage,
		rng: rand.New(rand.NewSource(time.Now().UnixNano())),
		stopCh:          make(chan struct{}),

		/*mSpansReceived:           mSpansReceived,
		mNewTraceIDReceived:      mNewTraceIDReceived,
		mTraceBufferSize:         mTraceBufferSize,
		mSampledCacheHits:        mSampledCacheHits,
		mSampledCacheMisses:      mSampledCacheMisses,
		mUnsampledCacheHits:      mUnsampledCacheHits,
		mUnsampledCacheMisses:    mUnsampledCacheMisses,
		mTracesClassifiedTotal:   mTracesClassifiedTotal,
		mTracesSampled:           mTracesSampled,
		mTracesUnsampled:         mTracesUnsampled,
		mErrorsTotal:             mErrorsTotal,
		mProcessingDuration:      mProcessingDuration,
		mSamplingDecisionLatency: mSamplingDecisionLatency,*/
	}, nil
}

type quantileEMA struct {
	Q25         float64
	Q75         float64
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

/*func (p *spanIntentProcessor) init() {
	p.seenTraceIDs = make(map[pcommon.TraceID]struct{})
	rand.Seed(time.Now().UnixNano())
}*/

func (p *spanIntentProcessor) processTraces(ctx context.Context, td ptrace.Traces) (ptrace.Traces, error) {
	resourceSpans := td.ResourceSpans()
	p.logger.Debug("Entering processTraces")

	// Initialize the categories
	normalSet := make(map[pcommon.TraceID]struct{})
	degradedSet := make(map[pcommon.TraceID]struct{})
	outlierSet := make(map[pcommon.TraceID]struct{})

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
				p.telemetry.ProcessorSpanintentSpansReceived.Add(ctx, 1) //p.mSpansReceived.Add(ctx, 1)

				p.mu.Lock()
				if sampled, ok := p.sampledTraces.Get(traceID); ok && sampled {
					p.telemetry.ProcessorSpanintentSampledCacheHits.Add(ctx, 1) //p.mSampledCacheHits.Add(ctx, 1)
					traceDataItem := getOrCreateTrace(traceID, resourceAttrs, tracesToForwardImmediately)
					traceDataItem.spans = append(traceDataItem.spans, span)
					p.mu.Unlock()
					continue
				}
				if unsampled, ok := p.unsampledTraces.Get(traceID); ok && unsampled {
					p.telemetry.ProcessorSpanintentUnsampledCacheHits.Add(ctx, 1) //p.mUnsampledCacheHits.Add(ctx, 1)
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
				// Apply Tukey's Fences to classify the latency data
				q25 := td.Quantile(0.25)
				q75 := td.Quantile(0.75)
				ema, exists := p.quantileEMAMap[key]
				if !exists {
					p.quantileEMAMap[key] = &quantileEMA{
						Q25:         q25,
						Q75:         q75,
						Initialized: true,
					}
				} else {
					alpha := p.emaAlpha
					ema.Q25 = alpha*q25 + (1-alpha)*ema.Q25
					ema.Q75 = alpha*q75 + (1-alpha)*ema.Q75
				}
				p.tdigestMutex.Unlock()

				// Check if the span is failed to categorize the trace
				if attr, ok := span.Attributes().Get("http.status_code"); ok {
					if attr.Type() == pcommon.ValueTypeInt && attr.Int() != 200 {
						outlierSet[traceID] = struct{}{}
						continue
					}
				}

				ema = p.quantileEMAMap[key]
				iqr := ema.Q75 -ema.Q25
				// Handle the initial span
				/*if  iqr == 0:
				{
					normalSet[traceID] = struct{}{}
					continue
				}*/
				innerFence := ema.Q75 + (1.5 * iqr)
				outerFence := ema.Q75 + (3.0 * iqr)

				// Categorization based on Tukey's Fences
				if ema, ok := p.quantileEMAMap[key]; ok && ema.Initialized && iqr != 0 {
					switch {
					case latencyMs < innerFence:
						normalSet[traceID] = struct{}{}
					case latencyMs > innerFence && latencyMs <= outerFence:
						degradedSet[traceID] = struct{}{}
					default:
						outlierSet[traceID] = struct{}{}
					}
				} else {
					normalSet[traceID] = struct{}{}
				}

			}
		}
	}

	p.processTracesForSampling(normalSet, degradedSet, outlierSet, tracesToProcess)

	for tid, data := range tracesToForwardImmediately {
		p.forwardTrace(tid, data.spans, data.resourceAttrs)
	}

	p.telemetry.ProcessorSpanintentSamplingDecisionLatency.Record(ctx, float64(time.Since(startTime)/time.Millisecond)) //p.mSamplingDecisionLatency.Record(ctx, int64(time.Since(startTime)/time.Millisecond))
	return td, nil
}

func (p *spanIntentProcessor) processTracesForSampling(
    normalSet, degradedSet, outlierSet map[pcommon.TraceID]struct{},
    tracesToProcess map[pcommon.TraceID]*traceData,
) {
    p.logger.Debug("Entering processTracesForSampling")

    // Step 1: De-duplication of trace IDs across categories
    for tid := range outlierSet {
        delete(normalSet, tid)
        delete(degradedSet, tid)
    }
    for tid := range degradedSet {
        delete(normalSet, tid)
    }

    // Update Metrics with the count in each category
    categories := map[string]map[pcommon.TraceID]struct{}{
        "normal":   normalSet,
        "degraded": degradedSet,
        "outlier":   outlierSet,
    }

    //p.mTracesClassifiedTotal.Add(context.Background(), int64(len(set)),
    for name, set := range categories {
        p.telemetry.ProcessorSpanintentTracesClassifiedTotal.Add(context.Background(), int64(len(set)),
            metric.WithAttributes(attribute.String("classification_category", name)))
    }

    /*biasMap := map[string]float64{
        "normal":   p.cfg.SamplingBias.Normal,
        "degraded": p.cfg.SamplingBias.Degraded,
        "failed":   p.cfg.SamplingBias.Failed,
    }*/
    biasMap := map[string]float64{
	    "normal":	p.samplingBiasNormal,
	    "degraded":	p.samplingBiasDegraded,
	    "outlier":	p.samplingBiasOutlier,
    }

    totalTraces := len(normalSet) + len(degradedSet) + len(outlierSet)
    if totalTraces == 0 {
        return
    }

    // Step 2: Calculate sampling budget
    totalBudget := int(float64(totalTraces) * p.samplingPercentage)
    if totalBudget == 0 {
        totalBudget = 1 // Always sample at least one if any traces exist
    }

    /*allocated := make(map[string]int)
    remainingBudget := totalBudget
    remainingBias := 0.0

    // Step 2a: Fully allocate bias==1 categories
    for label, traces := range categories {
        if biasMap[label] == 1 {
            allocated[label] = len(traces)
            remainingBudget -= len(traces)
        } else {
            remainingBias += biasMap[label]
        }
    }

    // Step 2b: Proportional allocation for others
    for label, traces := range categories {
        if biasMap[label] < 1 {
            alloc := int((biasMap[label] / remainingBias) * float64(remainingBudget))
            if alloc > len(traces) {
                alloc = len(traces)
            }
            allocated[label] = alloc
        }
    }*/

    allocated := make(map[string]int)
    remainingBudget := totalBudget
    remainingBias := 0.0

    for label, traces := range categories {
	    bias := biasMap[label]
	    if bias == 1 {
		    if remainingBudget >= len(traces) {
			    allocated[label] = len(traces)
			    remainingBudget -= len(traces)
		    } else {
			    allocated[label] = remainingBudget
			    remainingBudget = 0
		    }
	    } else {
		    remainingBias += bias
	    }
    }
    if remainingBudget > 0 && remainingBias > 0 {
	    for label, traces := range categories {
		    bias := biasMap[label]
		    if bias < 1 {
			    alloc := int((bias / remainingBias) * float64(remainingBudget))
			    if alloc > len(traces) {
				    alloc = len(traces)
			    }
			    allocated[label] = alloc
		    }
	    }
    }

    // Step 3: Random sampling per category
    for category, set := range categories {
        if len(set) == 0 {
            continue
        }

	categoryBudget := allocated[category]
        if categoryBudget == 0 {
            categoryBudget = 1
        }

        // Convert set to slice for random selection
        tids := make([]pcommon.TraceID, 0, len(set))
        for tid := range set {
            tids = append(tids, tid)
        }

        // Shuffle slice
        p.rng.Shuffle(len(tids), func(i, j int) { tids[i], tids[j] = tids[j], tids[i] })

        // Pick first `categoryBudget` traces
        for i, tid := range tids {
            trace := tracesToProcess[tid]
            if i < categoryBudget {
                p.sampledTraces.Put(tid, true)
		p.telemetry.ProcessorSpanintentTracesSampled.Add(context.Background(), 1, metric.WithAttributes(attribute.String("sampling_category", category),))
		p.telemetry.ProcessorSpanintentSpansSampled.Add(context.Background(), int64(len(trace.spans)), metric.WithAttributes(attribute.String("sampling_category", category),))
                //p.mTracesSampled.Add(context.Background(), 1, metric.WithAttributes(
                //    attribute.String("sampling_category", category),
                //))
                p.forwardTrace(tid, trace.spans, trace.resourceAttrs)
            } else {
                p.unsampledTraces.Put(tid, true)
		p.telemetry.ProcessorSpanintentTracesUnsampled.Add(context.Background(), 1, metric.WithAttributes(attribute.String("sampling_category", category),))
		p.telemetry.ProcessorSpanintentSpansUnsampled.Add(context.Background(), int64(len(trace.spans)), metric.WithAttributes(attribute.String("sampling_category", category),))
                /*p.mTracesUnsampled.Add(context.Background(), 1, metric.WithAttributes(
                    attribute.String("sampling_category", category),
                ))*/
            }
        }
    }
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
	p.logger.Debug("spanintentprocessor received traces")
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
		p.telemetry.ProcessorSpanintentErrorsTotal.Add(context.Background(), 1, metric.WithAttributes(attribute.String("error_type", "forwarding_failed")))
		//p.mErrorsTotal.Add(context.Background(), 1, metric.WithAttributes(attribute.String("error_type", "forwarding_failed")))
	}
}
