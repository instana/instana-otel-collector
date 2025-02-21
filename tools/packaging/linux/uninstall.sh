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

# Determine the installation path based on the script's location
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
INSTALL_PATH=$(dirname "$SCRIPT_DIR")/..
INSTALL_PATH=$(readlink -f "$INSTALL_PATH")

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

# Remove the Instana Collector installation directory
echo "Removing Instana Collector files..."
rm -rf "$INSTALL_PATH/collector"

# Remove the root installation folder if it is empty
test -d "$INSTALL_PATH" && [ -z "$(ls -A "$INSTALL_PATH")" ] && echo "Removing empty installation directory: $INSTALL_PATH" && rmdir "$INSTALL_PATH"

# Completion message
echo "Uninstallation complete. Instana Collector has been removed from $INSTALL_PATH."
