#!/bin/bash
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0

# Deploy OpenTelemetry Demo to Azure Kubernetes Service (AKS)
# This script automates the deployment of OpenTelemetry Demo to AKS

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it from https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install it from https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    print_info "All prerequisites are installed."
}

# Set default values
RESOURCE_GROUP="${RESOURCE_GROUP:-otel-demo-rg}"
CLUSTER_NAME="${CLUSTER_NAME:-otel-demo-cluster}"
LOCATION="${LOCATION:-eastus}"
NODE_COUNT="${NODE_COUNT:-3}"
NODE_VM_SIZE="${NODE_VM_SIZE:-Standard_D4s_v3}"
NAMESPACE="${NAMESPACE:-otel-demo}"

# Display configuration
print_config() {
    print_info "Deployment Configuration:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Cluster Name: $CLUSTER_NAME"
    echo "  Location: $LOCATION"
    echo "  Node Count: $NODE_COUNT"
    echo "  Node VM Size: $NODE_VM_SIZE"
    echo "  Namespace: $NAMESPACE"
    echo ""
}

# Check if user is logged in to Azure
check_azure_login() {
    print_info "Checking Azure login status..."
    if ! az account show &> /dev/null; then
        print_warn "Not logged in to Azure. Please login."
        az login
    else
        print_info "Already logged in to Azure."
        SUBSCRIPTION=$(az account show --query name -o tsv)
        print_info "Using subscription: $SUBSCRIPTION"
    fi
}

# Create resource group
create_resource_group() {
    print_info "Creating resource group: $RESOURCE_GROUP..."
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warn "Resource group $RESOURCE_GROUP already exists."
    else
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        print_info "Resource group created successfully."
    fi
}

# Create AKS cluster
create_aks_cluster() {
    print_info "Creating AKS cluster: $CLUSTER_NAME..."
    print_warn "This may take 5-10 minutes..."
    
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" &> /dev/null; then
        print_warn "AKS cluster $CLUSTER_NAME already exists."
    else
        az aks create \
            --resource-group "$RESOURCE_GROUP" \
            --name "$CLUSTER_NAME" \
            --node-count "$NODE_COUNT" \
            --node-vm-size "$NODE_VM_SIZE" \
            --enable-managed-identity \
            --generate-ssh-keys \
            --network-plugin azure \
            --enable-addons monitoring \
            --yes
        print_info "AKS cluster created successfully."
    fi
}

# Get AKS credentials
get_aks_credentials() {
    print_info "Getting AKS credentials..."
    az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing
    print_info "Credentials configured successfully."
}

# Deploy OpenTelemetry Demo using Helm
deploy_otel_demo() {
    print_info "Adding OpenTelemetry Helm repository..."
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update
    
    print_info "Creating namespace: $NAMESPACE..."
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    print_info "Installing OpenTelemetry Demo..."
    helm upgrade --install opentelemetry-demo open-telemetry/opentelemetry-demo \
        --namespace "$NAMESPACE" \
        --set frontendProxy.service.type=LoadBalancer \
        --wait \
        --timeout 10m
    
    print_info "OpenTelemetry Demo installed successfully."
}

# Wait for external IP
wait_for_external_ip() {
    print_info "Waiting for external IP to be assigned..."
    print_warn "This may take a few minutes..."
    
    local count=0
    local max_attempts=60
    
    while [ $count -lt $max_attempts ]; do
        EXTERNAL_IP=$(kubectl get service opentelemetry-demo-frontendproxy -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        
        if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
            print_info "External IP assigned: $EXTERNAL_IP"
            echo ""
            echo "=========================================="
            echo "🎉 Deployment completed successfully!"
            echo "=========================================="
            echo ""
            echo "Access the OpenTelemetry Demo at:"
            echo "  http://$EXTERNAL_IP:8080"
            echo ""
            echo "Access observability tools:"
            echo "  Jaeger UI:  kubectl port-forward -n $NAMESPACE svc/opentelemetry-demo-jaeger-query 16686:16686"
            echo "              Then open http://localhost:16686"
            echo ""
            echo "  Grafana:    kubectl port-forward -n $NAMESPACE svc/opentelemetry-demo-grafana 3000:80"
            echo "              Then open http://localhost:3000"
            echo ""
            echo "To view pod status:"
            echo "  kubectl get pods -n $NAMESPACE"
            echo ""
            echo "To view logs:"
            echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=frontend"
            echo ""
            return 0
        fi
        
        echo -n "."
        sleep 5
        count=$((count + 1))
    done
    
    print_error "Timeout waiting for external IP. Check service status with:"
    print_error "  kubectl get svc -n $NAMESPACE"
    return 1
}

# Main deployment flow
main() {
    echo "=========================================="
    echo "OpenTelemetry Demo - Azure AKS Deployment"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    print_config
    
    read -p "Do you want to proceed with the deployment? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warn "Deployment cancelled."
        exit 0
    fi
    
    check_azure_login
    create_resource_group
    create_aks_cluster
    get_aks_credentials
    deploy_otel_demo
    wait_for_external_ip
    
    print_info "Deployment script completed!"
}

# Run main function
main
