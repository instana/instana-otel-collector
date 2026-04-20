#!/bin/bash

# Kubernetes OpenTelemetry Collector Must-Gather Script
# Collects diagnostic information from OTel Collector deployed via Helm
# Usage: ./k8s-must-gather.sh [namespace] [release-name]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_NAMESPACE="default"
DEFAULT_RELEASE_NAME="opentelemetry-collector"

# Parse arguments
NAMESPACE="${1:-$DEFAULT_NAMESPACE}"
RELEASE_NAME="${2:-$DEFAULT_RELEASE_NAME}"

# Output directory setup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="k8s-otel-must-gather-${TIMESTAMP}"

# Banner
print_banner() {
    echo -e "${BLUE}========================================================${NC}"
    echo -e "${BLUE}  Kubernetes OpenTelemetry Collector Must-Gather Tool${NC}"
    echo -e "${BLUE}========================================================${NC}"
    echo ""
}

# Print section header
print_section() {
    echo -e "\n${CYAN}>>> $1${NC}"
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
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check required tools
check_dependencies() {
    print_section "Checking dependencies"
    
    local missing_tools=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All required tools are available"
}

# Create output directory structure
setup_output_directory() {
    print_section "Setting up output directory"
    
    mkdir -p "$OUTPUT_DIR"/{pods,configmaps,logs}
    
    print_success "Created output directory: $OUTPUT_DIR"
}

# Collect pod information
collect_pod_info() {
    print_section "Collecting pod information"
    
    local pods_dir="$OUTPUT_DIR/pods"
    
    # Get pods with label selector for OTel Collector
    local label_selector="app.kubernetes.io/instance=${RELEASE_NAME}"
    
    # List pods
    kubectl get pods -n "$NAMESPACE" -l "$label_selector" -o wide > "$pods_dir/pods-list.txt" 2>&1
    
    local pod_count=$(kubectl get pods -n "$NAMESPACE" -l "$label_selector" --no-headers 2>/dev/null | wc -l)
    
    if [ "$pod_count" -eq 0 ]; then
        print_error "No pods found with label: $label_selector"
        return 1
    fi
    
    print_success "Found $pod_count pod(s)"
    
    # Describe pods
    kubectl describe pods -n "$NAMESPACE" -l "$label_selector" > "$pods_dir/pods-describe.txt" 2>&1
    print_success "Collected pod descriptions"
    
    # Get pod resource usage
    kubectl top pods -n "$NAMESPACE" -l "$label_selector" > "$pods_dir/pods-top.txt" 2>&1 || echo "Metrics server not available" > "$pods_dir/pods-top.txt"
    print_success "Collected pod resource usage"
}

# Collect pod logs
collect_pod_logs() {
    print_section "Collecting pod logs"
    
    local logs_dir="$OUTPUT_DIR/logs"
    local label_selector="app.kubernetes.io/instance=${RELEASE_NAME}"
    
    # Get all pods
    local pods=$(kubectl get pods -n "$NAMESPACE" -l "$label_selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$pods" ]; then
        print_error "No pods found to collect logs"
        return 1
    fi
    
    for pod in $pods; do
        print_info "Collecting logs from pod: $pod"
        
        # Get container names
        local containers=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
        
        for container in $containers; do
            # Current logs
            kubectl logs "$pod" -n "$NAMESPACE" -c "$container" > "$logs_dir/${pod}-${container}.log" 2>&1
            print_success "  Collected current logs: $container"
            
            # Previous logs (if pod restarted)
            if kubectl logs "$pod" -n "$NAMESPACE" -c "$container" --previous &> /dev/null; then
                kubectl logs "$pod" -n "$NAMESPACE" -c "$container" --previous > "$logs_dir/${pod}-${container}-previous.log" 2>&1
                print_success "  Collected previous logs: $container"
            fi
        done
    done
}

# Collect ConfigMap information
collect_configmap_info() {
    print_section "Collecting ConfigMap information"
    
    local cm_dir="$OUTPUT_DIR/configmaps"
    local label_selector="app.kubernetes.io/instance=${RELEASE_NAME}"
    
    # List ConfigMaps
    kubectl get configmaps -n "$NAMESPACE" -l "$label_selector" > "$cm_dir/configmaps-list.txt" 2>&1
    
    # Get ConfigMaps YAML
    kubectl get configmaps -n "$NAMESPACE" -l "$label_selector" -o yaml > "$cm_dir/configmaps.yaml" 2>&1
    print_success "Collected ConfigMaps"
    
    # Extract config.yaml from ConfigMap
    local configmaps=$(kubectl get configmaps -n "$NAMESPACE" -l "$label_selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    for cm in $configmaps; do
        # Try to extract config.yaml or relay.yaml (common keys)
        kubectl get configmap "$cm" -n "$NAMESPACE" -o jsonpath='{.data.relay}' > "$cm_dir/${cm}-config.yaml" 2>/dev/null || \
        kubectl get configmap "$cm" -n "$NAMESPACE" -o jsonpath='{.data.config\.yaml}' > "$cm_dir/${cm}-config.yaml" 2>/dev/null || \
        kubectl get configmap "$cm" -n "$NAMESPACE" -o yaml > "$cm_dir/${cm}-full.yaml" 2>/dev/null
        
        if [ -s "$cm_dir/${cm}-config.yaml" ]; then
            print_success "Extracted config from ConfigMap: $cm"
        fi
    done
}

# Create summary report
create_summary() {
    print_section "Creating summary report"
    
    local summary_file="$OUTPUT_DIR/SUMMARY.txt"
    
    cat > "$summary_file" << EOF
Kubernetes OpenTelemetry Collector Must-Gather Report
=====================================================
Collection Date: $(date)
Output Directory: $OUTPUT_DIR

Cluster Information:
-------------------
Namespace: $NAMESPACE
Release Name: $RELEASE_NAME
Kubectl Context: $(kubectl config current-context)

Contents:
---------
- pods/            : Pod information (list, describe, YAML)
- logs/            : OpenTelemetry Collector pod logs
- configmaps/      : ConfigMaps and extracted config.yaml

Pod Summary:
-----------
EOF

    local label_selector="app.kubernetes.io/instance=${RELEASE_NAME}"
    kubectl get pods -n "$NAMESPACE" -l "$label_selector" --no-headers 2>/dev/null >> "$summary_file" || echo "No pods found" >> "$summary_file"
    
    echo "" >> "$summary_file"
    echo "Service Summary:" >> "$summary_file"
    echo "---------------" >> "$summary_file"
    kubectl get services -n "$NAMESPACE" -l "$label_selector" --no-headers 2>/dev/null >> "$summary_file" || echo "No services found" >> "$summary_file"
    
    print_success "Summary report created"
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
    
    print_info "Namespace: $NAMESPACE"
    print_info "Release Name: $RELEASE_NAME"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Setup
    setup_output_directory
    
    # Collect information
    collect_pod_info
    collect_pod_logs
    collect_configmap_info
    
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
