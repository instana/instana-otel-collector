# Building IDOT from source

The Linux installer is produced by `tools/packaging/linux/package_instana_collector.sh`.
It builds the collector binary, assembles the `collector/` tree (binary, service
scripts and example config) and emits a self-extracting installer with the
tarball embedded.

## Prerequisites

- Go (version as declared in `cmd/idot_linux/go.mod`)
- `tar`, `base64`, `sed`
- ~500 MB free disk space

No C toolchain is required. The collector is built with `CGO_ENABLED=0`, which
means it is statically linked and can be cross-compiled for any supported
architecture from any build host.

## Usage

```bash
./tools/packaging/linux/package_instana_collector.sh [OPTIONS] <version>
```

| Option | Description |
|--------|-------------|
| `-a`, `--arch` | Target architecture: `amd64` (default), `arm64`, `s390x`. Also settable via the `ARCH` environment variable. |
| `-v`, `--verbose` | Verbose output |
| `-d`, `--dry-run` | Run without making changes |
| `-h`, `--help` | Show help |
| `--version` | Show script version |

## Examples

```bash
# amd64 (default)
./tools/packaging/linux/package_instana_collector.sh 1.2.3

# arm64 / AArch64
./tools/packaging/linux/package_instana_collector.sh --arch arm64 1.2.3

# s390x / IBM Z
./tools/packaging/linux/package_instana_collector.sh --arch s390x 1.2.3

# architecture via environment
ARCH=arm64 ./tools/packaging/linux/package_instana_collector.sh 1.2.3
```

## Output

```
instana-collector-installer-v<version>-linux-<arch>.sh
instana-otel-collector-release-v<version>-linux-<arch>.tar.gz.sha256
```

Artifact names are architecture-qualified so builds for multiple architectures
can be attached to the same release without colliding.

## Verifying the result

Confirm the embedded binary targets the architecture you asked for:

```bash
./instana-collector-installer-v1.2.3-linux-arm64.sh \
  -e <endpoint> -a <key> -s /tmp/verify
file /tmp/verify/collector/bin/instana-otelcol
# ELF 64-bit LSB executable, ARM aarch64, ... statically linked, stripped
```

The `-s` flag extracts without installing the systemd service, which makes this
safe to run on a build machine.

List the compiled-in components:

```bash
/tmp/verify/collector/bin/instana-otelcol components
```

## Release automation

`.github/workflows/release_publish.yaml` runs the packaging script across an
architecture matrix and uploads one installer per architecture, plus a
`-latest-linux-<arch>` alias. For backward compatibility it also publishes the
historical unsuffixed `instana-collector-installer-v<version>.sh` and
`instana-collector-installer-latest.sh` names, which are amd64.

Because cross-compilation needs no emulation, every architecture builds on the
standard `ubuntu-latest` runner — no QEMU and no native ARM or Z runners.
