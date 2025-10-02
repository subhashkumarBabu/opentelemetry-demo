# Azure Deployment Scripts

This directory contains scripts to help you deploy and manage the OpenTelemetry Demo on Azure Kubernetes Service (AKS).

## Available Scripts

### deploy-to-azure-aks.sh

Automates the deployment of OpenTelemetry Demo to Azure Kubernetes Service.

**Usage:**

```bash
# Use default configuration
./scripts/deploy-to-azure-aks.sh

# Or customize with environment variables
RESOURCE_GROUP=my-rg \
CLUSTER_NAME=my-cluster \
LOCATION=westus2 \
NODE_COUNT=2 \
./scripts/deploy-to-azure-aks.sh
```

**Environment Variables:**

- `RESOURCE_GROUP` (default: `otel-demo-rg`) - Azure resource group name
- `CLUSTER_NAME` (default: `otel-demo-cluster`) - AKS cluster name
- `LOCATION` (default: `eastus`) - Azure region
- `NODE_COUNT` (default: `3`) - Number of nodes in the cluster
- `NODE_VM_SIZE` (default: `Standard_D4s_v3`) - VM size for nodes
- `NAMESPACE` (default: `otel-demo`) - Kubernetes namespace

**What it does:**

1. Checks for required tools (Azure CLI, kubectl, Helm)
2. Creates an Azure resource group
3. Creates an AKS cluster
4. Configures kubectl with cluster credentials
5. Deploys OpenTelemetry Demo using Helm
6. Waits for the external IP and displays access information

### cleanup-azure-aks.sh

Cleans up resources created by the deployment script.

**Usage:**

```bash
./scripts/cleanup-azure-aks.sh
```

**Options:**

When you run the script, you'll be presented with interactive options:

1. **Uninstall Helm release only** - Removes the OpenTelemetry Demo but keeps the AKS cluster running
2. **Delete AKS cluster** - Deletes the cluster but keeps the resource group
3. **Delete entire resource group** - Removes all resources including the cluster and resource group

**Environment Variables:**

- `RESOURCE_GROUP` (default: `otel-demo-rg`) - Azure resource group name
- `CLUSTER_NAME` (default: `otel-demo-cluster`) - AKS cluster name
- `NAMESPACE` (default: `otel-demo`) - Kubernetes namespace

## Prerequisites

Before running these scripts, ensure you have:

1. **Azure CLI** - [Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **kubectl** - [Installation Guide](https://kubernetes.io/docs/tasks/tools/)
3. **Helm 3** - [Installation Guide](https://helm.sh/docs/intro/install/)
4. An active Azure subscription

## Quick Start Example

```bash
# 1. Clone the repository
git clone https://github.com/open-telemetry/opentelemetry-demo.git
cd opentelemetry-demo

# 2. Login to Azure
az login

# 3. Deploy to Azure
./scripts/deploy-to-azure-aks.sh

# 4. Wait for deployment to complete and note the external IP

# 5. Access the demo
# Open http://<EXTERNAL-IP>:8080 in your browser

# 6. When done, cleanup resources
./scripts/cleanup-azure-aks.sh
```

## Cost Optimization Tips

### Development/Testing Environment

For development or testing, you can reduce costs by using smaller VM sizes and fewer nodes:

```bash
RESOURCE_GROUP=otel-demo-dev-rg \
CLUSTER_NAME=otel-demo-dev \
NODE_COUNT=2 \
NODE_VM_SIZE=Standard_D2s_v3 \
./scripts/deploy-to-azure-aks.sh
```

### Stop/Start Cluster

To save costs when not using the cluster:

```bash
# Stop the cluster
az aks stop --name otel-demo-cluster --resource-group otel-demo-rg

# Start the cluster when needed
az aks start --name otel-demo-cluster --resource-group otel-demo-rg
```

## Troubleshooting

### Script fails with "command not found"

Ensure all prerequisites are installed:

```bash
# Check Azure CLI
az --version

# Check kubectl
kubectl version --client

# Check Helm
helm version
```

### Pods not starting

Check pod status and logs:

```bash
kubectl get pods -n otel-demo
kubectl describe pod <pod-name> -n otel-demo
kubectl logs <pod-name> -n otel-demo
```

### External IP not assigned

Check service status:

```bash
kubectl get svc -n otel-demo
kubectl describe svc opentelemetry-demo-frontendproxy -n otel-demo
```

## More Information

For comprehensive deployment documentation, see [docs/azure-deployment.md](../docs/azure-deployment.md).
