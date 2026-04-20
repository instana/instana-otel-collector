# Windows Packaging for Instana OTel Collector

This directory contains all the necessary files and scripts to build a Windows MSI installer for the Instana Distribution of OpenTelemetry Collector.

## Overview

The Windows packaging creates a professional MSI installer that:
- Installs the Instana OTel Collector as a Windows service
- Optionally installs the OpAMP Supervisor for remote configuration management
- Provides a user-friendly GUI for configuration during installation
- Handles upgrades and uninstallation cleanly
- Follows Windows installer best practices

## Distribution Formats

### Primary: ZIP Package with MSI Installer (Recommended)
```
instana-otel-collector-installer-v1.316.0-windows-amd64.zip
├── README.md                                    # Installation guide
├── INSTALL.txt                                  # Quick start
├── instana-otel-collector-1.316.0.msi          # MSI installer
└── instana-otel-collector-1.316.0.msi.sha256   # Checksum
```

### Alternative: Standalone MSI
- Direct MSI download for users who prefer not to extract ZIP

### Legacy: Portable ZIP (No Installation)
- Portable binaries with batch scripts
- Use `--skip-msi` flag to build

## Directory Structure

```
windows/
├── README.md                          # This file
├── build-msi.ps1                     # MSI build script (called by bash wrapper)
├── package_instana_collector.sh       # Bash wrapper script
├── idot-windows-installer/            # MSI installer source files
│   ├── InstanaIdot.wxs                # Main WiX installer definition
│   ├── InstanaIdotUI.wxs              # User interface dialogs
│   ├── en-US.wxl                      # Localization strings
│   ├── service/
│   │   └── instana-idot.xml           # Windows service configuration
│   └── assets/                        # Graphical assets
│       ├── idot64.ico                 # Application icon (placeholder)
│       ├── idot64.png                 # Application logo (placeholder)
│       ├── banner.bmp                 # Installer banner (placeholder)
│       ├── welcome.bmp               # Welcome screen image (placeholder)
│       ├── create-placeholders.ps1    # Auto-generate placeholder assets
│       └── README.md                  # Asset documentation
```

## Prerequisites

1. **Go 1.21 or later** — `go version`
2. **WiX Toolset 3.11 or later** — `choco install wixtoolset -y`
3. **PowerShell 5.1 or later** (included with Windows 10/11)

## Quick Start

### Build MSI Package (ZIP with MSI inside)

```bash
# From repository root
./tools/packaging/windows/package_instana_collector.sh -v 1.316.0
```

### Build MSI Only

```bash
./tools/packaging/windows/package_instana_collector.sh -v 1.316.0 --msi-only
```

### Build Portable ZIP (Legacy)

```bash
./tools/packaging/windows/package_instana_collector.sh -v 1.316.0 --skip-msi
```

## Building the MSI Installer

### Method 1: Using Bash Script (Recommended for CI)

```bash
# Default: Build MSI and package into ZIP
./tools/packaging/windows/package_instana_collector.sh -v 1.316.0

# Verbose output
./tools/packaging/windows/package_instana_collector.sh -v 1.316.0 --verbose

# Dry run
./tools/packaging/windows/package_instana_collector.sh -v 1.316.0 --dry-run
```

### Method 2: Using PowerShell Script Directly

```powershell
cd tools/packaging/windows

.\build-msi.ps1 -Version "1.316.0"

# Verbose output
.\build-msi.ps1 -Version "1.316.0" -Verbose

# Skip Go build (use existing binaries)
.\build-msi.ps1 -Version "1.316.0" -SkipBuild
```

## Installation

### Interactive Installation

Double-click the MSI file. The installer will guide you through:
1. License agreement
2. Configuration (endpoints and agent key)
3. Installation directory selection
4. Completion

### Silent Installation

```cmd
msiexec /i instana-otel-collector-1.316.0.msi /quiet ^
    INSTANA_OTEL_ENDPOINT_GRPC="otlp-grpc-blue-saas.instana.io:443" ^
    INSTANA_KEY="your-agent-key-here"
```

### Installation with Logging

```cmd
msiexec /i instana-otel-collector-1.316.0.msi /l*v install.log
```

## Service Management

```cmd
net start InstanaOTelCollector
net stop InstanaOTelCollector
sc query InstanaOTelCollector
```

## Configuration

Configuration files are located at:
- `C:\Program Files\Instana\instana-otel-collector\config\config.yaml`
- `C:\Program Files\Instana\instana-otel-collector\config\config.env`

Edit these files and restart the service:
```cmd
net stop InstanaOTelCollector && net start InstanaOTelCollector
```

## Uninstallation

Via Add/Remove Programs, or:
```cmd
msiexec /x instana-otel-collector-1.316.0.msi /quiet
```

## CI/CD Integration

The GitHub Actions workflow `.github/workflows/windows-msi-build.yaml` automatically:
1. Builds the Windows MSI on `windows-latest` runner
2. Installs WiX Toolset via Chocolatey
3. Runs the packaging script
4. Uploads MSI and ZIP to GitHub Releases

The release pipeline (`pipeline/release-installer.sh`) also uploads standalone MSI artifacts alongside the ZIP package.

## Troubleshooting

**WiX Toolset not found:** Install WiX and ensure `%WIX%` environment variable is set.

**Go build fails:** Ensure Go 1.21+ is installed and in PATH.

**Service won't start:** Check logs at `C:\Program Files\Instana\instana-otel-collector\logs\` and verify config.yaml.

**Installation fails (error 1603):** Run with `/l*v install.log` and check the log. Ensure admin privileges and no prior version installed.

## Resources

- [WiX Toolset](https://wixtoolset.org/)
- [Windows Service Wrapper (WinSW)](https://github.com/winsw/winsw)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Instana Documentation](https://www.ibm.com/docs/en/instana-observability/current)
