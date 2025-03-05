# instana-otel-collector


## Overview

The Instana Distibution of OpenTelemetry Collector aims to bring a streamlined OpenTelemetry experience to the Instana ecosystem.

## Getting Started

### Linux

On Linux machines, setup up can be done by downloading the latest release of the installer via the command:

```
curl -Lo instana_otelcol_setup.sh https://github.com/instana/instana-otel-collector/releases/download/v0.0.10/instana-collector-installer-v0.0.10.sh

chmod +x instana_otelcol_setup.sh
```

Once this has been downloaded, the installer script can be run by

```
./instana_otelcol_setup.sh -e <INSTANA_OTEL_ENDPOINT_GRPC> -a <INSTANA_KEY> [-H <INSTANA_OTEL_ENDPOINT_HTTP>] [<install_path>]
```

`INSTANA_OTEL_ENDPOINT_GRPC` and `INSTANA_KEY` are required parameters to run the installer

The installation script will install and initiate the Instana Collector Service on your system using the parameters above.

These paramaters can be changed later in the `config.env` file found under `install_path` (default is `/opt/instana`)


### Windows

Coming soon...

### MacOS

Coming soon...