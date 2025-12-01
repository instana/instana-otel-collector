# IDOT Operator Deployment Guide

This guide covers the installation, configuration, and management of the Instana Distributed OpenTelemetry (IDOT) Collector using the OpenTelemetry Operator deployment method.

## Overview

The IDOT Operator chart deploys Instana's OpenTelemetry collectors for Kubernetes monitoring using the **OpenTelemetry Operator**. This approach provides a Kubernetes-native way to manage OpenTelemetry collectors through Custom Resources (CRs).

The deployment consists of:
- **OpenTelemetry Operator**: Manages the lifecycle of OpenTelemetry Collector instances
- **DaemonSet Collector**: Runs on every node to collect host-level metrics, kubelet stats, and logs
- **StatefulSet Collector**: Runs as a single instance to collect cluster-level metrics and Kubernetes events

## Operator vs Standard Helm Deployment

### Operator-Based Deployment (This Chart)

**Advantages:**
- **Declarative Management**: Define collectors as Custom Resources (CRs) that the operator manages
- **Automatic Updates**: Operator handles rolling updates and configuration changes automatically
- **Self-Healing**: Operator ensures desired state is maintained, automatically recreating failed collectors
- **Dynamic Configuration**: Update collector configuration by modifying CRs without redeploying the entire chart
- **Simplified Lifecycle**: Operator handles complex deployment scenarios (upgrades, rollbacks, scaling)
- **Webhook Validation**: Automatic validation of collector configurations before deployment
- **Multi-Collector Management**: Easily manage multiple collector instances with different configurations

**Trade-offs:**
- Additional operator pod consuming cluster resources (~100m CPU, 128Mi memory)
- Slightly more complex architecture with CRDs and webhooks
- Requires understanding of OpenTelemetry Operator CRs

**Use Cases:**
- Production environments requiring high availability and self-healing
- Clusters with frequent configuration changes
- Organizations following GitOps practices
- Environments requiring advanced lifecycle management
- Multi-tenant clusters with multiple collector instances

### Standard Helm Deployment

**Advantages:**
- **Simpler Architecture**: Direct deployment without operator overhead
- **Lower Resource Usage**: No operator pod consuming resources
- **Faster Initial Deployment**: No need to wait for operator to be ready
- **Direct Control**: Helm directly manages all resources
- **Easier Debugging**: Fewer abstraction layers to troubleshoot

**Trade-offs:**
- Manual helm upgrade required for configuration changes
- No automatic self-healing beyond Kubernetes native capabilities
- More complex to manage multiple collector instances

**Use Cases:**
- Development and testing environments
- Smaller clusters with limited resources
- Simple, static configurations that rarely change
- Teams preferring direct Helm management

### Key Differences

| Feature | Operator-Based | Standard Helm |
|---------|---------------|---------------|
| **Management** | Operator manages collectors via CRs | Helm directly manages all resources |
| **Updates** | Automatic rolling updates | Manual `helm upgrade` required |
| **Configuration Changes** | Edit CR, operator applies changes | `helm upgrade` required |
| **Resource Overhead** | Operator pod + collectors | Collectors only |
| **Complexity** | Higher (operator + CRDs) | Lower (direct deployment) |
| **Self-Healing** | Automatic via operator reconciliation | Kubernetes native only |
| **Validation** | Webhook validation of configs | Helm template validation |
| **Multi-Instance** | Easy via multiple CRs | Requires multiple releases |

## Prerequisites

- Kubernetes 1.24+
- Helm 3.9+
- Docker
- kubectl

### Optional

- **OpenShift**: For OpenShift clusters, ensure you have the appropriate Security Context Constraints (SCCs)

## Installation

### Step 1: Install the Operator Chart

The chart automatically installs the OpenTelemetry Operator and creates the collector Custom Resources.

#### Basic Installation

```bash
helm install idot-operator \
  --repo https://instana.github.io/instana-otel-collector instana-otel-collector-chart-operator \
  --namespace idot-operator \
  --create-namespace \
  --set clusterName=<CLUSTER_NAME> \
  --set instanaEndpoint=<INSTANA_ENDPOINT> \
  --set instanaKey=<INSTANA_KEY> \
  --set daemonset.enabled=true \
  --set statefulset.enabled=true
```

> [!NOTE]
> `<CLUSTER_NAME>`, `<INSTANA_ENDPOINT>` and `<INSTANA_KEY>` are mandatory parameters that need to be set when running the command.
> `--create-namespace` flag is used to create the namespace if it wasn't created before. It can be omitted if the namespace was created manually before.

#### OpenShift Installation

For OpenShift clusters, use the same command:

```bash
helm install idot-operator \
  --repo https://instana.github.io/instana-otel-collector instana-otel-collector-chart-operator \
  --namespace idot-operator \
  --create-namespace \
  --set clusterName=<CLUSTER_NAME> \
  --set instanaEndpoint=<INSTANA_ENDPOINT> \
  --set instanaKey=<INSTANA_KEY> \
  --set daemonset.enabled=true \
  --set statefulset.enabled=true
```

### Step 2: Verify Installation

#### Wait for Operator to be Ready

The chart includes a post-install hook that waits for the operator to be ready:

```bash
# Check the wait-for-operator job
kubectl get jobs -n idot-operator
```

Expected output:
```
NAME                                      COMPLETIONS   DURATION   AGE
idot-operator-wait-for-operator           1/1           30s        2m
```

Verify the operator pod is running:
```bash
kubectl get pods -n idot-operator -l app.kubernetes.io/name=opentelemetry-operator
```

Expected output:
```
NAME                                    READY   STATUS    RESTARTS   AGE
instana-otel-operator-xxxxxxxxxx-xxxxx  1/1     Running   0          2m
```

#### Verify OpenTelemetryCollector CRs

Check that the Custom Resources were created:

```bash
kubectl get opentelemetrycollector -n idot-operator
```

Expected output:
```
NAME                       MODE          VERSION   READY   AGE
idot-daemonset-collector   daemonset     latest    True    2m
idot-statefulset-collector statefulset   latest    True    2m
```

#### Verify Collector Pods

Check DaemonSet Collector (should be one per node) and StatefulSet Collector:

```bash
kubectl get pods -n idot-operator
```

### Step 3: Verify Data Collection

Check collector logs to ensure data is being sent to Instana:

```bash
# Check DaemonSet collector logs
kubectl logs -n idot-operator -l app.kubernetes.io/name=idot-daemonset-collector --tail=50

# Check StatefulSet collector logs
kubectl logs -n idot-operator -l app.kubernetes.io/name=idot-statefulset-collector --tail=50
```

Look for successful export messages and no error logs. If these steps were successful, then that means the Collectors managed by the operator are successfully sending data to Instana!

## Configuration

### Viewing Current Configuration

#### View OpenTelemetryCollector Custom Resources

```bash
# View DaemonSet collector CR
kubectl get opentelemetrycollector idot-daemonset-collector -n idot-operator -o yaml

# View StatefulSet collector CR
kubectl get opentelemetrycollector idot-statefulset-collector -n idot-operator -o yaml
```

### Modifying Collector Configuration

Edit the OpenTelemetryCollector CR directly using `kubectl` or `oc`:

**Using kubectl:**
```bash
kubectl edit opentelemetrycollector idot-daemonset-collector -n idot-operator
```

**Using oc (OpenShift):**
```bash
oc edit opentelemetrycollector idot-daemonset-collector -n idot-operator
```

This opens the CR YAML in your default shell editor (e.g., vi, nano). Make your changes, save, and exit. The operator will automatically detect the changes and perform a rolling update of the affected collector pods.

**Example: Changing log level**
```yaml
spec:
  config: |
    service:
      telemetry:
        logs:
          level: debug  # Change from info to debug
```

## Troubleshooting

### Common Issues

#### 1. Operator Pod Not Starting

**Symptoms**: Operator pod in CrashLoopBackOff or Pending state

**Diagnosis**:
```bash
kubectl describe pod -n idot-operator \
  -l app.kubernetes.io/name=opentelemetry-operator

kubectl logs -n idot-operator \
  -l app.kubernetes.io/name=opentelemetry-operator
```

**Solutions**:
- Check if CRDs are installed: `kubectl get crd | grep opentelemetry`
- Verify webhook certificates: `kubectl get secret -n idot-operator`
- Check resource limits and node capacity
- Ensure the namespace has sufficient resources

#### 2. Collector Pods Not Created

**Symptoms**: OpenTelemetryCollector CR exists but no pods are created

**Diagnosis**:
```bash
kubectl get opentelemetrycollector -n idot-operator -o yaml
kubectl describe opentelemetrycollector idot-daemonset-collector -n idot-operator
```

**Solutions**:
- Check operator logs for errors:
  ```bash
  kubectl logs -n idot-operator -l app.kubernetes.io/name=opentelemetry-operator
  ```
- Verify the CR spec is valid
- Check RBAC permissions
- Ensure the image is accessible

#### 3. Collectors Not Sending Data to Instana

**Symptoms**: Collectors running but no data appearing in Instana

**Diagnosis**:
```bash
# Check collector logs for export errors
kubectl logs -n idot-operator <pod-name> | grep -iE "error|fail"

# Check exporter configuration
kubectl get opentelemetrycollector idot-daemonset-collector -n idot-operator -o yaml | grep -A 10 exporters
```

**Solutions**:
- Verify `instanaEndpoint` is correct (including port 4317)
- Verify `instanaKey` is correct
- Check network connectivity to Instana backend:
  ```bash
  kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
    curl -v <INSTANA_BACKEND_ENDPOINT>
  ```
- Verify TLS settings in exporter configuration
- Check for firewall or network policy restrictions


### Getting Help

For additional troubleshooting:

1. **Check Documentation**:
   - Main troubleshooting guide: `docs/troubleshooting.md`
   - RBAC permission fix: `docs/rbac-permission-fix.md`

2. **Collect Diagnostic Information**:
   ```bash
   # Collect all relevant logs
   kubectl logs -n idot-operator -l app.kubernetes.io/name=opentelemetry-operator > operator-logs.txt
   kubectl logs -n idot-operator -l app.kubernetes.io/name=idot-daemonset-collector --tail=500 > daemonset-logs.txt
   kubectl logs -n idot-operator -l app.kubernetes.io/name=idot-statefulset-collector --tail=500 > statefulset-logs.txt
   
   # Get CR definitions
   kubectl get opentelemetrycollector -n idot-operator -o yaml > collectors-cr.yaml
   
   # Get cluster info
   kubectl cluster-info > cluster-info.txt
   kubectl get nodes > nodes.txt
   ```

3. **Consult Resources**:
   - OpenTelemetry Operator documentation: https://github.com/open-telemetry/opentelemetry-operator
   - Instana documentation: https://www.ibm.com/docs/en/instana-observability
   - Contact Instana support with collected diagnostic information

## Uninstallation

### Complete Uninstallation

The chart includes an automatic cleanup hook that removes all resources:

```bash
helm uninstall idot-operator -n idot-operator
```

This will:
1. Remove finalizers from OpenTelemetryCollector resources
2. Delete all OpenTelemetryCollector custom resources
3. Clean up all workloads (DaemonSets, StatefulSets, Pods)
4. Remove services, secrets, and config maps
5. Delete RBAC resources
6. Remove webhook configurations
7. Delete the operator deployment

### Verify Cleanup

```bash
# Check for remaining resources
kubectl get all -n idot-operator

# Check for OpenTelemetryCollector CRs
kubectl get opentelemetrycollector -n idot-operator

# Check for CRDs (these may remain if used by other installations)
kubectl get crd | grep opentelemetry
```

### Delete Namespace

If you want to completely remove the namespace:

```bash
kubectl delete namespace idot-operator
```

### Manual Cleanup (if needed)

If automatic cleanup fails or gets stuck (Usually on OCP):

```bash
# Remove finalizers from CRs
oc patch opentelemetrycollector idot-daemonset -n idot-operator -p '{"metadata":{"finalizers":[]}}' --type=merge
oc patch opentelemetrycollector idot-statefulset -n idot-operator -p '{"metadata":{"finalizers":[]}}' --type=merge        
```

### Preserve Configuration for Reinstallation

To uninstall but keep configuration for later:

```bash
# Backup before uninstalling
helm get values idot-operator -n idot-operator > idot-values-backup.yaml
kubectl get opentelemetrycollector -n idot-operator -o yaml > idot-collectors-backup.yaml

# Uninstall
helm uninstall idot-operator -n idot-operator

# Reinstall later with same configuration
helm install idot-operator \
  --repo https://instana.github.io/instana-otel-collector instana-otel-collector-chart-operator \
  --values idot-values-backup.yaml \
  --namespace idot-operator \
  --create-namespace
```

## Additional Resources

- [Main Documentation](../README.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [RBAC Permission Fix](./rbac-permission-fix.md)
- [OpenTelemetry Operator Documentation](https://github.com/open-telemetry/opentelemetry-operator)
- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Instana Documentation](https://www.ibm.com/docs/en/instana-observability)

