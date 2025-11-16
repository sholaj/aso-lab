# Quick Start Guide

Get started with ASO and KRO in 15 minutes!

## Prerequisites Check

Before you begin, verify you have:

```bash
# Check kubectl
kubectl version --client

# Check Azure CLI
az --version

# Check Helm (optional)
helm version

# Login to Azure
az login

# Set your subscription
az account set --subscription "<your-subscription-id>"
az account show
```

## Step 1: Install ASO (5 minutes)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

# Create service principal
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SP_OUTPUT=$(az ad sp create-for-rbac -n "aso-quickstart-sp" --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID)

# Extract credentials
CLIENT_ID=$(echo $SP_OUTPUT | jq -r .appId)
CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r .password)
TENANT_ID=$(echo $SP_OUTPUT | jq -r .tenant)

# Create namespace
kubectl create namespace azureserviceoperator-system

# Create secret
kubectl create secret generic aso-controller-settings \
  -n azureserviceoperator-system \
  --from-literal=AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID" \
  --from-literal=AZURE_TENANT_ID="$TENANT_ID" \
  --from-literal=AZURE_CLIENT_ID="$CLIENT_ID" \
  --from-literal=AZURE_CLIENT_SECRET="$CLIENT_SECRET"

# Add Helm repo
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo update

# Install ASO
helm install aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set crdPattern='resources.azure.com/*;storage.azure.com/*;network.azure.com/*;keyvault.azure.com/*'

# Verify installation
kubectl get pods -n azureserviceoperator-system
```

## Step 2: Create Your First Resource (5 minutes)

Create a Resource Group:

```bash
# Clone this repo (if not already done)
cd /path/to/aso-lab

# Apply resource group
kubectl apply -f examples/01-resource-group/resourcegroup.yaml

# Watch it get created
kubectl get resourcegroups -w

# Verify in Azure
az group show -n aso-lab-rg
```

Create a Storage Account:

```bash
# Apply storage account
kubectl apply -f examples/02-storage-account/storageaccount.yaml

# Check status
kubectl get storageaccounts
kubectl describe storageaccount asolabstorage

# Verify in Azure
az storage account show -n asolabstorage -g aso-lab-rg
```

## Step 3: Try a Composite Pattern (5 minutes)

Deploy a complete three-tier application stack:

```bash
# Apply the complete stack
kubectl apply -f examples/06-composite-patterns/complete-stacks/three-tier-app.yaml

# Monitor all resources
kubectl get resourcegroups,virtualnetworks,storageaccounts,vaults,networksecuritygroups -l stack=three-tier-app

# Check individual resource status
kubectl describe resourcegroup three-tier-app-rg
kubectl describe virtualnetwork three-tier-vnet

# Wait for all resources to be ready (takes 3-5 minutes)
kubectl wait --for=condition=Ready --timeout=600s -l stack=three-tier-app
```

## What You've Accomplished

✅ Installed Azure Service Operator
✅ Created Azure resources using Kubernetes manifests
✅ Deployed a complete infrastructure stack
✅ Learned the basics of KRO composite patterns

## Next Steps

1. **Explore More Examples**
   ```bash
   cd examples/03-virtual-network
   cat README.md
   ```

2. **Try Kustomize**
   ```bash
   kubectl apply -k examples/06-composite-patterns/kustomize/overlays/dev/
   ```

3. **Try Helm**
   ```bash
   cd examples/06-composite-patterns/helm/aso-app-stack
   # Update values.yaml with your tenant ID
   helm install myapp . -f values-dev.yaml
   ```

4. **Build Your Own Pattern**
   - Identify infrastructure you deploy often
   - Create a composite manifest
   - Add it to your GitOps repository

## Troubleshooting

### ASO Pods Not Starting
```bash
# Check logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager

# Verify secret
kubectl get secret aso-controller-settings -n azureserviceoperator-system
```

### Resource Not Creating
```bash
# Check resource status
kubectl describe <resource-type> <resource-name>

# Look for error messages in Events section
kubectl get events --sort-by='.lastTimestamp'
```

### Permission Errors
```bash
# Verify service principal has correct permissions
az role assignment list --assignee $CLIENT_ID --all

# If needed, grant contributor role
az role assignment create \
  --assignee $CLIENT_ID \
  --role Contributor \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

## Clean Up

```bash
# Delete the three-tier stack
kubectl delete -f examples/06-composite-patterns/complete-stacks/three-tier-app.yaml

# Delete storage account
kubectl delete -f examples/02-storage-account/storageaccount.yaml

# Delete resource group
kubectl delete -f examples/01-resource-group/resourcegroup.yaml

# Uninstall ASO (optional)
helm uninstall aso2 -n azureserviceoperator-system

# Delete service principal (optional)
az ad sp delete --id $CLIENT_ID
```

## Learning Resources

- 📖 Read the full [README.md](../README.md)
- 🎯 Follow the [examples](../examples/) in order
- 🔧 Check [Best Practices](../README.md#best-practices)
- 🐛 Review [Troubleshooting Guide](../README.md#troubleshooting)

## Community

- [ASO GitHub](https://github.com/Azure/azure-service-operator)
- [ASO Documentation](https://azure.github.io/azure-service-operator/)
- [File Issues](https://github.com/Azure/azure-service-operator/issues)

Happy learning! 🚀
