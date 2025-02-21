#!/bin/bash

set -e

show_help() {
	echo "Usage: instana-collector-uninstaller.sh"
	echo "Options:"
	echo "  -h, --help    Show this help message and exit"
	exit 0
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	show_help
fi

# Determine INSTALL_PATH based on script location
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
INSTALL_PATH=$(dirname "$SCRIPT_DIR")/..
INSTALL_PATH=$(readlink -f "$INSTALL_PATH")

if [[ ! -d "$INSTALL_PATH/collector" ]]; then
	echo "Error: Instana Collector not found in $INSTALL_PATH."
	exit 1
fi

# Stop and remove service
if [[ -f "$INSTALL_PATH/collector/bin/instana_collector_service.sh" ]]; then
	echo "Stopping and removing Instana Collector service..."
	"$INSTALL_PATH/collector/bin/instana_collector_service.sh" uninstall || true
fi

# Remove installation directory
echo "Removing Instana Collector files..."
rm -rf "$INSTALL_PATH/collector"

# Remove INSTALL_PATH if empty
if [[ -d "$INSTALL_PATH" && -z "$(ls -A "$INSTALL_PATH")" ]]; then
	echo "Removing empty installation directory: $INSTALL_PATH"
	rmdir "$INSTALL_PATH"
fi

echo "Uninstallation complete. Instana Collector has been removed from $INSTALL_PATH."
