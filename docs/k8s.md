# Kubernetes Deployment Guide

The recommended way to deploy IDOT on Kubernetes is using Helm.

## Prerequisites

- Kubernetes 1.24+
- Helm 3.9+
- Docker
- kubectl

## Helm Chart

Helm is a package manager for Kubernetes. It allows you to define, install, and upgrade complex Kubernetes applications.

### Installation

#### Step 1: Create a Namespace (Optional but Recommended)

First, create a dedicated namespace for IDOT:

```bash
kubectl create namespace instana-collector
```

#### Step 2: Install IDOT

```bash
helm install instana-otel-collector \
  --repo https://instana.github.io/instana-otel-collector instana-otel-collector-chart \
  --namespace instana-otel-collector \
  --create-namespace \
  --set clusterName=<CLUSTER_NAME> \
  --set instanaEndpoint=<INSTANA_ENDPOINT> \
  --set instanaKey=<INSTANA_KEY>
```

> [!NOTE]
> `<CLUSTER_NAME>`, `<INSTANA_ENDPOINT>` and `<INSTANA_KEY>` are mandatory parameters that need to be set when running the command.
> `--create-namespace` flag is used to create the namespace if it wasn't created before. It can be ommitted if the namespace was created manually before.

#### Step 3: Verify the Installation

After installation, verify that the collector is running:

```bash
kubectl get pods -n instana-collector
```

If everything went successfully the above command should output something like this:
```bash
NAME                         READY   STATUS    RESTARTS   AGE
idot-daemonset-agent-szpth   1/1     Running   0          55s
idot-statefulset-0           1/1     Running   0          55s
```

Keep in mind that the age your deployment and the id of the pod will vary depending on when you ran the installation command i.e `szpth` in `idot-daemonset-agent-szpth`. 

On the Instana UI, you should see the newly installed collector in the Cluster under `Platforms -> Kubernetes -> Opentelemetry Collectors` showing up as `<CLUSTER_NAME>`.

The logs of the pods can be checked using:

```bash
kubectl logs -n instana-collector  <NAME_OF_DEPLOYMENT>
```

You can also check the Helm release:

```bash
helm list -n instana-collector
```

### Upgrading

To upgrade IDOT with new configuration:

```bash
helm upgrade instana-otel-collector \
  --repo https://instana.github.io/instana-otel-collector instana-otel-collector-chart \
  --namespace instana-otel-collector \
```

#### Check Collector Status

```bash
kubectl describe pod -n instana-collector <NAME_OF_DEPLOYMENT>
```

### Uninstallation

To uninstall the Helm chart:

```bash
helm uninstall idot -n instana-collector
```

To completely remove all resources, including the namespace:

```bash
kubectl delete namespace instana-collector
```

## OpenShift Deployment

### Prerequisites for OpenShift

When targeting an OpenShift 4.x cluster, ensure proper permission before installing the helm chart, otherwise the agent pods will not be scheduled correctly. Once logged into your OpenShift cluster, run:

#### Step 1: Create a Namespace (Optional but Recommended)

```bash
oc new-project instana-collector
oc adm policy add-scc-to-user privileged -z instana-collector -n instana-collector
```

#### Step 2: Install IDOT

```bash
helm install instana-otel-collector \
  --repo https://instana.github.io/instana-otel-collector instana-otel-collector-chart \
  --namespace instana-otel-collector \
  --create-namespace \
  --set clusterName=<CLUSTER_NAME> \
  --set instanaEndpoint=<INSTANA_ENDPOINT> \
  --set instanaKey=<INSTANA_KEY>
```

### Step 3: Verify OpenShift Installation 

If you are using OpenShift, you can check pods using:

```bash
oc get pods
```

The `kubectl` from above can also be used:

```bash
kubectl get pods -n instana-collector
```

Checking logs and status of the pods is the same as for Kubernetes:

```bash
kubectl logs -n instana-collector  <NAME_OF_DEPLOYMENT>
```

```bash
kubectl describe pod -n instana-collector <NAME_OF_DEPLOYMENT>
```

### OpenShift Security Configuration

For OpenShift clusters, the chart automatically creates a privileged ServiceAccount and SecurityContextConstraints when `openshift.daemonset.usePrivilegedServiceAccount` is set to `true` (default). This grants access to host paths, network, processes, and allows running as a privileged container - necessary permissions for collecting comprehensive metrics from your cluster. For this reason, a warning may appear regarding PodSecurity during the installation command.

### Uninstalling from OpenShift

Run the uninstall Helm chart command:

```bash
helm uninstall idot -n instana-collector
```

To delete the project from OpenShift cluster:
```bash
oc delete project instana-collector
```

## Switching Between OpenShift and Kubernetes Contexts

If you're working with both OpenShift and Kubernetes clusters, you might encounter errors when running `kubectl` commands if your current context is set to the wrong platform. Here's how to switch between contexts:

1. List all available contexts:

```bash
kubectl config get-contexts
```

This will list the Name, Cluster, Namespace and AuthInfo for each context. Use the name to switch context.

2. Switch to a Kubernetes context:

```bash
kubectl config use-context <kubernetes-context-name>
```

3. Switch to an OpenShift context:

```bash
kubectl config use-context <openshift-context-name>
```

## Advanced

### Configuration Options

#### Common Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `clusterName` | Name of the Kubernetes cluster | Required |
| `instanaEndpoint` | Instana backend endpoint host | Required |
| `instanaKey` | Instana agent key | Required |
| `resources.limits.cpu` | CPU limits for the collector | `1.5` |
| `resources.limits.memory` | Memory limits for the collector | `768Mi` |
| `resources.requests.cpu` | CPU requests for the collector | `0.5` |
| `resources.requests.memory` | Memory requests for the collector | `768Mi` |
| `env` | Additional environment variables | `{}` |

#### Pod Security Requirements

The daemonset deployment requires elevated permissions to collect host-level metrics.

##### Custom TLS Certificates

If you need to use custom TLS certificates:

```yaml
tls:
  enabled: true
  # Use an existing secret
  secretName: "my-tls-secret"
  # Or provide certificate and key directly
  certificate: "base64-encoded-certificate"
  key: "base64-encoded-key"
```

#### Troubleshooting 

Best way to troubleshoot is to check the logs of the collector pod.

#### Check Collector Logs

```bash
kubectl logs -n instana-collector <NAME_OF_DEPLOYMENT>
```
Another way to do this is by the `describe` command:

```bash
kubectl describe pod -n instana-collector -l app=idot
```

#### Namespace Deletion

If the namespace deletion command hangs or gets stuck in the "Terminating" state, you can force remove the finalizers with the following command:

```bash
kubectl get namespace instana-collector -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/instana-collector/finalize" -f -
```

Always ensure you uninstall the Helm chart before deleting the namespace to minimize the chance of this happening.