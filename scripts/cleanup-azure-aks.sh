#!/bin/bash
# Copyright The OpenTelemetry Authors
# SPDX-License-Identifier: Apache-2.0

# Cleanup OpenTelemetry Demo from Azure Kubernetes Service (AKS)
# This script removes all resources created for the OpenTelemetry Demo

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

# Set default values
RESOURCE_GROUP="${RESOURCE_GROUP:-otel-demo-rg}"
CLUSTER_NAME="${CLUSTER_NAME:-otel-demo-cluster}"
NAMESPACE="${NAMESPACE:-otel-demo}"
DELETE_RESOURCE_GROUP="${DELETE_RESOURCE_GROUP:-false}"

# Display configuration
print_config() {
    print_info "Cleanup Configuration:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Cluster Name: $CLUSTER_NAME"
    echo "  Namespace: $NAMESPACE"
    echo ""
}

# Uninstall Helm release
uninstall_helm_release() {
    print_info "Uninstalling OpenTelemetry Demo Helm release..."
    
    if helm list -n "$NAMESPACE" | grep -q "opentelemetry-demo"; then
        helm uninstall opentelemetry-demo -n "$NAMESPACE"
        print_info "Helm release uninstalled successfully."
    else
        print_warn "Helm release not found in namespace $NAMESPACE."
    fi
}

# Delete namespace
delete_namespace() {
    print_info "Deleting namespace: $NAMESPACE..."
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        kubectl delete namespace "$NAMESPACE"
        print_info "Namespace deleted successfully."
    else
        print_warn "Namespace $NAMESPACE not found."
    fi
}

# Delete AKS cluster
delete_aks_cluster() {
    print_info "Deleting AKS cluster: $CLUSTER_NAME..."
    print_warn "This may take a few minutes..."
    
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" &> /dev/null; then
        az aks delete --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --yes --no-wait
        print_info "AKS cluster deletion initiated."
    else
        print_warn "AKS cluster $CLUSTER_NAME not found."
    fi
}

# Delete resource group
delete_resource_group() {
    print_info "Deleting resource group: $RESOURCE_GROUP..."
    print_warn "This will delete ALL resources in the resource group!"
    
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        az group delete --name "$RESOURCE_GROUP" --yes --no-wait
        print_info "Resource group deletion initiated."
    else
        print_warn "Resource group $RESOURCE_GROUP not found."
    fi
}

# Main cleanup flow
main() {
    echo "=========================================="
    echo "OpenTelemetry Demo - Azure AKS Cleanup"
    echo "=========================================="
    echo ""
    
    print_config
    
    echo "What would you like to cleanup?"
    echo "1) Uninstall Helm release only (keep cluster running)"
    echo "2) Delete AKS cluster (keep resource group)"
    echo "3) Delete entire resource group (removes everything)"
    echo "4) Cancel"
    echo ""
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            print_warn "This will uninstall the OpenTelemetry Demo but keep the AKS cluster."
            read -p "Are you sure? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                uninstall_helm_release
                delete_namespace
                print_info "Cleanup completed. AKS cluster is still running."
            else
                print_warn "Cleanup cancelled."
            fi
            ;;
        2)
            print_warn "This will delete the AKS cluster. The resource group will remain."
            read -p "Are you sure? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                delete_aks_cluster
                print_info "Cleanup initiated. Resource group $RESOURCE_GROUP will remain."
                print_info "You can delete it manually later with:"
                print_info "  az group delete --name $RESOURCE_GROUP --yes"
            else
                print_warn "Cleanup cancelled."
            fi
            ;;
        3)
            print_warn "⚠️  WARNING: This will delete ALL resources in the resource group: $RESOURCE_GROUP"
            print_warn "This action cannot be undone!"
            read -p "Are you absolutely sure? Type 'yes' to confirm: " confirmation
            if [ "$confirmation" = "yes" ]; then
                delete_resource_group
                print_info "Resource group deletion initiated."
                print_info "This may take several minutes to complete."
            else
                print_warn "Cleanup cancelled."
            fi
            ;;
        4)
            print_warn "Cleanup cancelled."
            exit 0
            ;;
        *)
            print_error "Invalid choice. Cleanup cancelled."
            exit 1
            ;;
    esac
    
    echo ""
    print_info "Cleanup script completed!"
}

# Run main function
main
