#!/bin/bash

show_help() {
	echo "Usage: $0 <version>"
	echo ""
	echo "Options:"
	echo "  -h, --help    Show this help message and exit"
}

# Show help if -h or --help is passed
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	show_help
	exit 0
fi

VERSION=$1
# Check if the supervisor source directory exists.
# If it does, enable the SUPERVISOR flag.
SUPERVISOR=false
if [ -d "supervisor/cmd/supervisor" ]; then
  SUPERVISOR=true
fi

# Ensure VERSION is provided
if [[ -z "$VERSION" ]]; then
	echo "Error: Version is required."
	show_help
	exit 1
fi

# Function to setup environment
setup_environment() {
	echo "Setting up environment..."
	GOBIN=$PWD go install go.opentelemetry.io/collector/cmd/builder@v0.128.0
}

# Function to build the collector
build_collector() {
	echo "Building Instana Collector..."
	./builder --config config/builder/builder-config.yaml
}

# Function to build the supervisor
build_supervisor() {
	echo "Building Supervisor..."
	cd supervisor/cmd/supervisor
	go build -o opampsupervisor
	cd ../../..
}

# Function to package files
package_files() {
	echo "Packaging Files..."
	mkdir -p collector/bin collector/config collector/logs
	cp config/linux/config.yaml collector/config/config.example.yaml
	cp tools/packaging/linux/instana_collector_service.sh collector/bin
	cp tools/packaging/linux/uninstall.sh collector/bin
	mv idot/instana-otel-collector collector/bin/instana-otelcol
	if [ "$SUPERVISOR" = "true" ]; then
		cp tools/packaging/linux/instana_supervisor_service.sh collector/bin
		mv supervisor/cmd/supervisor/opampsupervisor collector/bin/supervisor
		cp supervisor/cmd/supervisor/supervisor.yaml collector/config
	fi
	tar -czvf "instana-otel-collector-release-v$VERSION.tar.gz" collector
}

# Function to create installer script
create_installer_script() {
	echo "Embedding tar.gz into script..."
	BASE64_TAR=$(base64 "instana-otel-collector-release-v$VERSION.tar.gz")

	cat >instana-collector-installer-v"$VERSION".sh <<EOL
#!/bin/bash

set -e

show_help() {
  echo "Usage: instana-collector-installer-v$VERSION.sh -e INSTANA_OTEL_ENDPOINT_GRPC [-H INSTANA_OTEL_ENDPOINT_HTTP] -a INSTANA_KEY [install_path]"
  echo "Options:"
  echo "  -h, --help          Show this help message and exit"
  echo "  -e gRPC ENDPOINT    Set the Instana OTel gRPC endpoint (required)"
  echo "  -H HTTP ENDPOINT    Set the Instana OTel HTTP endpoint"
  echo "  -m Metrics ENDPOINT Set the Instana Metrics endpoint"
  echo "  -a KEY              Set the Instana key (required)"
  if [ "$SUPERVISOR" = "true" ]; then
    echo "  -u true|false       Enable Supervisor service (enabled by default)"
  fi
  exit 0
}

if [[ "\$1" == "-h" || "\$1" == "--help" ]]; then
  show_help
fi

# Default values
INSTALL_PATH="/opt/instana"
INSTANA_OTEL_ENDPOINT_GRPC=""
INSTANA_OTEL_ENDPOINT_HTTP=""
INSTANA_OPAMP_ENDPOINT=""
INSTANA_METRICS_ENDPOINT=""
INSTANA_KEY=""
SKIP_INSTALL_SERVICE=false
USE_SUPERVISOR_SERVICE=$SUPERVISOR

# Parse arguments
while getopts "he:H:m:a:su:" opt; do
  case \${opt} in
    h )
      show_help
      ;;
    e )
      INSTANA_OTEL_ENDPOINT_GRPC="\$OPTARG"
      ;;
    H )
      INSTANA_OTEL_ENDPOINT_HTTP="\$OPTARG"
      ;;
    m )
      INSTANA_METRICS_ENDPOINT="\$OPTARG"
      ;;
    a )
      INSTANA_KEY="\$OPTARG"
      ;;
    s )
      SKIP_INSTALL_SERVICE=true
      ;;
    u )
      if [[ "\$OPTARG" == "true" ]]; then
        USE_SUPERVISOR_SERVICE=true
      elif [[ "\$OPTARG" == "false" ]]; then
        USE_SUPERVISOR_SERVICE=false
      else
        echo "Error: Invalid value for -u. Expected 'true' or 'false'."
        exit 1
      fi
      ;;
    \? )
      show_help
      ;;
  esac
done
shift \$((OPTIND -1))

if [[ -z "\$INSTANA_OTEL_ENDPOINT_GRPC" || -z "\$INSTANA_KEY" ]]; then
  echo "Error: Both -e (INSTANA_OTEL_ENDPOINT_GRPC) and -a (INSTANA_KEY) are required."
  show_help
fi

# If the INSTANA_OTEL_ENDPOINT_GRPC does not start with a protocol imply https://
if [[ ! "\$INSTANA_OTEL_ENDPOINT_GRPC" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    INSTANA_OTEL_ENDPOINT_GRPC="https://\$INSTANA_OTEL_ENDPOINT_GRPC"
fi

# Derive INSTANA_OTEL_ENDPOINT_HTTP if not set
if [[ -z "\$INSTANA_OTEL_ENDPOINT_HTTP" ]]; then
  INSTANA_OTEL_ENDPOINT_HTTP="\$(echo "\$INSTANA_OTEL_ENDPOINT_GRPC" | sed -E 's/:[0-9]+//g'):4318"
fi

# If the INSTANA_OTEL_ENDPOINT_HTTP does not start with a protocol imply https://
if [[ ! "\$INSTANA_OTEL_ENDPOINT_HTTP" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    INSTANA_OTEL_ENDPOINT_HTTP="https://\$INSTANA_OTEL_ENDPOINT_HTTP"
fi

# Derive INSTANA_OPAMP_ENDPOINT if not set
if [[ -z "\$INSTANA_OPAMP_ENDPOINT" ]]; then
  INSTANA_OPAMP_ENDPOINT="\$(echo "ws://\$INSTANA_OTEL_ENDPOINT_GRPC" | sed -E 's/:[0-9]+//g'):4320/v1/opamp"
fi

# Derive INSTANA_METRICS_ENDPOINT if not set
if [[ -z "\$INSTANA_METRICS_ENDPOINT" ]]; then
  MODIFIED_URL=\$(echo "\$INSTANA_OTEL_ENDPOINT_GRPC" | sed -E 's|^https://||' | sed -E 's|^otlp-|ingress-|' | sed -E 's|:[0-9]+$||')
  INSTANA_METRICS_ENDPOINT="https://\${MODIFIED_URL}:443"
fi

if [[ -n "\$1" ]]; then
  INSTALL_PATH="\$1"
fi

echo "Extracting package to \$INSTALL_PATH..."
mkdir -p "\$INSTALL_PATH"
echo "$BASE64_TAR" | base64 --decode > "\$INSTALL_PATH/instana-otel-collector-release-v$VERSION.tar.gz"
tar -xzvf "\$INSTALL_PATH/instana-otel-collector-release-v$VERSION.tar.gz" -C "\$INSTALL_PATH"

# Delete the package tar.gz file after extraction
rm -f "\$INSTALL_PATH/instana-otel-collector-release-v$VERSION.tar.gz"

echo "Creating config.env file..."
echo "INSTANA_OTEL_ENDPOINT_GRPC=\$INSTANA_OTEL_ENDPOINT_GRPC" > "\$INSTALL_PATH/collector/config/config.env"
echo "INSTANA_OTEL_ENDPOINT_HTTP=\$INSTANA_OTEL_ENDPOINT_HTTP" >> "\$INSTALL_PATH/collector/config/config.env"
echo "INSTANA_KEY=\$INSTANA_KEY" >> "\$INSTALL_PATH/collector/config/config.env"
echo "HOSTNAME=\$HOSTNAME" >> "\$INSTALL_PATH/collector/config/config.env"

chmod 600 "\$INSTALL_PATH/collector/config/config.env"

# Create config.yaml
CONFIG_PATH="\$INSTALL_PATH/collector/config"
if [[ ! -f "\$CONFIG_PATH/config.yaml" ]]; then
  if [[ -f "\$CONFIG_PATH/config.example.yaml" ]]; then
    echo "Creating config.yaml from config.example.yaml..."
    install -m 600 "\$CONFIG_PATH/config.example.yaml" "\$CONFIG_PATH/config.yaml"
  else
    echo "Error: Neither config.yaml nor config.example.yaml found in '\$CONFIG_PATH'. Cannot proceed."
    exit 1
  fi
else
  echo "The config.yaml already exists. Skipping creation..."
fi

if [ "$SUPERVISOR" = "true" ]; then
  # Update supervisor.yaml
  echo "\$CONFIG_PATH/supervisor.yaml"
  sed -i 's|<OTEL_COLLECTOR_EXECUTABLE>|./instana-otelcol|g' "\$CONFIG_PATH/supervisor.yaml"
  sed -i 's|<HEALTH_CHECK_ENDPOINT>|http://localhost:13133/health|g' "\$CONFIG_PATH/supervisor.yaml"
  sed -i "s|<INSTANA_METRICS_ENDPOINT>|\$INSTANA_METRICS_ENDPOINT|g" "\$CONFIG_PATH/supervisor.yaml"
fi

if [[ "\$SKIP_INSTALL_SERVICE" == "false" ]]; then
  if [[ "\$USE_SUPERVISOR_SERVICE" == "true" ]]; then
    echo "Running instana_supervisor_service.sh install..."
    "\$INSTALL_PATH/collector/bin/instana_supervisor_service.sh" install
  else
    echo "Running instana_collector_service.sh install..."
    "\$INSTALL_PATH/collector/bin/instana_collector_service.sh" install
  fi
fi

echo "Extraction complete. Files are available at \$INSTALL_PATH."
EOL

	chmod +x instana-collector-installer-v"$VERSION".sh
}

# Function to clean up artifacts
cleanup() {
	echo "Cleaning up artifacts..."
	rm -rf otelcol-dev collector "instana-otel-collector-release-v$VERSION.tar.gz"
}

# Main Script Execution
setup_environment
build_collector
if [ "$SUPERVISOR" = "true" ]; then
	build_supervisor
fi
package_files
create_installer_script
cleanup

echo "Packaging and extraction script generation complete."
