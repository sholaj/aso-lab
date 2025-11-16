# Azure Storage Account Examples

This directory contains examples for deploying Azure Storage Accounts using ASO v2.

## Examples

1. **basic-storage-account.yaml** - Simple storage account with secure defaults
2. **premium-storage.yaml** - Premium storage with advanced features
3. **storage-with-containers.yaml** - Storage account with blob containers
4. **storage-with-lifecycle.yaml** - Storage with lifecycle management policies

## Quick Start

```bash
# Deploy basic storage account
kubectl apply -f basic-storage-account.yaml

# Check status
kubectl get storageaccount mysa001 -n azure-storage -w

# View in Azure
az storage account show --name mysa001 --resource-group storage-demo-rg
```

## Storage Account Naming Rules

- 3-24 characters
- Lowercase letters and numbers only
- Must be globally unique across Azure

## Common Use Cases

### Development/Testing
- SKU: Standard_LRS
- Access Tier: Hot
- Public access: Disabled

### Production
- SKU: Standard_GRS or Standard_RAGRS
- Access Tier: Hot/Cool based on usage
- Encryption: Customer-managed keys
- Network rules: Restricted access

### Archive/Backup
- SKU: Standard_LRS
- Access Tier: Cool or Archive
- Lifecycle policies: Auto-tier old data

## Security Best Practices

✅ **DO:**
- Use HTTPS only (supportsHttpsTrafficOnly: true)
- Minimum TLS 1.2 (minimumTlsVersion: TLS1_2)
- Disable public blob access (allowBlobPublicAccess: false)
- Enable soft delete for blobs and containers
- Use managed identities for access

❌ **DON'T:**
- Allow anonymous public access
- Use account keys in code (use managed identity)
- Use TLS 1.0 or 1.1
- Skip encryption

## Troubleshooting

### Name conflicts
```bash
# Check if name is available
az storage account check-name --name mysa001
```

### Permission issues
```bash
# Verify service principal has Contributor role
az role assignment list --assignee <CLIENT_ID> --scope /subscriptions/<SUBSCRIPTION_ID>
```

### Resource status
```bash
# Check ASO resource status
kubectl describe storageaccount mysa001 -n azure-storage
```

## References

- [Azure Storage Documentation](https://docs.microsoft.com/azure/storage/)
- [ASO Storage Examples](https://azure.github.io/azure-service-operator/)
