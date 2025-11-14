package spanintentprocessor // import "github.com/open-telemetry/opentelemetry-collector-contrib/processor/tailsamplingprocessor"

import (
	"context"

	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/processor"

	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor/internal/metadata"
)

var TypeStr = component.MustNewType("spanintentprocessor")

func NewFactory() processor.Factory {
	return processor.NewFactory(
		TypeStr, // pass component.Type, not string
		createDefaultConfig,
		processor.WithTraces(createTracesProcessor, metadata.TracesStability),
	)
}

func createDefaultConfig() component.Config {
	return &Config{
		Settings: processor.Settings{
			ID: component.NewID(TypeStr),
		},
		SamplingPercentage: 0.3,
		SamplingBias: SamplingBias{
			Normal:   0.3,
			Degraded: 1.0,
			Failed:   1.0,
		},
		SampledTracesCacheSize:   10000,
		UnsampledTracesCacheSize: 10000,
	}
}

func createTracesProcessor(
	ctx context.Context,
	settings processor.Settings, // use processor.Settings here
	cfg component.Config,
	nextConsumer consumer.Traces,
) (processor.Traces, error) {
	config := cfg.(*Config)

	// Pass settings.TelemetrySettings, not config.ID
	_, err := metadata.NewTelemetryBuilder(settings.TelemetrySettings)
	if err != nil {
		return nil, err
	}

	// Pass settings.Meter (implements metric.Meter) instead of telemetry
	meter := settings.MeterProvider.Meter(config.ID.String())
	return newSpanIntentProcessor(settings.Logger, config, nextConsumer, meter)
}
