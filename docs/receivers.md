# Receivers

List of supported receivers with their GitHub Reference

## OpenTelemetry Receivers

| Name                       | GitHub README                                                                                                                                         | Linux amd64 | Linux s390x | Windows | AIX |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | ----------- | ------- | --- |
| AWS CloudWatch Receiver    | [awscloudwatchreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/awscloudwatchreceiver/README.md)     | ✓           | ✓           | ✓       | ✓   |
| File Log Receiver          | [filelogreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/filelogreceiver/README.md)                 | ✓           | ✓           | ✓       | ✓   |
| Host Metrics Receiver      | [hostmetricsreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/hostmetricsreceiver/README.md)         | ✓           | ✓           | ✓       | ✓   |
| IIS Receiver               | [iisreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/iisreceiver/README.md)                         | –           | –           | ✓       | –   |
| Jaeger Receiver            | [jaegerreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/jaegerreceiver/README.md)                   | ✓           | ✓           | ✓       | ✓   |
| Journald Receiver          | [journaldreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/journaldreceiver/README.md)               | ✓           | ✓           | ✓       | ✓   |
| K8s Cluster Receiver       | [k8sclusterreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/k8sclusterreceiver/README.md)           | ✓           | ✓           | ✓       | ✓   |
| K8s Events Receiver        | [k8seventsreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/k8seventsreceiver/README.md)             | ✓           | ✓           | ✓       | ✓   |
| K8s Objects Receiver       | [k8sobjectsreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/k8sobjectsreceiver/README.md)           | ✓           | ✓           | ✓       | ✓   |
| Kubelet Stats Receiver     | [kubeletstatsreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/kubeletstatsreceiver/README.md)       | ✓           | ✓           | ✓       | ✓   |
| OTLP Receiver              | [otlpreceiver](https://github.com/open-telemetry/opentelemetry-collector/blob/v0.134.0/receiver/otlpreceiver/README.md)                               | ✓           | ✓           | ✓       | ✓   |
| PostgreSQL Receiver        | [postgresqlreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/postgresqlreceiver/README.md)           | ✓           | ✓           | ✓       | ✓   |
| Prometheus Receiver        | [prometheusreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/prometheusreceiver/README.md)           | ✓           | ✓           | ✓       | –   |
| SQL Query Receiver         | [sqlqueryreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/sqlqueryreceiver/README.md)               | ✓           | ✓           | ✓       | ✓   |
| StatsD Receiver            | [statsdreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/statsdreceiver/README.md)                   | ✓           | ✓           | ✓       | ✓   |
| Windows Event Log Receiver | [windowseventlogreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/windowseventlogreceiver/README.md) | ✓           | ✓           | ✓       | ✓   |
| Zipkin Receiver            | [zipkinreceiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.134.0/receiver/zipkinreceiver/README.md)                   | ✓           | ✓           | ✓       | ✓   |

## Instana Custom Receivers

| Name                 | GitHub README                                                                                                           | Linux amd64 | Linux s390x | Windows | AIX |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------- | ----------- | ----------- | ------- | --- |
| API Scraper Receiver | [apiscraperreceiver](https://github.com/instana/instana-otel-collector/blob/main/receiver/apiscraperreceiver/README.md) | ✓           | ✓           | –       | –   |
| s390 Receiver        | [s390receiver](https://github.com/instana/instana-otel-collector/blob/main/receiver/s390receiver/README.md)             | –           | ✓           | –       | –   |
| Shell Receiver       | [shellreceiver](https://github.com/instana/instana-otel-collector/blob/main/receiver/shellreceiver/README.md)           | ✓           | ✓           | ✓       | ✓   |
