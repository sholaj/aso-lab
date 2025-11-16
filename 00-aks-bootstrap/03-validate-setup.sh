#!/bin/bash
set -e

# ASO Lab - Phase 1: Validate ASO and KRO Installation
# This script validates that ASO CRDs are installed and ready

echo "🔍 Validating ASO and KRO setup..."
echo ""

# Check ASO pods
echo "📊 ASO Pods Status:"
kubectl get pods -n azureserviceoperator-system
echo ""

# Check KRO pods (if namespace exists)
if kubectl get namespace kro-system &>/dev/null; then
  echo "📊 KRO Pods Status:"
  kubectl get pods -n kro-system
  echo ""
fi

# List ASO CRDs
echo "📋 ASO CRDs Installed:"
kubectl get crds | grep azure.com | head -20
echo ""

# Check specific important CRDs
echo "🔍 Checking critical ASO CRDs..."
CRITICAL_CRDS=(
  "resourcegroups.resources.azure.com"
  "vaults.keyvault.azure.com"
  "storageaccounts.storage.azure.com"
  "workspaces.operationalinsights.azure.com"
  "registries.containerregistry.azure.com"
  "managedclusters.containerservice.azure.com"
)

for crd in "${CRITICAL_CRDS[@]}"; do
  if kubectl get crd "$crd" &>/dev/null; then
    echo "  ✅ $crd"
  else
    echo "  ❌ $crd (not found)"
  fi
done

echo ""
echo "🧪 Testing kubectl explain for ASO resources..."
echo "   Example: ResourceGroup"
kubectl explain resourcegroup.spec --recursive | head -20

echo ""
echo "✨ Validation complete!"
echo ""
echo "🎯 You're now ready to deploy your first ASO resource!"
echo "   Next: cd ../01-resource-group && kubectl apply -f resourcegroup.yaml"
