// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

//go:generate mdatagen metadata.yaml

package spanintentprocessor // import "github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor"

import (
	"context"

	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/processor"

	"github.com/open-telemetry/opentelemetry-collector-contrib/processor/spanintentprocessor/internal/metadata"
)

// TypeStr is the component type for the spanintentprocessor.
//var TypeStr = component.MustNewType("spanintentprocessor")

// NewFactory creates a new factory for the spanintentprocessor.
func NewFactory() processor.Factory {
	return processor.NewFactory(
		metadata.Type, // pass component.Type, not string
		createDefaultConfig,
		processor.WithTraces(createSpanIntentProcessor, metadata.TracesStability),
	)
}

//Settings: processor.Settings{ID: component.NewID(TypeStr),},
// The default configuration for the spanintentprocessor.
func createDefaultConfig() component.Config {
	return &Config{
		SamplingPercentage: 0.3,
		SamplingBias: SamplingBias{
			Normal:   0.3,
			Degraded: 1.0,
			Outlier:   1.0,
		},
		SampledTracesCacheSize:   10000,
		UnsampledTracesCacheSize: 10000,
	}
}

func createSpanIntentProcessor(
	ctx context.Context,
	settings processor.Settings,
	cfg component.Config,
	nextConsumer consumer.Traces,
) (processor.Traces, error) {
	config := cfg.(*Config)

	/*_, err := metadata.NewTelemetryBuilder(settings.TelemetrySettings)
	if err != nil {
		return nil, err
	}

	// Pass settings.Meter (implements metric.Meter) instead of telemetry
	meter := settings.MeterProvider.Meter(config.ID.String())
	return newSpanIntentProcessor(settings.Logger, config, nextConsumer, meter)*/
	return newSpanIntentProcessor(ctx, settings, nextConsumer, *config)
}
