#check=skip=SecretsUsedInArgOrEnv

# Stage 1: Build the collector using Red Hat UBI 9
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest AS builder

# Add metadata labels for documentation and traceability
LABEL maintainer="Instana Team" \
      description="Instana OpenTelemetry Collector Builder Stage"

# Install required packages (only ca-certificates needed for HTTPS)
# Clean up in the same layer to minimize image size
RUN microdnf install -y ca-certificates tar gzip && \
    microdnf clean all

# Define build-time arguments and default values
# PAT_TOKEN is required to authenticate GitHub Enterprise API calls
ARG PAT_TOKEN
ARG VERSION="latest"
# URL to fetch release assets from GitHub Enterprise
ENV DOWNLOAD_URL="https://api.github.ibm.com/repos/instana/instana-otel-collector/releases/assets"

# Download and install the appropriate collector release
RUN echo "Building version: ${VERSION}" && \
    # Determine the correct API URL based on whether we're building "latest" or a specific version
    if [ "${VERSION}" = "latest" ]; then \
      API_URL="https://api.github.ibm.com/repos/instana/instana-otel-collector/releases/latest"; \
    else \
      API_URL="https://api.github.ibm.com/repos/instana/instana-otel-collector/releases/tags/${VERSION}"; \
    fi && \
    # Extract the asset ID for the installer script (most recent match)
    ASSET_ID=$(curl --fail -s -H "Authorization: token ${PAT_TOKEN}" "${API_URL}" | \
      grep -B 5 "instana-collector-installer" | \
      sed -n 's/.*"id":\s*\([0-9]*\),*/\1/p' | tr -d ' ' | head -1) && \
    echo "Using asset ID: $ASSET_ID" && \
    # Download and run the installer (use dummy values for endpoint and key)
    curl --fail -sSL -H "Accept: application/octet-stream" -H "Authorization: token ${PAT_TOKEN}" \
      "${DOWNLOAD_URL}/${ASSET_ID}" -o /tmp/installer.sh && \
    chmod +x /tmp/installer.sh && \
    # silent mode; endpoint/key not needed for extraction
    /tmp/installer.sh -s -e otlp-grpc.domain.local:0000 -a tempkey && \
    # Remove installer after execution
    rm -f /tmp/installer.sh

# Stage 2: Final minimal image (scratch is as small as it gets)
FROM scratch

# Re-declare VERSION arg so it's available during label rendering
ARG VERSION="latest"

# Set non-root user for runtime security
ARG USER_UID=10001
ARG USER_GID=10001
USER ${USER_UID}:${USER_GID}

# OCI-compliant metadata for image consumers and scanners
LABEL org.opencontainers.image.title="Instana OpenTelemetry Collector" \
      org.opencontainers.image.description="Instana OpenTelemetry Collector for metrics, traces, and logs collection" \
      org.opencontainers.image.vendor="IBM" \
      org.opencontainers.image.source="https://github.com/instana/instana-otel-collector" \
      org.opencontainers.image.version="${VERSION:-unknown}"

# Copy CA certificates for HTTPS support in the collector
COPY --from=builder /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt

# Copy the built collector binary and default config file
# Ensure file ownership matches the non-root user
COPY --from=builder --chown=${USER_UID}:${USER_GID} /opt/instana/collector/bin/instana-otelcol /
COPY --from=builder --chown=${USER_UID}:${USER_GID} /opt/instana/collector/config/config.yaml /etc/instana-otelcol/config.yaml

# Set default startup behavior
ENTRYPOINT ["/instana-otelcol"]
CMD ["--config", "/etc/instana-otelcol/config.yaml"]

# Expose default OTLP (gRPC + HTTP) and legacy ports for metrics/traces
EXPOSE 4317 4318 55678 55679
