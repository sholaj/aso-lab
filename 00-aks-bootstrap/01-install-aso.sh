#!/bin/bash
set -e

# ASO Lab - Phase 1: Install Azure Service Operator v2
# This script installs ASO v2 using Helm and configures Azure identity

SUBSCRIPTION_ID="1aa6797c-bba1-4073-a0f8-e49d0e79fd4f"
RESOURCE_GROUP="rg-aso-lab-shola"
CLUSTER_NAME="aks-aso-lab-shola"
LOCATION="northeurope"

echo "🔧 Installing Azure Service Operator v2..."

# Get current Azure tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "📌 Azure Tenant ID: $TENANT_ID"

# Create service principal for ASO
echo "🔑 Creating service principal for ASO..."
SP_NAME="sp-aso-lab-shola"

# Check if SP already exists, if not create it
SP_JSON=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --query "{clientId:appId, clientSecret:password}" \
  -o json 2>/dev/null || echo "{}")

if [ "$SP_JSON" == "{}" ]; then
  echo "⚠️  Service principal may already exist. Retrieving existing credentials..."
  CLIENT_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv)
  echo "Using existing service principal: $CLIENT_ID"
  echo "⚠️  Note: You may need to create a new client secret if the original has expired."
else
  CLIENT_ID=$(echo "$SP_JSON" | jq -r '.clientId')
  CLIENT_SECRET=$(echo "$SP_JSON" | jq -r '.clientSecret')

  # Store credentials in a secret file (not for production!)
  echo "💾 Storing SP credentials..."
  cat > /tmp/aso-credentials.env <<EOF
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_CLIENT_ID=$CLIENT_ID
AZURE_CLIENT_SECRET=$CLIENT_SECRET
EOF

  echo "✅ Service Principal created: $CLIENT_ID"
  echo "   Credentials saved to: /tmp/aso-credentials.env"
fi

# Install cert-manager (required by ASO)
echo "📦 Installing cert-manager (required by ASO)..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

echo "⏳ Waiting for cert-manager to be ready..."
sleep 15
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s || echo "⚠️  cert-manager pods not ready yet, continuing..."

# Add ASO Helm repository
echo "📦 Adding ASO Helm repository..."
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo update

# Create namespace for ASO
echo "📂 Creating azureserviceoperator-system namespace..."
kubectl create namespace azureserviceoperator-system --dry-run=client -o yaml | kubectl apply -f -

# Create secret for ASO credentials
echo "🔐 Creating Kubernetes secret for ASO credentials..."
if [ -f /tmp/aso-credentials.env ]; then
  source /tmp/aso-credentials.env
  kubectl create secret generic aso-controller-settings \
    --namespace azureserviceoperator-system \
    --from-literal=AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID" \
    --from-literal=AZURE_TENANT_ID="$AZURE_TENANT_ID" \
    --from-literal=AZURE_CLIENT_ID="$AZURE_CLIENT_ID" \
    --from-literal=AZURE_CLIENT_SECRET="$AZURE_CLIENT_SECRET" \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "⚠️  Please create the secret manually:"
  echo "   kubectl create secret generic aso-controller-settings \\"
  echo "     --namespace azureserviceoperator-system \\"
  echo "     --from-literal=AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID \\"
  echo "     --from-literal=AZURE_TENANT_ID=$TENANT_ID \\"
  echo "     --from-literal=AZURE_CLIENT_ID=<your-client-id> \\"
  echo "     --from-literal=AZURE_CLIENT_SECRET=<your-client-secret>"
  exit 1
fi

# Install ASO using Helm
echo "🚀 Installing ASO v2 via Helm..."
helm upgrade --install aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set azureSubscriptionID="$SUBSCRIPTION_ID" \
  --set azureTenantID="$TENANT_ID" \
  --set azureClientID="$CLIENT_ID" \
  --set crdPattern='resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;storage.azure.com/*;operationalinsights.azure.com/*;containerregistry.azure.com/*' \
  --wait

# Wait for ASO pods to be ready
echo "⏳ Waiting for ASO pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n azureserviceoperator-system --timeout=300s

echo ""
echo "✨ ASO v2 installed successfully!"
echo ""
echo "Next step: Run ./02-install-kro.sh"
