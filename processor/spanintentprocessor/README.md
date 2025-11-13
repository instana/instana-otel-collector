# SpanIntent Processor

The **SpanIntent Processor** samples traces based on span-level behaviors, guided by predefined sampling policies. The processor’s core principle is that a trace’s importance—its ability to represent real application usage—is derived from the characteristics of its spans. Traces are classified as **normal**, **degraded**, or **failed** according to span latency and error patterns.

## Overview

Modern distributed systems generate enormous volumes of tracing data, making it impractical to retain every trace.
Conventional sampling approaches often overlook traces that reflect genuine performance degradation or user-facing failures.

The **SpanIntent Processor** introduces *intent-aware* sampling, emphasizing trace significance from the end-user perspective. Unlike the standard probabilistic sampler, it does not rely on uniform, rate-based selection. And unlike the tail sampling processor, it makes sampling decisions without reconstructing full end-to-end traces, resulting in significantly lower computational overhead.

Since the significance of a trace can be effectively inferred from its constituent spans, a key anticipated advantage of the proposed **SpanIntent processor** is that it could potentially be deployed in the client environment—either on the host or within the proxy, depending on deployment semantics—while still enabling intelligent trace sampling based on span information, in addition to possible deployment on the backend.

## Configuration
Please refer to [config.go](./config.go) for the config spec.

The following configuration options are required:
- `sampling_percentage`: The base percentage of traces to sample, expressed as a value between 0.0 and 1.0
- `sampling_bias`: Defines bias multipliers for different categories of traces (e.g., to prioritize degraded or failed traces over normal ones).
	- `normal`: The proportion of normal traces to be sampled, as determined by the configured sampling_percentage
	- `degraded`: The proportion of degraded traces to be sampled, as determined by the configured sampling_percentage
	- `failed`: The proportion of failed traces to be sampled, as determined by the configured sampling_percentage
- `sampled_traces_cache_size`: The maximum size of the cache for sampled traces, used to prevent reprocessing traces already selected for sampling.
- `unsampled_traces_cache_size`: The maximum size of the cache for unsampled traces, used to skip traces previously determined to be excluded from sampling.


## Examples
Example configuration for adding the processor to a pipeline:
```yaml
processors:
  spanintentprocessor:
    sampling_percentage: 0.1
    sampling_bias:
      normal: 0.999
      degraded: 0.999
      failed: 0.999
    sampled_traces_cache_size: 1000
    unsampled_traces_cache_size: 1000

```
