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

# Ensure VERSION is provided
if [[ -z "$VERSION" ]]; then
	echo "Error: Version is required."
	show_help
	exit 1
fi

# Function to setup environment
setup_environment() {
	echo "Setting up environment..."
	GOBIN=$PWD go install go.opentelemetry.io/collector/cmd/builder@v0.119.0
}

# Function to build the collector
build_collector() {
	echo "Building Instana Collector..."
	./builder --config builder-config.yaml
}

# Function to package files
package_files() {
	echo "Packaging Files..."
	mkdir -p collector/bin collector/config
	cp config.yaml collector/config
	cp tools/packaging/linux/instana_collector_service.sh collector/bin
	mv otelcol-dev/otelcol-dev collector/bin/instana-otelcol
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
  echo "Usage: instana-collector-installer-v$VERSION.sh -e INSTANA_ENDPOINT -a INSTANA_KEY [install_path]"
  echo "Options:"
  echo "  -h, --help    Show this help message and exit"
  echo "  -e ENDPOINT   Set the Instana endpoint (required)"
  echo "  -a KEY        Set the Instana key (required)"
  exit 0
}

if [[ "\$1" == "-h" || "\$1" == "--help" ]]; then
  show_help
fi

# Default values
INSTALL_PATH="/opt/instana"
INSTANA_ENDPOINT=""
INSTANA_KEY=""

# Parse arguments
while getopts "he:a:" opt; do
  case \${opt} in
    h )
      show_help
      ;;
    e )
      INSTANA_ENDPOINT="\$OPTARG"
      ;;
    a )
      INSTANA_KEY="\$OPTARG"
      ;;
    \? )
      show_help
      ;;
  esac
done
shift \$((OPTIND -1))

if [[ -z "\$INSTANA_ENDPOINT" || -z "\$INSTANA_KEY" ]]; then
  echo "Error: Both -e (INSTANA_ENDPOINT) and -a (INSTANA_KEY) are required."
  show_help
fi

if [[ -n "\$1" ]]; then
  INSTALL_PATH="\$1"
fi

echo "Extracting package to \$INSTALL_PATH..."
mkdir -p "\$INSTALL_PATH"
echo "$BASE64_TAR" | base64 --decode > "\$INSTALL_PATH/instana-otel-collector-release-v$VERSION.tar.gz"
tar -xzvf "\$INSTALL_PATH/instana-otel-collector-release-v$VERSION.tar.gz" -C "\$INSTALL_PATH"

echo "Creating config.env file..."
echo "INSTANA_ENDPOINT=\$INSTANA_ENDPOINT" > "\$INSTALL_PATH/collector/config/config.env"
echo "INSTANA_KEY=\$INSTANA_KEY" >> "\$INSTALL_PATH/collector/config/config.env"

chmod 600 "\$INSTALL_PATH/collector/config/config.env"

echo "Running instana_collector_service.sh install..."
"\$INSTALL_PATH/collector/bin/instana_collector_service.sh" install

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
package_files
create_installer_script
cleanup

echo "Packaging and extraction script generation complete."
