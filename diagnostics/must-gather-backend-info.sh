#!/bin/bash

# Instana Core Resource Collection Script
# Purpose: Collect key configurations, Pod status and logs from instana-core namespace

set -e

# Configuration variables
NAMESPACE="instana-core"
RESOURCE_KIND="Core"
RESOURCE_NAME="instana-core"
OPAMP_LABEL="app.kubernetes.io/component=opamp-acceptor"
OTLP_LABEL="app.kubernetes.io/component=otlp-acceptor"
OUTPUT_DIR="instana-backend-$(date +%Y%m%d-%H%M%S)"
TAR_FILE="${OUTPUT_DIR}.tgz"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Instana Core Resource Collection Tool${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo -e "${YELLOW}[1/4] Creating output directory: $OUTPUT_DIR${NC}"

# Step 1: Collect Core resource configuration
echo -e "${YELLOW}[2/4] Collecting Core resource configuration...${NC}"
CONFIG_FILE="$OUTPUT_DIR/core-config.yaml"

if kubectl get "$RESOURCE_KIND" "$RESOURCE_NAME" -n "$NAMESPACE" &> /dev/null; then
    # Get complete resource definition
    kubectl get "$RESOURCE_KIND" "$RESOURCE_NAME" -n "$NAMESPACE" -o yaml > "$CONFIG_FILE"
    echo -e "${GREEN}  ✓ Core resource configuration saved${NC}"
else
    echo -e "${RED}  ✗ Resource not found: $RESOURCE_KIND/$RESOURCE_NAME${NC}"
fi

# Step 2 and 3: Collect Pod status, logs and image information
echo -e "${YELLOW}[3/4] Collecting Pod status, logs and image information...${NC}"

# Process OpAMP Acceptor Pods
echo -e "\n${GREEN}--- OpAMP Acceptor Pods ---${NC}"
OPAMP_PODS=$(kubectl get pods -n "$NAMESPACE" -l "$OPAMP_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -n "$OPAMP_PODS" ]; then
    mkdir -p "$OUTPUT_DIR/opamp-acceptor"
    
    for POD in $OPAMP_PODS; do
        echo -e "  Processing Pod: ${GREEN}$POD${NC}"
        
        # Detailed status
        kubectl describe pod "$POD" -n "$NAMESPACE" > "$OUTPUT_DIR/opamp-acceptor/${POD}-describe.txt"
       
        # Get logs
        CONTAINERS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}')
        for CONTAINER in $CONTAINERS; do
            echo "    Collecting container logs: $CONTAINER"
            kubectl logs "$POD" -n "$NAMESPACE" -c "$CONTAINER" --tail=1000 > "$OUTPUT_DIR/opamp-acceptor/${POD}-${CONTAINER}.log" 2>&1 || echo "Failed to get logs" > "$OUTPUT_DIR/opamp-acceptor/${POD}-${CONTAINER}.log"
            
            # Get previous logs (if Pod restarted)
            kubectl logs "$POD" -n "$NAMESPACE" -c "$CONTAINER" --previous --tail=1000 > "$OUTPUT_DIR/opamp-acceptor/${POD}-${CONTAINER}-previous.log" 2>&1 || rm -f "$OUTPUT_DIR/opamp-acceptor/${POD}-${CONTAINER}-previous.log"
        done
    done
    echo -e "${GREEN}  ✓ OpAMP Acceptor data collected${NC}"
else
    echo -e "${RED}  ✗ No OpAMP Acceptor Pods found${NC}"
fi

# Process OTLP Acceptor Pods
echo -e "\n${GREEN}--- OTLP Acceptor Pods ---${NC}"
OTLP_PODS=$(kubectl get pods -n "$NAMESPACE" -l "$OTLP_LABEL" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -n "$OTLP_PODS" ]; then
    mkdir -p "$OUTPUT_DIR/otlp-acceptor"
    
    for POD in $OTLP_PODS; do
        echo -e "  Processing Pod: ${GREEN}$POD${NC}"
        
        # Detailed status
        kubectl describe pod "$POD" -n "$NAMESPACE" > "$OUTPUT_DIR/otlp-acceptor/${POD}-describe.txt"
        
        # Get logs
        CONTAINERS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}')
        for CONTAINER in $CONTAINERS; do
            echo "    Collecting container logs: $CONTAINER"
            kubectl logs "$POD" -n "$NAMESPACE" -c "$CONTAINER" --tail=1000 > "$OUTPUT_DIR/otlp-acceptor/${POD}-${CONTAINER}.log" 2>&1 || echo "Failed to get logs" > "$OUTPUT_DIR/otlp-acceptor/${POD}-${CONTAINER}.log"
            
            # Get previous logs (if Pod restarted)
            kubectl logs "$POD" -n "$NAMESPACE" -c "$CONTAINER" --previous --tail=1000 > "$OUTPUT_DIR/otlp-acceptor/${POD}-${CONTAINER}-previous.log" 2>&1 || rm -f "$OUTPUT_DIR/otlp-acceptor/${POD}-${CONTAINER}-previous.log"
        done
    done
    echo -e "${GREEN}  ✓ OTLP Acceptor data collected${NC}"
else
    echo -e "${RED}  ✗ No OTLP Acceptor Pods found${NC}"
fi

# Step 4: Package to tgz file
echo -e "${YELLOW}[4/4] Packaging data to $TAR_FILE...${NC}"
tar -czf "$TAR_FILE" "$OUTPUT_DIR"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Packaging completed${NC}"
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}Collection Completed!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo -e "Output file: ${YELLOW}$TAR_FILE${NC}"
    echo -e "File size: $(du -h "$TAR_FILE" | cut -f1)"
    echo ""
    echo "To extract and view the data:"
    echo "  tar -xzf $TAR_FILE"
    echo ""
    
    # Optional: delete temporary directory
    read -p "Delete temporary directory $OUTPUT_DIR? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$OUTPUT_DIR"
        echo -e "${GREEN}Temporary directory deleted${NC}"
    fi
else
    echo -e "${RED}  ✗ Packaging failed${NC}"
    exit 1
fi
