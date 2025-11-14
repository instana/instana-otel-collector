package spanintentprocessor // import "github.com/open-telemetry/opentelemetry-collector-contrib/processor/tailsamplingprocessor"

import (
	"fmt"

	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/processor"
)

var typeStr = component.MustNewType("spanintentprocessor")

// SamplingBias controls the bias multipliers for different categories of traces.
type SamplingBias struct {
	Normal   float64 `mapstructure:"normal"`
	Degraded float64 `mapstructure:"degraded"`
	Failed   float64 `mapstructure:"failed"`
}

// Config defines the processor configuration.
type Config struct {
	processor.Settings `mapstructure:",squash"` // component.ProcessorSettings `mapstructure:",squash"`

	// SamplingPercentage is the base percentage of traces to sample (0.0 to 1.0)
	SamplingPercentage float64 `mapstructure:"sampling_percentage"`

	// SamplingBias controls the bias (percentage of traces from each category) for different categories of traces
	SamplingBias SamplingBias `mapstructure:"sampling_bias"`

	// Cache sizes for sampled and unsampled traces
	SampledTracesCacheSize   int `mapstructure:"sampled_traces_cache_size"`
	UnsampledTracesCacheSize int `mapstructure:"unsampled_traces_cache_size"`
}

func DefaultConfig() *Config {
	return &Config{
		Settings: processor.Settings{
			ID: component.NewID(typeStr),
		},
		SamplingPercentage:       0.3,
		SamplingBias:             SamplingBias{Normal: 0.3, Degraded: 1.0, Failed: 1.0},
		SampledTracesCacheSize:   10000,
		UnsampledTracesCacheSize: 10000,
	}
}

// Validate checks the configuration values for correctness.
func (cfg *Config) Validate() error {
	if cfg.SamplingPercentage < 0 || cfg.SamplingPercentage > 1 {
		return fmt.Errorf("sampling_percentage must be between 0.0 and 1.0")
	}
	if cfg.SamplingBias.Normal < 0 || cfg.SamplingBias.Normal > 1 {
		return fmt.Errorf("sampling_bias.normal must be between 0.0 and 1.0")
	}
	if cfg.SamplingBias.Degraded < 0 || cfg.SamplingBias.Degraded > 1 {
		return fmt.Errorf("sampling_bias.degraded must be between 0.0 and 1.0")
	}
	if cfg.SamplingBias.Failed < 0 || cfg.SamplingBias.Failed > 1 {
		return fmt.Errorf("sampling_bias.failed must be between 0.0 and 1.0")
	}
	if cfg.SampledTracesCacheSize <= 0 {
		return fmt.Errorf("sampled_traces_cache_size must be positive")
	}
	if cfg.UnsampledTracesCacheSize <= 0 {
		return fmt.Errorf("unsampled_traces_cache_size must be positive")
	}
	return nil
}
