# Phase 1: Resource Group

This directory contains your first ASO resource: a Resource Group.

## What is this?

A Resource Group in Azure is a logical container for Azure resources. Using ASO, we can manage it declaratively through Kubernetes.

## Deployment

```bash
# Deploy the resource group
kubectl apply -f resourcegroup.yaml

# Watch the reconciliation
kubectl get resourcegroup -w

# Check the status
kubectl describe resourcegroup rg-aso-workloads-shola

# View events
kubectl get events --sort-by='.lastTimestamp' | grep rg-aso-workloads-shola
```

## Key Concepts

1. **CRD (Custom Resource Definition)**: `resources.azure.com/v1api20200601` is an ASO-installed CRD
2. **Reconciliation**: ASO controller watches this resource and creates it in Azure
3. **API Version**: Maps to Azure REST API version (2020-06-01)
4. **Ownership**: Kubernetes now owns this Azure resource

## Verify in Azure

```bash
# List resource groups
az group list --query "[?tags.owner=='shola']" -o table

# Show the specific resource group
az group show --name rg-aso-workloads-shola
```

## Lifecycle Testing

```bash
# Delete from Kubernetes (will delete from Azure too!)
kubectl delete -f resourcegroup.yaml

# Recreate
kubectl apply -f resourcegroup.yaml
```

## Next Steps

Once the Resource Group is successfully created, move to:
- `02-keyvault/` - Deploy an Azure Key Vault
