# Example 02: Storage Account

## Overview
This example shows how to create an Azure Storage Account using ASO, including how to access connection strings and keys.

## What You'll Learn
- Creating storage accounts with ASO
- Understanding storage account SKUs and kinds
- Retrieving storage account keys as Kubernetes secrets
- Managing storage account properties

## Prerequisites
- ASO installed with storage CRDs
- Resource group created (from Example 01)

## Files
- `storageaccount.yaml`: Basic storage account
- `storageaccount-with-secret.yaml`: Storage account with automatic secret creation
- `storageaccount-advanced.yaml`: Storage account with advanced features

## Apply the Resources

```bash
# Create the storage account
kubectl apply -f storageaccount.yaml

# Check status
kubectl get storageaccounts
kubectl describe storageaccount asolabstorage

# Wait for provisioning (can take 2-3 minutes)
kubectl wait --for=condition=Ready --timeout=300s storageaccount/asolabstorage
```

## Accessing Storage Account Keys

The example with secrets demonstrates how to automatically export storage account keys:

```bash
# Apply storage account with secret export
kubectl apply -f storageaccount-with-secret.yaml

# Once ready, check the secret
kubectl get secret storage-keys -o yaml

# Extract connection string
kubectl get secret storage-keys -o jsonpath='{.data.connectionString}' | base64 -d
```

## Verify in Azure

```bash
# Show storage account details
az storage account show -n asolabstorage -g aso-lab-rg

# List storage account keys
az storage account keys list -n asolabstorage -g aso-lab-rg
```

## Understanding Storage Account Configuration

### SKU (Stock Keeping Unit)
- `Standard_LRS`: Locally redundant storage (lowest cost)
- `Standard_GRS`: Geo-redundant storage
- `Standard_ZRS`: Zone-redundant storage
- `Premium_LRS`: Premium performance with SSD

### Kind
- `StorageV2`: General-purpose v2 (recommended)
- `BlobStorage`: Blob-only storage
- `BlockBlobStorage`: Premium block blobs
- `FileStorage`: Premium files

### Access Tier
- `Hot`: Frequently accessed data
- `Cool`: Infrequently accessed data (lower storage cost)

## Key Concepts

### Owner References
Storage accounts need to belong to a resource group:

```yaml
spec:
  owner:
    name: aso-lab-rg  # References the ResourceGroup
```

### Operator Secrets
ASO can automatically export secrets for connection strings and keys:

```yaml
operatorSpec:
  secrets:
    key1:
      name: storage-keys
      key: key1
    connectionString:
      name: storage-keys  
      key: connectionString
```

## Using Storage in Applications

Once you have the secret, reference it in your pods:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-using-storage
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: AZURE_STORAGE_CONNECTION_STRING
      valueFrom:
        secretKeyRef:
          name: storage-keys
          key: connectionString
```

## Clean Up

```bash
# Delete storage account
kubectl delete -f storageaccount.yaml

# Verify deletion
az storage account show -n asolabstorage -g aso-lab-rg
```

## Common Issues

### Name Already Taken
Storage account names must be globally unique across Azure. If you get a conflict:
- Change the name in the manifest
- Use a naming convention like: `<prefix><random>storage`

### Provisioning Timeout
Storage accounts can take 2-3 minutes to provision. Be patient or increase the wait timeout.

## Next Steps
- Proceed to Example 03 for Virtual Networks
- Try creating blob containers within the storage account
- Experiment with different SKUs and access tiers
