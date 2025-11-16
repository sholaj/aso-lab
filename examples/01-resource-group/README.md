# Example 01: Resource Group

## Overview
This example demonstrates how to create an Azure Resource Group using ASO. A Resource Group is a logical container for Azure resources.

## What You'll Learn
- How to create a basic ASO resource
- Understanding ASO resource specifications
- Checking resource status in Kubernetes
- Verifying resources in Azure

## Prerequisites
- ASO installed in your cluster
- Azure credentials configured

## Files
- `resourcegroup.yaml`: Basic resource group
- `resourcegroup-with-tags.yaml`: Resource group with tags

## Apply the Resource

```bash
# Create the resource group
kubectl apply -f resourcegroup.yaml

# Check status
kubectl get resourcegroups
kubectl describe resourcegroup aso-lab-rg

# Wait for provisioning (can take 1-2 minutes)
kubectl wait --for=condition=Ready --timeout=300s resourcegroup/aso-lab-rg
```

## Verify in Azure

```bash
# Using Azure CLI
az group show -n aso-lab-rg

# List all resources in the group
az resource list -g aso-lab-rg
```

## Understanding the Manifest

```yaml
apiVersion: resources.azure.com/v1api20200601  # API version
kind: ResourceGroup                             # Resource type
metadata:
  name: aso-lab-rg                             # Kubernetes object name
  namespace: default                            # Kubernetes namespace
spec:
  location: eastus                              # Azure region
```

## Key Concepts

### API Version
- ASO uses versioned APIs matching Azure API versions
- Format: `resources.azure.com/v1api{YYYYMMDD}`
- Different resources may have different API versions

### Resource Naming
- `metadata.name`: Name in Kubernetes (can differ from Azure name)
- `spec.azureName`: Actual name in Azure (optional, defaults to metadata.name)

### Location
- Azure region where the resource will be created
- Common values: `eastus`, `westus`, `westeurope`, `southeastasia`

## Clean Up

```bash
# Delete the resource (will also delete in Azure)
kubectl delete -f resourcegroup.yaml

# Verify deletion
az group show -n aso-lab-rg
```

## Next Steps
- Proceed to Example 02 to learn about Storage Accounts
- Try creating resource groups in different regions
- Experiment with tags for resource organization
