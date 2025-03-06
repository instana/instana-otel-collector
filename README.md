# Instana Distribution of OpenTelemetry Collector

![e2e-test](https://github.com/instana/instana-otel-collector/actions/workflows/test_build.yaml/badge.svg)
![Release](https://img.shields.io/github/v/release/instana/instana-otel-collector)

## Overview

The Instana Distibution of OpenTelemetry Collector aims to bring a streamlined OpenTelemetry experience to the Instana ecosystem.

## Getting Started

### Linux

On Linux machines, setup up can be done by downloading the latest release of the installer via the command:

```bash
curl -Lo instana_otelcol_setup.sh https://github.com/instana/instana-otel-collector/releases/download/v0.0.10/instana-collector-installer-v0.0.10.sh

chmod +x instana_otelcol_setup.sh
```

Once this has been downloaded, the installer script can be run by

```bash
./instana_otelcol_setup.sh -e <INSTANA_OTEL_ENDPOINT_GRPC> -a <INSTANA_KEY> [-H <INSTANA_OTEL_ENDPOINT_HTTP>] [<install_path>]
```

> [!NOTE] 
> `INSTANA_OTEL_ENDPOINT_GRPC` and `INSTANA_KEY` are required parameters to run the installer

The installation script will install and initiate the Instana Collector Service on your system using the parameters above.

These paramaters can be changed later in the `config.env` file found under `install_path` (default is `/opt/instana`)

### Windows

Coming soon...

### MacOS

Coming soon...

## Configuration and Setup

The collector can be fine tuned for your needs through the use of a `config.yaml` file. Based on the operating system the path will change:

| OS  | Default Path  |
|---|---|
| Linux   | `/opt/instana/collector/config.yaml`  |


## Supported Components

See the table below for links to supported components

| Component     |  Link                                                                                                  |
|---------------|--------------------------------------------------------------------------------------------------------|
| Receivers     | [Receiver List](https://github.com/instana/instana-otel-collector/blob/readme/docs/receivers.md)       |
| Processors    | [Processor List](https://github.com/instana/instana-otel-collector/blob/readme/docs/receivers.md)      |
| Exporters     | [Exporter List](https://github.com/instana/instana-otel-collector/blob/readme/docs/receivers.md)       |


## OpAmp Support

Coming soon...

## Uninstallation

The installation script adds an uninstallation script under `collector/bin` in `install_path`

Running this script will stop the Instana Collector Service and remove all collector files from the system.

## Contributing

Instana Distribution of OpenTelemetry Collector is an open source project and any contribution is welcome and appreciated.