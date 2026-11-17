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

The **Instana Distribution of OpenTelemetry Collector** (IDOT) aims to bring a streamlined OpenTelemetry experience to the Instana ecosystem.

IDOT was built using the builder found on the [OpenTelemetry GitHub](https://github.com/open-telemetry/opentelemetry-collector) and follows the documentation found on the official [OpenTelemetry Website](https://opentelemetry.io/).

Visit the [IBM OpenTelemetry Documentation](https://www.ibm.com/docs/en/instana-observability/current?topic=apis-opentelemetry) page to learn more about Instana-OpenTelemetry synergy.

## Getting Started

#### Supported Architectures

The Instana Distribution of OpenTelemetry Collector supports the following architectures:

| OS      | Architectures                 |
|---------|-------------------------------|
| Linux   | x86-64 (amd64), s390x (IBM Z) |
| Windows | x86-64 (amd64)                |

### Linux Installation

The installation process is identical for both supported Linux architectures (amd64 and s390x/IBM Z). The only difference is the installer script you need to download.

#### Step 1: Download the appropriate installer for your architecture

**For x86-64/amd64 systems:**
```bash
curl -Lo instana_otelcol_setup.sh https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-amd64.sh
chmod +x instana_otelcol_setup.sh
```

**For s390x/zLinux systems:**
```bash
curl -Lo instana_otelcol_setup.sh https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-s390x.sh
chmod +x instana_otelcol_setup.sh
```

#### Step 2: Run the installer

The installation command as follows:

```bash
./instana_otelcol_setup.sh -e <INSTANA_OTEL_ENDPOINT_GRPC> -a <INSTANA_KEY> [-H <INSTANA_OTEL_ENDPOINT_HTTP>] [-u USE_SUPERVISOR_SERVICE] [<install_path>]
```

Where:
```
<INSTANA_OTEL_ENDPOINT_GRPC> # GRPC Endpoint for Instana. Format <ip_address>:<port>
<INSTANA_KEY>                # Key for authentication into Instana
<INSTANA_OTEL_ENDPOINT_HTTP> # HTTP Endpoint for Instana. Format <ip_address>:<port>
<USE_SUPERVISOR_SERVICE>     # Set as true by default to enable the collector supervisor feature, false will leave the supervisor disabled.
```

> [!NOTE] 
> `INSTANA_OTEL_ENDPOINT_GRPC` and `INSTANA_KEY` are required parameters to run the installer.

> [!NOTE]
> When installing on SLES for IBM Z, ensure you have the necessary dependencies installed for the collector to run properly.

The installation script will install and initiate the Instana Collector Service on your system using the parameters above.

These paramaters can be changed later in the `config.env` file found under `install_path/collector/config/config.env` (default is `/opt/instana/collector/config/config.env`)

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

### Kubernetes 

Visit [Kubernetes Deployment Guide](docs/k8s.md) for more information.

### Windows Installation

The Windows distribution is available as a portable ZIP archive for easy deployment.

#### Step 1: Download the Windows ZIP package

Download the latest Windows ZIP package from the releases page:

```powershell
# Download using PowerShell
Invoke-WebRequest -Uri "https://github.com/instana/instana-otel-collector/releases/latest/download/instana-collector-installer-latest.zip" -OutFile "instana-collector.zip"

# Extract the archive
Expand-Archive -Path "instana-collector.zip" -DestinationPath "C:\Program Files\Instana\"
```

Or download manually from: [GitHub Releases](https://github.com/instana/instana-otel-collector/releases/latest)

#### Step 2: Configure the collector

Edit `bin\setenv.bat` to configure your Instana connection:

```batch
REM Required: Your Instana agent key
set INSTANA_KEY=your-instana-key-here

REM Required: Instana backend endpoint (HTTP)
set INSTANA_OTEL_ENDPOINT_HTTP=https://your-instana-backend:4318

REM Optional: Service identification
set INSTANA_OTEL_SERVICE_NAME=my-service
set HOSTNAME=%COMPUTERNAME%
```

#### Step 3: Start the collector

Open Command Prompt as Administrator:

```cmd
cd "C:\Program Files\Instana\instana-collector\bin"
start.bat
```

#### Managing the Collector

The Windows package includes convenient batch scripts for managing the collector:

```cmd
REM Check collector status
status.bat

REM Stop the collector
stop.bat

REM View logs
type ..\logs\agent.log
```

For detailed Windows installation instructions, configuration examples, and troubleshooting, see the [Windows Installation Guide](tools/packaging/windows/README.md) included in the ZIP package.

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

## Target Allocator Support

The Target Allocator can be used with Prometheus-based scraping to distribute scrape targets across collector replicas. In this repository, the collector binary already includes Prometheus receiver support, while the chart documentation and examples describe how this can be wired with the StatefulSet collector tier.

**Documentation:**
- [Target Allocator Guide](docs/target-allocator.md) - Overview and setup guidance
- [Example Overlay](examples/target-allocator-example.yaml) - Additive example configuration

## OpAmp Support

Coming soon...

## Troubleshooting

For common issues and their solutions, please refer to our [troubleshooting guide](docs/troubleshooting.md). This guide covers installation problems, connectivity issues, and platform-specific troubleshooting steps.

## Uninstallation

The installation script adds an uninstallation script under `collector/bin` in `install_path`

Running this script will stop the Instana Collector Service and remove all collector files from the system.

## Contributing

Instana Distribution of OpenTelemetry Collector is an open source project and any contribution is welcome and appreciated.
