#!/bin/bash

set -e

# Function to display help message
show_help() {
	echo "Usage: uninstall.sh"
	echo "Options:"
	echo "  -h, --help    Show this help message and exit"
	exit 0
}

# Check if the user requested help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	show_help
fi

# Get the absolute path without using readlink -f (not available on AIX)
get_abs_path() {
    local path="$1"
    local dir=$(dirname "$path")
    local base=$(basename "$path")
    
    if [[ "$dir" = /* ]]; then
        cd "$dir" 2>/dev/null && pwd || echo "$dir"
    else
        cd "$dir" 2>/dev/null && pwd || echo "$(pwd)/$dir"
    fi
}

# Determine the installation path based on the script's location
SCRIPT_DIR=$(get_abs_path "$0")
INSTALL_PATH=$(dirname "$SCRIPT_DIR")/..
INSTALL_PATH=$(get_abs_path "$INSTALL_PATH")

# Verify if the Instana Collector is installed
if [[ ! -d "$INSTALL_PATH/collector" ]]; then
	echo "Error: Instana Collector not found in $INSTALL_PATH."
	exit 1
fi

# Stop and remove the Instana Collector service if it exists
if [[ -f "$INSTALL_PATH/collector/bin/instana_collector_service.sh" ]]; then
	echo "Stopping and removing Instana Collector service..."
	"$INSTALL_PATH/collector/bin/instana_collector_service.sh" uninstall || true
fi

# Stop and remove the Instana Supervisor service if it exists
if [[ -f "$INSTALL_PATH/collector/bin/instana_supervisor_service.sh" ]]; then
	echo "Stopping and removing Instana Supervisor service..."
	"$INSTALL_PATH/collector/bin/instana_supervisor_service.sh" uninstall || true
fi

# Remove the Instana Collector installation directory
echo "Removing Instana Collector files..."
rm -rf "$INSTALL_PATH/collector"

# Remove the root installation folder if it is empty
if [[ -d "$INSTALL_PATH" ]] && [[ -z "$(ls -A "$INSTALL_PATH" 2>/dev/null)" ]]; then
	echo "Removing empty installation directory: $INSTALL_PATH"
	rmdir "$INSTALL_PATH"
fi

# Completion message
echo "Uninstallation complete. Instana Collector has been removed from $INSTALL_PATH."

