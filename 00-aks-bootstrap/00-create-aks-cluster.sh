#!/bin/bash
set -e

# ASO Lab - Phase 1: Create AKS Cluster Bootstrap
# This script creates a minimal AKS cluster for learning ASO and KRO

SUBSCRIPTION_ID="1aa6797c-bba1-4073-a0f8-e49d0e79fd4f"
LOCATION="northeurope"
RESOURCE_GROUP="rg-aso-lab-shola"
CLUSTER_NAME="aks-aso-lab-shola"
NODE_COUNT=1
NODE_SIZE="Standard_B2s"  # Cost-optimized for lab

echo "🚀 Creating ASO Lab Infrastructure in Azure..."

# Set subscription context
echo "📌 Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

# Create resource group
echo "📦 Creating resource group: $RESOURCE_GROUP..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --tags "purpose=aso-lab" "owner=shola"

# Create AKS cluster
echo "🔧 Creating AKS cluster: $CLUSTER_NAME..."
az aks create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --location "$LOCATION" \
  --node-count "$NODE_COUNT" \
  --node-vm-size "$NODE_SIZE" \
  --enable-managed-identity \
  --generate-ssh-keys \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --tags "purpose=aso-lab" "owner=shola"

# Get AKS credentials
echo "🔑 Getting AKS credentials..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

# Verify cluster access
echo "✅ Verifying cluster access..."
kubectl get nodes
kubectl cluster-info

echo ""
echo "✨ AKS Cluster created successfully!"
echo "   Resource Group: $RESOURCE_GROUP"
echo "   Cluster Name: $CLUSTER_NAME"
echo "   Location: $LOCATION"
echo ""
echo "Next steps:"
echo "  1. Run: ./01-install-aso.sh"
echo "  2. Run: ./02-install-kro.sh"
echo "  3. Run: ./03-validate-setup.sh"
