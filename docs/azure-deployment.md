# Deploying OpenTelemetry Demo to Azure

This guide provides instructions for deploying the OpenTelemetry Demo application to Microsoft Azure using Azure Kubernetes Service (AKS).

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm 3](https://helm.sh/docs/intro/install/) installed
- An active Azure subscription

## Deployment Options

### Option 1: Azure Kubernetes Service (AKS) - Recommended

Azure Kubernetes Service (AKS) is the recommended approach for deploying the OpenTelemetry Demo to Azure as it provides a fully managed Kubernetes environment.

#### Step 1: Set up Azure CLI

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "<your-subscription-id>"

# Set environment variables
export RESOURCE_GROUP="otel-demo-rg"
export CLUSTER_NAME="otel-demo-cluster"
export LOCATION="eastus"  # Choose your preferred region
```

#### Step 2: Create Resource Group

```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

#### Step 3: Create AKS Cluster

```bash
# Create AKS cluster with recommended specifications
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --network-plugin azure \
  --enable-addons monitoring

# Get credentials for kubectl
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

#### Step 4: Deploy OpenTelemetry Demo using Helm

```bash
# Add OpenTelemetry Helm repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Create namespace
kubectl create namespace otel-demo

# Install the OpenTelemetry Demo
helm install opentelemetry-demo open-telemetry/opentelemetry-demo \
  --namespace otel-demo \
  --set frontendProxy.service.type=LoadBalancer

# Or use the Azure-optimized values file
# helm install opentelemetry-demo open-telemetry/opentelemetry-demo \
#   --namespace otel-demo \
#   -f docs/azure-values.yaml
```

#### Step 5: Access the Application

```bash
# Wait for the external IP to be assigned (may take a few minutes)
kubectl get service opentelemetry-demo-frontendproxy -n otel-demo --watch

# Once the EXTERNAL-IP is assigned, access the demo at:
# http://<EXTERNAL-IP>:8080
```

#### Step 6: Monitor Your Deployment

```bash
# Check all pods are running
kubectl get pods -n otel-demo

# View logs for a specific service (example: frontend)
kubectl logs -n otel-demo -l app.kubernetes.io/component=frontend

# Access Jaeger UI for traces
kubectl port-forward -n otel-demo svc/opentelemetry-demo-jaeger-query 16686:16686
# Then open http://localhost:16686

# Access Grafana for metrics
kubectl port-forward -n otel-demo svc/opentelemetry-demo-grafana 3000:80
# Then open http://localhost:3000
```

### Option 2: Azure Container Apps (Alternative)

Azure Container Apps is a serverless container platform suitable for simpler deployments. However, due to the complex multi-service architecture of the OpenTelemetry Demo, AKS is the recommended approach.

If you still want to use Azure Container Apps:

#### Prerequisites for Container Apps

- Azure Container Registry (ACR) to host your container images
- Each microservice needs to be deployed as a separate container app
- Proper networking configuration for service-to-service communication

#### Step 1: Create Azure Container Registry

```bash
export ACR_NAME="oteldemo${RANDOM}"
export RESOURCE_GROUP="otel-demo-rg"
export LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Standard
```

#### Step 2: Build and Push Images

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Clone the repository if you haven't already
# git clone https://github.com/open-telemetry/opentelemetry-demo.git
# cd opentelemetry-demo

# Build and push images to ACR (example for frontend)
docker build -f src/frontend/Dockerfile -t $ACR_NAME.azurecr.io/frontend:latest .
docker push $ACR_NAME.azurecr.io/frontend:latest

# Repeat for other services as needed
```

#### Step 3: Create Container Apps Environment

```bash
# Create Container Apps environment
az containerapp env create \
  --name otel-demo-env \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

#### Step 4: Deploy Services

Note: You'll need to deploy each microservice separately and configure environment variables for service discovery. This is complex for a multi-service application like OpenTelemetry Demo. Refer to [Azure Container Apps documentation](https://docs.microsoft.com/en-us/azure/container-apps/) for detailed instructions.

## Cost Optimization

### For Development/Testing

```bash
# Use smaller node sizes and fewer nodes
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 3
```

### Stop/Start Cluster to Save Costs

```bash
# Stop the cluster when not in use
az aks stop --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP

# Start the cluster when needed
az aks start --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

## Cleanup

When you're done with the demo, clean up resources to avoid charges:

```bash
# Delete the entire resource group (this removes everything)
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Or uninstall just the Helm release
helm uninstall opentelemetry-demo -n otel-demo
kubectl delete namespace otel-demo

# Delete AKS cluster only
az aks delete --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --yes
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n otel-demo

# Describe a pod to see events
kubectl describe pod <pod-name> -n otel-demo

# Check pod logs
kubectl logs <pod-name> -n otel-demo
```

### Resource constraints

If pods are failing due to insufficient resources:

```bash
# Scale up the node pool
az aks scale --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --node-count 4

# Or enable autoscaling
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 5
```

### Service not accessible

```bash
# Check service status
kubectl get svc -n otel-demo

# Check if LoadBalancer is provisioned
kubectl get svc opentelemetry-demo-frontendproxy -n otel-demo
```

## Configuration

### Azure-Specific Helm Values

An example Helm values file optimized for Azure is available at [docs/azure-values.yaml](azure-values.yaml). This file includes:

- Azure LoadBalancer configuration
- Resource limits optimized for common Azure VM sizes
- Optional Azure Monitor integration
- Persistent storage configuration using Azure Disks

To use this values file:

```bash
helm install opentelemetry-demo open-telemetry/opentelemetry-demo \
  --namespace otel-demo \
  -f docs/azure-values.yaml
```

## Additional Resources

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [OpenTelemetry Demo Documentation](https://opentelemetry.io/docs/demo/)
- [Helm Charts for OpenTelemetry Demo](https://github.com/open-telemetry/opentelemetry-helm-charts)
- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Azure-Specific Helm Values](azure-values.yaml)

## Support

For issues specific to:
- Azure deployment: Refer to [Azure Support](https://azure.microsoft.com/en-us/support/)
- OpenTelemetry Demo: Open an issue on [GitHub](https://github.com/open-telemetry/opentelemetry-demo/issues)
