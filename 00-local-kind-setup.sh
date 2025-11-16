#!/bin/bash
set -e

# Local Kind Cluster Setup for ASO Testing
# This script creates a kind cluster and installs ASO + KRO for local testing

echo "🚀 Setting up local kind cluster for ASO testing..."

# Configuration
CLUSTER_NAME="aso-lab-local"
SUBSCRIPTION_ID="1aa6797c-bba1-4073-a0f8-e49d0e79fd4f"
LOCATION="northeurope"

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "✅ Kind cluster '${CLUSTER_NAME}' already exists"
else
    # Create kind cluster
    echo "📦 Creating kind cluster: ${CLUSTER_NAME}..."
    cat <<EOF | kind create cluster --name ${CLUSTER_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
EOF
fi

# Get current context
echo "🔍 Setting kubectl context..."
kubectl config use-context kind-${CLUSTER_NAME}

# Verify cluster
echo "✅ Verifying cluster access..."
kubectl get nodes
kubectl cluster-info

# Get Azure tenant ID
echo "📌 Getting Azure tenant ID..."
TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || echo "")
if [ -z "$TENANT_ID" ]; then
    echo "⚠️  Not logged in to Azure. Please run: az login"
    exit 1
fi

echo "   Tenant ID: $TENANT_ID"
echo "   Subscription ID: $SUBSCRIPTION_ID"

# Create service principal for ASO (if it doesn't exist)
echo "🔑 Setting up Azure Service Principal for ASO..."
SP_NAME="sp-aso-lab-local"

# Check if SP exists
SP_APP_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -z "$SP_APP_ID" ]; then
    echo "   Creating new service principal..."
    SP_JSON=$(az ad sp create-for-rbac \
      --name "$SP_NAME" \
      --role Contributor \
      --scopes "/subscriptions/$SUBSCRIPTION_ID" \
      --query "{clientId:appId, clientSecret:password}" \
      -o json)

    CLIENT_ID=$(echo "$SP_JSON" | jq -r '.clientId')
    CLIENT_SECRET=$(echo "$SP_JSON" | jq -r '.clientSecret')

    echo "   ✅ Service Principal created: $CLIENT_ID"
else
    echo "   ⚠️  Service Principal already exists: $SP_APP_ID"
    echo "   Using existing SP. If credentials are expired, delete and rerun:"
    echo "   az ad sp delete --id $SP_APP_ID"
    CLIENT_ID="$SP_APP_ID"
    CLIENT_SECRET="YOUR_EXISTING_SECRET"  # You'll need to provide this
fi

# Store credentials temporarily
cat > /tmp/aso-credentials-local.env <<EOF
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_CLIENT_ID=$CLIENT_ID
AZURE_CLIENT_SECRET=$CLIENT_SECRET
EOF

echo "💾 Credentials saved to: /tmp/aso-credentials-local.env"

# Install cert-manager (required by ASO)
echo "📦 Installing cert-manager (required by ASO)..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

echo "⏳ Waiting for cert-manager to be ready..."
sleep 15
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s || echo "⚠️  cert-manager pods not ready yet, continuing..."

# Install ASO using Helm
echo "📦 Adding ASO Helm repository..."
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts || true
helm repo update

# Create namespace
echo "📂 Creating azureserviceoperator-system namespace..."
kubectl create namespace azureserviceoperator-system --dry-run=client -o yaml | kubectl apply -f -

# Create secret
echo "🔐 Creating Kubernetes secret for ASO credentials..."
kubectl create secret generic aso-controller-settings \
  --namespace azureserviceoperator-system \
  --from-literal=AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID" \
  --from-literal=AZURE_TENANT_ID="$TENANT_ID" \
  --from-literal=AZURE_CLIENT_ID="$CLIENT_ID" \
  --from-literal=AZURE_CLIENT_SECRET="$CLIENT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

# Install ASO
echo "🚀 Installing ASO v2..."
helm upgrade --install aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set azureSubscriptionID="$SUBSCRIPTION_ID" \
  --set azureTenantID="$TENANT_ID" \
  --set azureClientID="$CLIENT_ID" \
  --set crdPattern='resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;storage.azure.com/*;operationalinsights.azure.com/*;containerregistry.azure.com/*' \
  --wait

# Wait for ASO pods
echo "⏳ Waiting for ASO pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n azureserviceoperator-system --timeout=300s || true

# Check ASO status
echo "📊 ASO Pods Status:"
kubectl get pods -n azureserviceoperator-system

# Install KRO
echo "🔧 Installing KRO..."
KRO_VERSION=$(curl -sL https://api.github.com/repos/kubernetes-sigs/kro/releases/latest | jq -r '.tag_name | ltrimstr("v")')
echo "   KRO Version: $KRO_VERSION"
helm install kro oci://registry.k8s.io/kro/charts/kro \
  --namespace kro \
  --create-namespace \
  --version=${KRO_VERSION}

# Wait for KRO
echo "⏳ Waiting for KRO pods to be ready..."
sleep 15
kubectl wait --for=condition=Ready pods --all -n kro --timeout=300s || echo "⚠️  KRO pods not ready yet"

# List CRDs
echo ""
echo "📋 ASO CRDs Installed:"
kubectl get crds | grep azure.com | head -10

echo ""
echo "✨ Local kind cluster setup complete!"
echo ""
echo "🎯 Next steps:"
echo "   1. Test deploying a resource group:"
echo "      kubectl apply -f 01-resource-group/resourcegroup.yaml"
echo ""
echo "   2. Watch the reconciliation:"
echo "      kubectl get resourcegroup -w"
echo ""
echo "   3. Verify in Azure:"
echo "      az group show --name rg-aso-workloads-shola"
echo ""
echo "🧹 To delete the cluster when done:"
echo "   kind delete cluster --name ${CLUSTER_NAME}"
