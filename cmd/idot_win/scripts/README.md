# Instana Distribution of OpenTelemetry Collector - Windows ZIP Package Installation Guide

## Overview

This package contains the Instana Distribution of OpenTelemetry Collector for Windows, distributed as a portable ZIP archive. The collector enables you to gather telemetry data (traces, metrics, and logs) from your applications and infrastructure and send it to Instana for monitoring and observability.

## System Requirements

- **Operating System**: Windows 10 or later, Windows Server 2016 or later
- **Architecture**: x64 (64-bit)
- **Permissions**: Administrator privileges recommended for full functionality
- **Network**: Outbound HTTPS access to Instana backend
- **PowerShell**: PowerShell 5.1 or later (included in Windows 10+)

## Quick Start

Get started in 2 minutes with this one-line command in windows PowerShell:

```powershell
$env:AGENT_KEY=<it's-a-key>
$env:OTLP_GRPC_ENDPOINT=<otlp-grpc-magenta-saas.instana.rocks:443>
$env:OTLP_HTTP_ENDPOINT=<otlp-http-magenta-saas.instana.rocks:443>
```

```powershell
Invoke-WebRequest -Uri "https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-windows-amd64.zip" -OutFile "$env:TEMP\instana-collector.zip"; Expand-Archive -Path "$env:TEMP\instana-collector.zip" -DestinationPath "C:\Program Files\Instana\" -Force; cd "C:\Program Files\Instana\instana-collector\bin"; .\setenv.bat -a YOUR_AGENT_KEY -e YOUR_GRPC_ENDPOINT -H YOUR_HTTP_ENDPOINT; .\start.bat
```

**Replace:**
- `YOUR_AGENT_KEY` - Your Instana agent key
- `YOUR_GRPC_ENDPOINT` - Your Instana gRPC endpoint (e.g., `otlp-grpc-orange-saas.instana.io:443`)
- `YOUR_HTTP_ENDPOINT` - Your Instana HTTP endpoint (e.g., `https://otlp-http-orange-saas.instana.io:443`)

---

## Step-by-Step Installation

Follow these steps for a detailed installation process:

### Step 1: Download and Extract

Download the latest release and extract to the installation directory:

```powershell
# Download
Invoke-WebRequest -Uri "https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-windows-amd64.zip" -OutFile "instana-collector.zip"

# Extract
Expand-Archive -Path "instana-collector.zip" -DestinationPath "C:\Program Files\Instana\"
```

### Step 2: Navigate to Installation Directory

```powershell
cd "C:\Program Files\Instana\instana-collector\bin"
```

### Step 3: Configure Environment

Use `setenv.bat` with command-line arguments:

```powershell
setenv.bat -a YOUR_AGENT_KEY -e YOUR_GRPC_ENDPOINT -H YOUR_HTTP_ENDPOINT
```

This automatically generates `config\config.env` with your settings.

### Step 4: Start the Collector

```powershell
start.bat
```

The collector will start in the background and begin collecting telemetry data.


### Step 5: Checking Status

```powershell
status.bat
```

Output will show either:
- `OpenTelemetry Collector status: RUNNING`
- `OpenTelemetry Collector status: STOPPED`

### Step 6: Stopping the Collector

```powershell
stop.bat
```

### Step 7: Viewing Logs

Logs are written to `logs\agent.log`. You can view them using:

```powershell
type ..\logs\agent.log
```

### Step 8: Viewing Collector in Instana UI

After installation, you can go to your settled instana endpoint with UI, landing from `Agents & collectors` -> `OpenTelemetry collectors` and filtering collectorID by add your hostname as keywords, and you are able to find it from the collector list, click your collector to check all the required metric data in the KPI page.

## Troubleshooting

### Collector Won't Start

1. **Check environment variables**: Ensure `INSTANA_KEY` and `INSTANA_OTEL_ENDPOINT_HTTP` are set in `setenv.bat`
2. **Verify configuration**: Check `config\config.yaml` for syntax errors
3. **Review logs**: Check `logs\agent.log` for error messages
4. **Test connectivity**: Ensure network access to Instana backend

### No Data in Instana

1. **Verify agent key**: Ensure `INSTANA_KEY` is correct
2. **Check endpoint**: Verify `INSTANA_OTEL_ENDPOINT_HTTP` is accessible
3. **Review configuration**: Ensure receivers and exporters are properly configured
4. **Check firewall**: Ensure outbound HTTPS traffic is allowed

### High Resource Usage

1. **Adjust collection interval**: Increase intervals in receiver configurations
2. **Enable memory limiter**: Uncomment and configure the memory_limiter processor
3. **Reduce log collection**: Limit file patterns in filelog receiver

### Common Error Messages

**"Failed to connect to backend"**
- Check network connectivity to Instana backend
- Verify endpoint URL and port
- Check firewall rules

**"Invalid agent key"**
- Verify `INSTANA_KEY` in `setenv.bat`
- Ensure key is active in Instana

**"Permission denied"**
- Run scripts as Administrator
- Check file permissions on installation directory

## Uninstallation

1. Stop the collector: `stop.bat`
2. If running as a service, remove the service (e.g., `nssm remove InstanaCollector`)
3. Delete the installation directory
4. Remove any environment variables or registry entries (if applicable)

## Support

For support and documentation:
- **Instana Documentation**: https://www.ibm.com/docs/en/instana-observability/current
- **OpenTelemetry Documentation**: https://opentelemetry.io/docs/collector/
- **GitHub Issues**: Report issues on the project repository