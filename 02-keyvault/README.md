# Phase 3: Azure Key Vault

Deploy an Azure Key Vault using ASO.

## Prerequisites

- Resource Group `rg-aso-workloads-shola` must exist
- Replace `TENANT_ID_PLACEHOLDER` with your Azure tenant ID

## Get your Tenant ID

```bash
az account show --query tenantId -o tsv
```

## Update the manifest

```bash
TENANT_ID=$(az account show --query tenantId -o tsv)
sed -i.bak "s/TENANT_ID_PLACEHOLDER/$TENANT_ID/g" keyvault.yaml
```

## Deploy

```bash
kubectl apply -f keyvault.yaml
```

## Monitor

```bash
# Watch the vault creation
kubectl get vault -w

# Describe the vault
kubectl describe vault kv-aso-lab-shola

# Check in Azure
az keyvault show --name kv-aso-lab-shola --resource-group rg-aso-workloads-shola
```

## Key Concepts

1. **Owner Reference**: `owner.name: rg-aso-workloads-shola` creates a dependency
2. **RBAC Authorization**: Using Azure RBAC instead of access policies
3. **Soft Delete**: Enabled with 7-day retention for lab safety
4. **API Version**: `v1api20230701` maps to Azure API version 2023-07-01
