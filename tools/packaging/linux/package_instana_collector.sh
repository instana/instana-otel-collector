#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

SCRIPT_VERSION="1.0.0"
VERSION=""
VERBOSE=false
DRY_RUN=false
SUPERVISOR=false
TEMP_DIR=""

# Function to display script usage
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] <version>

Package the Instana Collector and create an installer script.

Options:
  -h, --help     Show this help message and exit
  -v, --verbose  Enable verbose output
  -d, --dry-run  Run without making changes
  --version      Show script version

Arguments:
  version        Version number for the package (required)
EOF
}

# Function to display script version
show_version() {
    echo "$(basename "$0") version $SCRIPT_VERSION"
}

# Function for logging with different levels
log() {
    local level="$1"
    shift
    if [[ "$VERBOSE" == "true" || "$level" != "DEBUG" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
    fi
}

# Function to show progress spinner
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to check if required dependencies are installed
check_dependencies() {
    log "INFO" "Checking dependencies..."
    local missing=false
    for cmd in go tar base64 sed; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR" "Required command not found: $cmd"
            missing=true
        fi
    done
    
    if [[ "$missing" == "true" ]]; then
        log "ERROR" "Please install missing dependencies and try again."
        exit 1
    fi
}

# Function to check available disk space
check_disk_space() {
    log "INFO" "Checking available disk space..."
    local required_space=500000  # 500MB in KB
    local available_space
    
    available_space=$(df -k . | awk 'NR==2 {print $4}')
    
    if [[ "$available_space" -lt "$required_space" ]]; then
        log "ERROR" "Insufficient disk space. Required: ${required_space}KB, Available: ${available_space}KB"
        exit 1
    fi
}

# Function to create temporary directory
create_temp_dir() {
    TEMP_DIR=$(mktemp -d) || {
        log "ERROR" "Failed to create temporary directory"
        exit 1
    }
    log "DEBUG" "Created temporary directory: $TEMP_DIR"
    
    # Register cleanup handler
    trap cleanup_temp EXIT INT TERM
}

# Function to clean up temporary directory
cleanup_temp() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        log "DEBUG" "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# Function to build the collector
build_collector() {
    log "INFO" "Building Instana Collector..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would build collector"
        return 0
    fi
    
    # Save current directory
    local current_dir
    current_dir=$(pwd)
    
    cd cmd/idot || {
        log "ERROR" "Failed to change directory to cmd/idot"
        exit 1
    }
    
    log "DEBUG" "Running go build for collector..."
    
    # Run build in background and show spinner
    if [[ "$VERBOSE" == "true" ]]; then
        # In verbose mode, show output directly
        if ! go build -trimpath -o instana-otel-collector -ldflags='-s -w' -gcflags=''; then
            log "ERROR" "Failed to build collector"
            cd "$current_dir" || true
            exit 1
        fi
    else
        # In normal mode, show spinner
        go build -trimpath -o instana-otel-collector -ldflags='-s -w' -gcflags='' &
        local build_pid=$!
        echo -n "Building collector "
        show_spinner "$build_pid"
        wait "$build_pid" || {
            echo
            log "ERROR" "Failed to build collector"
            cd "$current_dir" || true
            exit 1
        }
        echo " Done!"
    fi
    
    cd "$current_dir" || {
        log "ERROR" "Failed to return to original directory"
        exit 1
    }
    
    log "INFO" "Successfully built collector"
}

# Function to build the supervisor
build_supervisor() {
    log "INFO" "Building Supervisor..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would build supervisor"
        return 0
    fi
    
    # Save current directory
    local current_dir
    current_dir=$(pwd)
    
    cd supervisor/cmd/supervisor || {
        log "ERROR" "Failed to change directory to supervisor/cmd/supervisor"
        exit 1
    }
    
    log "DEBUG" "Running go build for supervisor..."
    
    # Run build in background and show spinner
    if [[ "$VERBOSE" == "true" ]]; then
        # In verbose mode, show output directly
        if ! go build -o opampsupervisor; then
            log "ERROR" "Failed to build supervisor"
            cd "$current_dir" || true
            exit 1
        fi
    else
        # In normal mode, show spinner
        go build -o opampsupervisor &
        local build_pid=$!
        echo -n "Building supervisor "
        show_spinner "$build_pid"
        wait "$build_pid" || {
            echo
            log "ERROR" "Failed to build supervisor"
            cd "$current_dir" || true
            exit 1
        }
        echo " Done!"
    fi
    
    cd "$current_dir" || {
        log "ERROR" "Failed to return to original directory"
        exit 1
    }
    
    log "INFO" "Successfully built supervisor"
}

# Function to package files
package_files() {
    log "INFO" "Packaging Files..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would package files"
        return 0
    fi
    
    # Create directory structure
    mkdir -p collector/bin collector/config collector/logs
    
    # Copy configuration files
    if ! cp config/linux/config.yaml collector/config/config.example.yaml; then
        log "ERROR" "Failed to copy config.yaml"
        exit 1
    fi
    
    # Copy service scripts
    if ! cp tools/packaging/linux/instana_collector_service.sh collector/bin; then
        log "ERROR" "Failed to copy instana_collector_service.sh"
        exit 1
    fi
    
    if ! cp tools/packaging/linux/uninstall.sh collector/bin; then
        log "ERROR" "Failed to copy uninstall.sh"
        exit 1
    fi
    
    # Move built binaries
    if ! mv cmd/idot/instana-otel-collector collector/bin/instana-otelcol; then
        log "ERROR" "Failed to move collector binary"
        exit 1
    fi
    
    # Handle supervisor if enabled
    if [[ "$SUPERVISOR" == "true" ]]; then
        log "DEBUG" "Including supervisor components..."
        
        if ! cp tools/packaging/linux/instana_supervisor_service.sh collector/bin; then
            log "ERROR" "Failed to copy instana_supervisor_service.sh"
            exit 1
        fi
        
        if ! mv supervisor/cmd/supervisor/opampsupervisor collector/bin/supervisor; then
            log "ERROR" "Failed to move supervisor binary"
            exit 1
        fi
        
        if ! cp supervisor/cmd/supervisor/supervisor.yaml collector/config; then
            log "ERROR" "Failed to copy supervisor.yaml"
            exit 1
        fi
    fi
    
    # Create tarball
    log "DEBUG" "Creating tarball..."
    if ! tar -czvf "instana-otel-collector-release-v$VERSION.tar.gz" collector; then
        log "ERROR" "Failed to create tarball"
        exit 1
    fi
    
    # Generate checksum
    log "DEBUG" "Generating checksum..."
    if command -v sha256sum &>/dev/null; then
        sha256sum "instana-otel-collector-release-v$VERSION.tar.gz" > "instana-otel-collector-release-v$VERSION.tar.gz.sha256"
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "instana-otel-collector-release-v$VERSION.tar.gz" > "instana-otel-collector-release-v$VERSION.tar.gz.sha256"
    else
        log "WARNING" "Neither sha256sum nor shasum found, skipping checksum generation"
    fi
    
    log "INFO" "Successfully packaged files"
}

# Function to create installer script
create_installer_script() {
    log "INFO" "Creating installer script..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would create installer script"
        return 0
    fi
    
    log "DEBUG" "Embedding tar.gz into script..."
    
    # Use a more efficient approach for base64 encoding
    local base64_cmd
    if command -v base64 &>/dev/null; then
        if base64 --help 2>&1 | grep -q -- "-w"; then
            # GNU base64 (Linux)
            base64_cmd="base64 -w 0"
        else
            # BSD base64 (macOS)
            base64_cmd="base64"
        fi
    else
        log "ERROR" "base64 command not found"
        exit 1
    fi
    
    local BASE64_TAR
    BASE64_TAR=$($base64_cmd < "instana-otel-collector-release-v$VERSION.tar.gz")
    
    log "DEBUG" "Creating installer script..."
    
    cat > "instana-collector-installer-v$VERSION.sh" <<EOL
#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

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

# ------------------------------------------------------------------------------
# Endpoint Configuration and Validation Logic
#
# This section ensures that required environment variables for Instana OTEL
# integration are present and properly formatted. It performs the following:
#
# 1. Validates that both INSTANA_OTEL_ENDPOINT_GRPC and INSTANA_KEY are set.
# 2. Ensures that endpoint URLs include a protocol; defaults to https:// if missing.
# 3. Parses the GRPC endpoint to extract the protocol, domain, and port.
# 4. Sets a default port (443) if the protocol is https and no port is specified.
# 5. Derives the HTTP OTEL endpoint if not explicitly provided, using standard
#    port 4318 unless GRPC is on 443 (then reuse 443 for HTTP).
# 6. Constructs the metrics endpoint if not provided, transforming the GRPC domain
#    from 'otlp-*' to 'ingress-*' and assuming port 443.
#
# This logic ensures flexible, robust endpoint handling across different deployment
# environments with minimal manual configuration.
# ------------------------------------------------------------------------------

# Validate required parameters
if [[ -z "\$INSTANA_OTEL_ENDPOINT_GRPC" || -z "\$INSTANA_KEY" ]]; then
  echo "Error: Both -e (INSTANA_OTEL_ENDPOINT_GRPC) and -a (INSTANA_KEY) are required."
  show_help
  exit 1
fi

# If the INSTANA_OTEL_ENDPOINT_GRPC does not start with a protocol imply https://
if [[ ! "\$INSTANA_OTEL_ENDPOINT_GRPC" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    INSTANA_OTEL_ENDPOINT_GRPC="https://\$INSTANA_OTEL_ENDPOINT_GRPC"
fi

# Extract base domain and protocol for endpoint derivation
ENDPOINT_PROTOCOL="\$(echo "\$INSTANA_OTEL_ENDPOINT_GRPC" | sed -E 's|^([a-zA-Z][a-zA-Z0-9+.-]*://).*|\1|')"
ENDPOINT_DOMAIN="\$(echo "\$INSTANA_OTEL_ENDPOINT_GRPC" | sed -E 's|^[a-zA-Z][a-zA-Z0-9+.-]*://||' | sed -E 's|:[0-9]+$||' | sed -E 's|/.*$||')"

# Extract port from GRPC endpoint (if any)
GRPC_PORT="\$(echo "\$INSTANA_OTEL_ENDPOINT_GRPC" | sed -nE 's|.*:([0-9]+).*|\1|p')"

# If protocol is https and no port is set, assume port 443
if [[ "\$ENDPOINT_PROTOCOL" == "https://" && -z "\$GRPC_PORT" ]]; then
  GRPC_PORT="443"
  INSTANA_OTEL_ENDPOINT_GRPC="\${ENDPOINT_PROTOCOL}\${ENDPOINT_DOMAIN}:443"
fi

# Derive INSTANA_OTEL_ENDPOINT_HTTP if not set
if [[ -z "\$INSTANA_OTEL_ENDPOINT_HTTP" ]]; then
  if [[ "\$GRPC_PORT" == "443" ]]; then
    INSTANA_OTEL_ENDPOINT_HTTP="\${ENDPOINT_PROTOCOL}\${ENDPOINT_DOMAIN}:443"
  else
    INSTANA_OTEL_ENDPOINT_HTTP="\${ENDPOINT_PROTOCOL}\${ENDPOINT_DOMAIN}:4318"
  fi
fi

# If the INSTANA_OTEL_ENDPOINT_HTTP does not start with a protocol imply https://
if [[ ! "\$INSTANA_OTEL_ENDPOINT_HTTP" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
    INSTANA_OTEL_ENDPOINT_HTTP="https://\$INSTANA_OTEL_ENDPOINT_HTTP"
fi

# Derive INSTANA_OPAMP_ENDPOINT if not set
if [[ -z "\$INSTANA_OPAMP_ENDPOINT" ]]; then
  # Always use secure WebSocket protocol (wss://) for security
  INSTANA_OPAMP_ENDPOINT="wss://\${ENDPOINT_DOMAIN}:4320/v1/opamp"
fi

# Derive INSTANA_METRICS_ENDPOINT if not set
if [[ -z "\$INSTANA_METRICS_ENDPOINT" ]]; then
  # Simplified metrics endpoint derivation
  MODIFIED_URL="\$(echo "\$ENDPOINT_DOMAIN" | sed -E 's|^otlp-|ingress-|')"
  INSTANA_METRICS_ENDPOINT="https://\${MODIFIED_URL}:443"
fi

# Set installation path if provided
if [[ -n "\${1-}" ]]; then
  INSTALL_PATH="\$1"
fi

echo "Extracting package to \$INSTALL_PATH..."
mkdir -p "\$INSTALL_PATH"

# Create a temporary file for the tarball
TEMP_TAR="\$(mktemp)"
echo "$BASE64_TAR" | base64 --decode > "\$TEMP_TAR"

# Verify the tarball integrity
if command -v tar &>/dev/null && ! tar -tf "\$TEMP_TAR" &>/dev/null; then
  echo "Error: The downloaded package appears to be corrupted."
  rm -f "\$TEMP_TAR"
  exit 1
fi

# Extract the tarball
tar -xzf "\$TEMP_TAR" -C "\$INSTALL_PATH"

# Delete the temporary tarball
rm -f "\$TEMP_TAR"

echo "Creating config.env file..."
CONFIG_ENV_PATH="\$INSTALL_PATH/collector/config/config.env"
cat > "\$CONFIG_ENV_PATH" <<EOF
INSTANA_OTEL_ENDPOINT_GRPC=\$INSTANA_OTEL_ENDPOINT_GRPC
INSTANA_OTEL_ENDPOINT_HTTP=\$INSTANA_OTEL_ENDPOINT_HTTP
INSTANA_KEY=\$INSTANA_KEY
HOSTNAME=\$HOSTNAME
INSTANA_OTEL_LOG_LEVEL=info
EOF

chmod 600 "\$CONFIG_ENV_PATH"

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
  echo "Configuring supervisor.yaml at \$CONFIG_PATH/supervisor.yaml"
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

echo "Installation complete. Files are available at \$INSTALL_PATH."
EOL
    
    chmod +x "instana-collector-installer-v$VERSION.sh"
    log "INFO" "Successfully created installer script: instana-collector-installer-v$VERSION.sh"
}

# Function to clean up artifacts
cleanup() {
    log "INFO" "Cleaning up artifacts..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would clean up artifacts"
        return 0
    fi
    
    rm -rf otelcol-dev collector "instana-otel-collector-release-v$VERSION.tar.gz"
    log "DEBUG" "Artifacts cleaned up"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --version)
            show_version
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            log "ERROR" "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION="$1"
            else
                log "ERROR" "Unexpected argument: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Signal handler for graceful termination
handle_signal() {
    log "INFO" "Received termination signal. Cleaning up..."
    cleanup
    cleanup_temp
    exit 1
}

# Main script execution
main() {
    # Set up signal handlers
    trap handle_signal INT TERM
    # Validate inputs
    if [[ -z "$VERSION" ]]; then
        log "ERROR" "Version is required."
        show_help
        exit 1
    fi
    
    # Validate version format (semantic versioning)
    if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        log "WARNING" "Version '$VERSION' does not appear to follow semantic versioning (X.Y.Z)"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Check disk space
    check_disk_space
    
    # Check if the supervisor source directory exists
    if [[ -d "supervisor/cmd/supervisor" ]]; then
        SUPERVISOR=true
        log "INFO" "Supervisor component detected, will be included in the package"
    fi
    
    # Build components
    build_collector
    
    if [[ "$SUPERVISOR" == "true" ]]; then
        build_supervisor
    fi
    
    # Package and create installer
    package_files
    create_installer_script
    cleanup
    
    log "INFO" "Packaging and extraction script generation complete."
    
    # Show summary
    echo "----------------------------------------"
    echo "Package Summary:"
    echo "  Version: $VERSION"
    echo "  Installer: instana-collector-installer-v$VERSION.sh"
    if [[ -f "instana-otel-collector-release-v$VERSION.tar.gz.sha256" ]]; then
        echo "  Checksum: $(cat "instana-otel-collector-release-v$VERSION.tar.gz.sha256")"
    fi
    echo "  Supervisor included: $SUPERVISOR"
    echo "----------------------------------------"
}

# Execute main function
main
