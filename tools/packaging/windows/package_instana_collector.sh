#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

SCRIPT_VERSION="1.0.0"
VERSION=""
VERBOSE=false
DRY_RUN=false

# Function to display script usage
show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] -v <version>

Package the Instana Collector for Windows and create a ZIP installer.

Options:
  -h, --help     Show this help message and exit
  -v VERSION     Version number for the package (required)
  --verbose      Enable verbose output
  --dry-run      Run without making changes
  --version      Show script version

EOF
}

# Function to display script version
show_version() {
    echo "$(basename "$0") version $SCRIPT_VERSION"
}

# Function for logging
log() {
    local level="$1"
    shift
    if [[ "$VERBOSE" == "true" || "$level" != "DEBUG" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
    fi
}

# Function to check dependencies
check_dependencies() {
    log "INFO" "Checking dependencies..."
    local missing=false
    for cmd in go zip; do
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

# Function to build the Windows collector
build_collector() {
    log "INFO" "Building Instana Collector for Windows..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would build collector"
        return 0
    fi
    
    local current_dir
    current_dir=$(pwd)
    
    cd cmd/idot_win || {
        log "ERROR" "Failed to change directory to cmd/idot_win"
        exit 1
    }
    
    log "DEBUG" "Running go build for Windows collector..."
    
    # Build for Windows
    if ! go build -trimpath -o instana-otel-collector.exe -ldflags='-s -w'; then
        log "ERROR" "Failed to build Windows collector"
        cd "$current_dir" || true
        exit 1
    fi
    
    cd "$current_dir" || {
        log "ERROR" "Failed to return to original directory"
        exit 1
    }
    
    log "INFO" "Successfully built Windows collector"
}

# Function to package files
package_files() {
    log "INFO" "Packaging Windows files..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would package files"
        return 0
    fi
    
    # Create directory structure
    local package_dir="instana-collector"
    mkdir -p "$package_dir/bin" "$package_dir/config" "$package_dir/logs"

    # Create VERSION file
    echo "$VERSION" > "$package_dir/VERSION"
 
    # Copy README file first (so it appears at the top when extracted)
    if ! cp cmd/idot_win/scripts/README.md "$package_dir/README.md"; then
        log "ERROR" "Failed to copy README.md"
        exit 1
    fi

    # Copy configuration file
    if ! cp config/windows/config.yaml "$package_dir/config/config.yaml"; then
        log "ERROR" "Failed to copy config.yaml"
        exit 1
    fi
    
    # Copy Windows scripts
    if ! cp cmd/idot_win/scripts/setenv.bat "$package_dir/bin/"; then
        log "ERROR" "Failed to copy setenv.bat"
        exit 1
    fi

    if ! cp cmd/idot_win/scripts/start.bat "$package_dir/bin/"; then
        log "ERROR" "Failed to copy start.bat"
        exit 1
    fi
    
    if ! cp cmd/idot_win/scripts/stop.bat "$package_dir/bin/"; then
        log "ERROR" "Failed to copy stop.bat"
        exit 1
    fi
    
    if ! cp cmd/idot_win/scripts/status.bat "$package_dir/bin/"; then
        log "ERROR" "Failed to copy status.bat"
        exit 1
    fi
    
    # Move and rename built binary to match script expectations
    if ! mv cmd/idot_win/instana-otel-collector.exe "$package_dir/bin/instana-otelcol.exe"; then
        log "ERROR" "Failed to move collector binary"
        exit 1
    fi
    
    # Create ZIP package
    log "DEBUG" "Creating ZIP package..."
    local zip_file="instana-collector-installer-v$VERSION.zip"
    if ! zip -r "$zip_file" "$package_dir"; then
        log "ERROR" "Failed to create ZIP package"
        exit 1
    fi
    
    # Generate checksum
    log "DEBUG" "Generating checksum..."
    if command -v sha256sum &>/dev/null; then
        sha256sum "$zip_file" > "$zip_file.sha256"
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$zip_file" > "$zip_file.sha256"
    else
        log "WARNING" "Neither sha256sum nor shasum found, skipping checksum generation"
    fi
    
    # Clean up temporary directory
    rm -rf "$package_dir"
    
    log "INFO" "Successfully packaged Windows files"
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
        -v)
            VERSION="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main script execution
main() {
    # Validate inputs
    if [[ -z "$VERSION" ]]; then
        log "ERROR" "Version is required. Use -v VERSION"
        show_help
        exit 1
    fi
    
    # Validate version format
    if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
        log "WARNING" "Version '$VERSION' does not follow semantic versioning (X.Y.Z)"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Build and package
    build_collector
    package_files
    
    log "INFO" "Windows packaging complete."
    
    # Show summary
    echo "----------------------------------------"
    echo "Windows Package Summary:"
    echo "  Version: $VERSION"
    echo "  Package: instana-collector-installer-v$VERSION.zip"
    echo "----------------------------------------"
}

# Execute main function
main