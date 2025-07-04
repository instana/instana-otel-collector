# Instana Distribution of OpenTelemetry Collector

<!-- Instana Logo -->
<a href="https://www.ibm.com/products/instana">
    <p align="center">
        <img src="docs/assets/instana-logo.png">
    </p>
</a>

<!-- Badges -->
<p align="center">
  <a href="https://github.com/instana/instana-otel-collector/actions/workflows/test_build.yaml">
    <img src="https://github.com/instana/instana-otel-collector/workflows/Run End to End Tests/badge.svg" alt="Build Status" />
  </a>
  <a href="https://github.com/instana/instana-otel-collector/releases/latest">
    <img src="https://img.shields.io/github/v/release/instana/instana-otel-collector.svg?style-for-the-badge&color=05b5b3" alt="Latest Release" />
  </a>
</p>

## Overview

The **Instana Distibution of OpenTelemetry Collector** (IDOT) aims to bring a streamlined OpenTelemetry experience to the Instana ecosystem.

IDOT was built using the builder found on the [OpenTelemetry GitHub](https://github.com/open-telemetry/opentelemetry-collector) and follows the documentation found on the official [OpenTelemetry Website](https://opentelemetry.io/).

Visit the [IBM OpenTelemetry Documentation](https://www.ibm.com/docs/en/instana-observability/current?topic=apis-opentelemetry) page to learn more about Instana-OpenTelemetry synergy.

## Getting Started

### Linux

On Linux machines, setup up can be done by downloading the latest release of the installer via the command:

```bash
curl -Lo instana_otelcol_setup.sh https://github.com/instana/instana-otel-collector/releases/latest/download/instana-collector-installer-latest.sh

chmod +x instana_otelcol_setup.sh
```

Once this has been downloaded, the installer script can be run by

```bash
./instana_otelcol_setup.sh -e <INSTANA_OTEL_ENDPOINT_GRPC> -a <INSTANA_KEY> [-H <INSTANA_OTEL_ENDPOINT_HTTP>] [-m INSTANA_METRICS_ENDPOINT] [-u USE_SUPERVISOR_SERVICE] [<install_path>]
```

> [!NOTE] 
> `INSTANA_OTEL_ENDPOINT_GRPC` and `INSTANA_KEY` are required parameters to run the installer.

> [!NOTE] 
> `USE_SUPERVISOR_SERVICE` is set as `true` by default, set to `false` if supervisor is undesired.

The installation script will install and initiate the Instana Collector Service on your system using the parameters above.

These paramaters can be changed later in the `config.env` file found under `install_path` (default is `/opt/instana/collector/config/config.env`)

#### Instana Collector Service

By default the installer will install and start the service. However, there are a few parameters to choose from when interacting with the Instana Collector Service. Each of these all run the corresponding `systemd` commands in a user friendly manner. Run these commands under the `bin` folder within the `install_path` (default is `/opt/instana/collector/bin`).

```bash
./instana_collector_service.sh install # Will install the service (done automatically by installation script)

./instana_collector_service.sh uninstall # Uninstall the service (done automatically by uninstallation script)

./instana_collector_service.sh status # Display the activity status of the collector service

./instana_collector_service.sh start # Initiate the collector service

./instana_collector_service.sh stop # Stop the collector service

./instana_collector_service.sh restart # Restart the collector service
```

Additionally, the `service` command can be used here as well.

```bash
service instana-collector start # Start collector service

service instana-collector stop # Stop collector service

service instana-collector restart # Restart collector service

service instana-collector status # Display status of collector service
```

#### Instana Supervisor Service

> [!NOTE] 
> If `USE_SUPERVISOR_SERVICE` is set as `false` during installation, skip this section.

The `Instana Supervisor Service` works akin to the `Instana Collector Service` and supports the same commands, however does not support management through the `service` keyword.

```bash
./instana_supervisor_service.sh install # Will install the service (done automatically by installation script if false isn't specified for USE_SUPERVISOR_SERVICE)

./instana_supervisor_service.sh uninstall # Uninstall the service (done automatically by uninstallation script)

./instana_supervisor_service.sh status # Display the activity status of the supervisor service

./instana_supervisor_service.sh start # Initiate the supervisor service

./instana_supervisor_service.sh stop # Stop the supervisor service

./instana_supervisor_service.sh restart # Restart the supervisor service
```

### Windows

Coming soon...

### MacOS

Coming soon...

## Configuration and Setup

The collector can be fine tuned for your needs through the use of a `config.yaml` file. Based on the operating system the path will change:

| OS      | Default Path                                 |
|---------|----------------------------------------------|
| Linux   | `/opt/instana/collector/config/config.yaml`  |


Pipelines for Telemetry Data can be defined and altered as needed. For example, a simple pipeline for log data can be defined as follows:

```yaml
receivers:
    # Specifies a file log receiver to include logs from a given path
    filelog:
        include: ["path/to/logs/*.log"]
processors:
    # Specify a transform processor to add a processed attribute to the log
    transform:
        log_statements:
            - set(log.body, log.attributes["processed"])
exporters:
    # Configure an otlp exporter for this log data to be sent to
    otlp:
        endpoint: YOURENDPOINT

# Assemble the data pipeline from the configured components
services:
    pipelines:
        logs:
            receivers: [filelog]
            processors: [transform]
            exporters: [otlp]
```

## Supported Components

See the table below for links to supported components

| Component     |  Link                                                                                                  |
|---------------|--------------------------------------------------------------------------------------------------------|
| Receivers     | [Receiver List](https://github.com/instana/instana-otel-collector/blob/main/docs/receivers.md)     |
| Processors    | [Processor List](https://github.com/instana/instana-otel-collector/blob/main/docs/processors.md)   |
| Exporters     | [Exporter List](https://github.com/instana/instana-otel-collector/blob/main/docs/exporters.md)     |
| Extensions    | [Extensions List](https://github.com/instana/instana-otel-collector/blob/main/docs/extensions.md)  |
| Providers     | [Provider List](https://github.com/instana/instana-otel-collector/blob/main/docs/providers.md)      |

## OpAmp Support

Coming soon...

## Uninstallation

The installation script adds an uninstallation script under `collector/bin` in `install_path`

Running this script will stop the Instana Collector Service and remove all collector files from the system.

## Contributing

Instana Distribution of OpenTelemetry Collector is an open source project and any contribution is welcome and appreciated.
