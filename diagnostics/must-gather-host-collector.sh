#!/bin/bash

# OpenTelemetry Collector Must-Gather Script
# Collects system information, configuration and logs
# Usage: ./must-gather.sh [output_directory]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default paths
DEFAULT_COLLECTOR_DIR="/opt/instana/collector"
DEFAULT_CONFIG_PATH="${DEFAULT_COLLECTOR_DIR}/config/config.yaml"
DEFAULT_CFGENV_PATH="${DEFAULT_COLLECTOR_DIR}/config/config.env"
DEFAULT_LOGS_PATH="${DEFAULT_COLLECTOR_DIR}/logs"

# Output directory setup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${1:-host-otel-must-gather-${TIMESTAMP}}"

# Banner
print_banner() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  OpenTelemetry Collector Must-Gather Tool${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Print section header
print_section() {
    echo -e "\n${YELLOW}>>> $1${NC}"
}

# Print success message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Print info message
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Create output directory structure
setup_output_directory() {
    print_section "Setting up output directory"
    
    mkdir -p "$OUTPUT_DIR"/{system,logs,config}
    
    print_success "Created output directory: $OUTPUT_DIR"
}

# Collect system information
collect_system_info() {
    print_section "Collecting system information"
    
    local sys_dir="$OUTPUT_DIR/system"
    
    # Kernel version
    uname -a > "$sys_dir/kernel-version.txt"
    print_success "Collected kernel version"
    
    # Hostname
    hostname > "$sys_dir/hostname.txt"
    print_success "Collected hostname"
    
    free -h > "$sys_dir/memory-usage.txt" 2>/dev/null || true
    
    # Disk space
    df -h > "$sys_dir/disk-space.txt"
    print_success "Collected disk space information"
}

# Prompt for collector directory if default doesn't exist
get_collector_directory() {
    local collector_dir="$DEFAULT_COLLECTOR_DIR"
    
    if [ ! -d "$DEFAULT_LOGS_PATH" ]; then
        print_error "Default collector logs directory not found: $DEFAULT_LOGS_PATH"
        echo -n "Please enter the collector installation directory (or press Enter to skip): "
        read -r user_input
        
        if [ -n "$user_input" ]; then
            collector_dir="$user_input"
            if [ ! -d "$collector_dir" ]; then
                print_error "Directory does not exist: $collector_dir"
                return 1
            fi
        else
            print_info "Skipping log collection"
            return 1
        fi
    fi
    
    echo "$collector_dir"
    return 0
}

# Collect OpenTelemetry Collector logs
collect_collector_logs() {
    print_section "Collecting OpenTelemetry Collector logs"
    
    local collector_dir
    if ! collector_dir=$(get_collector_directory); then
        return
    fi
    
    local logs_path="${collector_dir}/logs"
    local logs_dir="$OUTPUT_DIR/logs"
    
    if [ -d "$logs_path" ]; then
        cp -r "$logs_path"/* "$logs_dir/" 2>/dev/null || true
        
        # Count collected log files
        local log_count=$(find "$logs_dir" -type f | wc -l)
        print_success "Collected $log_count log file(s)"
        
        # Create log file inventory
        find "$logs_dir" -type f -exec ls -lh {} \; > "$logs_dir/log-inventory.txt"
    else
        print_error "Logs directory not found: $logs_path"
    fi
}

# Collect collector configuration
collect_collector_config() {
    print_section "Collecting OpenTelemetry Collector configuration"
    
    local config_dir="$OUTPUT_DIR/config"
    
    if [ -f "$DEFAULT_CONFIG_PATH" ]; then
        cp "$DEFAULT_CONFIG_PATH" "$config_dir/config.yaml"
        cp "$DEFAULT_CFGENV_PATH" "$config_dir/config.env"
        print_success "Collected config.yaml and config.env from $config_dir"
    else
        print_error "Configuration file not found: $DEFAULT_CONFIG_PATH"
        echo -n "Please enter the directory path containing config.yaml (or press Enter to skip)"
        read -r enter_path
        
        if [ -n "$enter_path" ] && [ -f "$enter_path" ]; then
            cp "$enter_path/config.yaml" "$config_dir/config.yaml"
            cp "$enter_path/config.env" "$config_dir/config.env"
            print_success "Collected config.yaml and config.env from $enter_path"
        else
            print_info "Skipping configuration collection"
        fi
    fi
}

# Create summary report
create_summary() {
    print_section "Creating summary report"
    
    local summary_file="$OUTPUT_DIR/SUMMARY.txt"
    
    cat > "$summary_file" << EOF
OpenTelemetry Collector Must-Gather Report
==========================================
Collection Date: $(date)
Output Directory: $OUTPUT_DIR

Contents:
---------
- system/         : System information (OS, memory, disk)
- logs/           : OpenTelemetry Collector logs
- config/         : Collector configuration files

Notes:
------
EOF

    if [ ! -f "$OUTPUT_DIR/config/config.yaml" ]; then
        echo "- Configuration file was not found or collected" >> "$summary_file"
    fi
    
    if [ ! -d "$OUTPUT_DIR/logs" ] || [ -z "$(ls -A "$OUTPUT_DIR/logs")" ]; then
        echo "- Collector logs were not found or collected" >> "$summary_file"
    fi
    
    print_success "Summary report created: $summary_file"
}

# Create archive
create_archive() {
    print_section "Creating archive"
    
    local archive_name="${OUTPUT_DIR}.tar.gz"
    
    tar -czf "$archive_name" "$OUTPUT_DIR" 2>/dev/null
    
    if [ -f "$archive_name" ]; then
        local size=$(du -h "$archive_name" | cut -f1)
        print_success "Archive created: $archive_name (Size: $size)"
        
        echo ""
        print_info "To extract: tar -xzf $archive_name"
    else
        print_error "Failed to create archive"
    fi
}

# Main execution
main() {
    print_banner
    
    print_info "Starting must-gather collection..."
    echo ""
    
    # Setup
    setup_output_directory
    
    # Collect information
    collect_system_info
    collect_collector_logs
    collect_collector_config
    
    # Finalize
    create_summary
    create_archive
    
    # Final message
    echo ""
    print_banner
    print_success "Must-gather collection completed successfully!"
    echo ""
    print_info "Output directory: $OUTPUT_DIR"
    print_info "Archive file: ${OUTPUT_DIR}.tar.gz"
    echo ""
    print_info "Please share the archive file for analysis"
}

# Run main function
main
