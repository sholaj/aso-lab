# Phase 3: Azure Storage Account

Deploy an Azure Storage Account using ASO.

## Important Notes

- Storage account names must be globally unique
- Only lowercase letters and numbers allowed
- No hyphens or special characters
- If `stasoshola001` is taken, modify the name in the YAML

## Deploy

```bash
kubectl apply -f storageaccount.yaml
```

## Monitor

```bash
# Watch the storage account creation
kubectl get storageaccount -w

# Describe the storage account
kubectl describe storageaccount stasoshola001

# Get storage account details from Azure
az storage account show --name stasoshola001 --resource-group rg-aso-workloads-shola
```

## Key Concepts

1. **Naming Constraints**: Storage accounts have strict naming rules
2. **SKU**: Standard_LRS is cheapest for lab (Locally Redundant Storage)
3. **Security**: HTTPS-only, TLS 1.2 minimum, public blob access disabled
4. **Encryption**: Enabled for blob and file services

## Optional: Create a Blob Container

After the storage account is created, you can add blob containers using ASO:

```yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccountsBlobService
metadata:
  name: stasoshola001-blobservice
  namespace: default
spec:
  owner:
    name: stasoshola001
---
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccountsBlobServicesContainer
metadata:
  name: stasoshola001-data
  namespace: default
spec:
  owner:
    name: stasoshola001-blobservice
  properties:
    publicAccess: None
```
