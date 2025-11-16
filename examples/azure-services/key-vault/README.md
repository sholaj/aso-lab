# Azure Key Vault Examples

This directory contains examples for deploying Azure Key Vault using ASO v2.

## Examples

1. **basic-keyvault.yaml** - Simple Key Vault with RBAC
2. **keyvault-with-secrets.yaml** - Key Vault with secrets managed by ASO
3. **keyvault-with-access-policies.yaml** - Key Vault using access policies

## Quick Start

```bash
# Deploy basic Key Vault
kubectl apply -f basic-keyvault.yaml

# Check status
kubectl get vault mykeyvault001 -n azure-keyvault -w

# View in Azure
az keyvault show --name mykeyvault001 --resource-group keyvault-demo-rg
```

## Key Vault Naming Rules

- 3-24 characters
- Alphanumeric and hyphens only
- Start with a letter
- Must be globally unique across Azure

## Access Control Models

### RBAC (Recommended)
- Modern, Azure-native access control
- Use Azure RBAC roles (Key Vault Administrator, Secrets Officer, etc.)
- Better integration with Azure AD

### Access Policies (Legacy)
- Traditional Key Vault access model
- Object ID based permissions
- Fine-grained per-identity permissions

## Common Use Cases

### Application Secrets
- Store connection strings, API keys
- Use with Kubernetes External Secrets Operator
- Integrate with workload identity

### Certificate Management
- SSL/TLS certificates
- Code signing certificates
- Automated rotation

### Encryption Keys
- Customer-managed keys for Azure services
- Application-level encryption
- Key rotation policies

## Security Best Practices

✅ **DO:**
- Enable soft delete and purge protection
- Use RBAC for access control
- Enable audit logging to Log Analytics
- Use private endpoints for network isolation
- Implement key rotation policies

❌ **DON'T:**
- Disable purge protection in production
- Use access policies if RBAC is available
- Store keys/secrets in code or config files
- Allow public access without restrictions

## Integration with Kubernetes

### Using Secrets Store CSI Driver
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault
spec:
  provider: azure
  parameters:
    keyvaultName: "mykeyvault001"
    objects: |
      array:
        - objectName: "db-password"
          objectType: "secret"
```

### Using External Secrets Operator
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
spec:
  provider:
    azurekv:
      vaultUrl: "https://mykeyvault001.vault.azure.net"
      authType: WorkloadIdentity
```

## Troubleshooting

### Name conflicts
```bash
# Check if name is available (Key Vault names are global)
az keyvault list --query "[?name=='mykeyvault001']"
```

### Access denied
```bash
# Check RBAC assignments
az role assignment list --scope /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.KeyVault/vaults/<VAULT_NAME>

# Add yourself as admin
az role assignment create --role "Key Vault Administrator" --assignee <YOUR_OBJECT_ID> --scope <VAULT_RESOURCE_ID>
```

### Soft-deleted vault conflicts
```bash
# List soft-deleted vaults
az keyvault list-deleted

# Purge a soft-deleted vault
az keyvault purge --name mykeyvault001
```

## References

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Key Vault Best Practices](https://docs.microsoft.com/azure/key-vault/general/best-practices)
- [RBAC Guide](https://docs.microsoft.com/azure/key-vault/general/rbac-guide)
