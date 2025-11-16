# Example 05: Azure Key Vault

## Overview
This example demonstrates creating and managing Azure Key Vault using ASO, including secret management and access policies.

## What You'll Learn
- Creating Key Vaults with ASO
- Managing secrets in Key Vault
- Configuring access policies
- Integrating with AKS workloads

## Prerequisites
- ASO installed with keyvault CRDs
- Resource group created
- Managed identity (from Example 04)

## Files
- `keyvault.yaml`: Basic Key Vault
- `keyvault-secret.yaml`: Secret stored in Key Vault
- `keyvault-with-policies.yaml`: Key Vault with access policies

## Apply the Resources

```bash
# Create Key Vault
kubectl apply -f keyvault.yaml

# Wait for provisioning (1-2 minutes)
kubectl wait --for=condition=Ready --timeout=300s vault/aso-lab-kv

# Check status
kubectl get vaults
kubectl describe vault aso-lab-kv
```

## Adding Secrets

```bash
# Create a secret
kubectl apply -f keyvault-secret.yaml

# Check secret status
kubectl get keyvaults/secrets
kubectl describe keyvaults/secret db-connection-string
```

## Verify in Azure

```bash
# Show Key Vault details
az keyvault show -n aso-lab-kv -g aso-lab-rg

# List secrets
az keyvault secret list --vault-name aso-lab-kv -o table

# Show secret value (if you have permission)
az keyvault secret show --vault-name aso-lab-kv --name db-connection-string
```

## Understanding Key Vault Configuration

### Naming Requirements
- Key Vault names must be globally unique
- 3-24 characters
- Alphanumeric and hyphens only
- Must start with a letter

### SKU Options
- **Standard**: Software-protected keys
- **Premium**: Hardware-protected keys (HSM-backed)

### Access Models
- **Access Policies**: Traditional, role-based access
- **RBAC**: Azure RBAC integration (recommended)

## Access Policies

Grant access to identities:

```yaml
spec:
  properties:
    accessPolicies:
    - objectId: "<user-or-service-principal-object-id>"
      permissions:
        secrets:
        - get
        - list
        - set
      tenantId: "<tenant-id>"
```

## Using Secrets in AKS

### Option 1: CSI Secret Store Driver

Install the driver:
```bash
# Enable on AKS cluster
az aks enable-addons \
  --addons azure-keyvault-secrets-provider \
  --name aso-lab-aks \
  --resource-group aso-lab-rg
```

Create SecretProviderClass:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    tenantId: "<tenant-id>"
    keyvaultName: "aso-lab-kv"
    objects: |
      array:
        - |
          objectName: db-connection-string
          objectType: secret
          objectVersion: ""
```

Use in Pod:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: secrets
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secrets
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "azure-keyvault"
```

### Option 2: Azure SDK

Use Azure SDK in your application:
```python
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(
    vault_url="https://aso-lab-kv.vault.azure.net",
    credential=credential
)

secret = client.get_secret("db-connection-string")
print(secret.value)
```

## Managing Secrets with ASO

### Create Secret
```yaml
apiVersion: keyvault.azure.com/v1api20210401preview
kind: VaultsSecret
metadata:
  name: db-connection-string
spec:
  owner:
    name: aso-lab-kv
  properties:
    value: "Server=myserver;Database=mydb;User=admin;Password=P@ssw0rd!"
```

### Update Secret
```bash
# Edit the manifest
kubectl edit keyvaults/secret db-connection-string

# Or apply updated file
kubectl apply -f keyvault-secret.yaml
```

### Export to Kubernetes Secret

ASO can export Key Vault secrets to Kubernetes secrets:

```yaml
apiVersion: keyvault.azure.com/v1api20210401preview
kind: VaultsSecret
metadata:
  name: db-connection-string
spec:
  owner:
    name: aso-lab-kv
  properties:
    value: "connection-string-value"
  operatorSpec:
    secrets:
      value:
        name: app-secrets
        key: db-connection-string
```

Then use in pods:
```yaml
env:
- name: DB_CONNECTION_STRING
  valueFrom:
    secretKeyRef:
      name: app-secrets
      key: db-connection-string
```

## Best Practices

### Security
1. Use managed identity for access
2. Enable soft delete and purge protection
3. Regularly rotate secrets
4. Use separate Key Vaults for different environments
5. Enable audit logging

### Secret Management
1. Never commit secrets to Git
2. Use descriptive secret names
3. Version your secrets
4. Document secret purposes
5. Set expiration dates when appropriate

### Access Control
1. Follow least privilege principle
2. Use RBAC over access policies
3. Separate Key Vaults by sensitivity level
4. Regular access reviews
5. Enable MFA for administrative access

## Advanced Features

### Network Restrictions
```yaml
spec:
  properties:
    networkAcls:
      defaultAction: Deny
      bypass: AzureServices
      ipRules:
      - value: "1.2.3.4/32"
      virtualNetworkRules:
      - id: "/subscriptions/.../subnets/aks-subnet"
```

### Private Endpoint
```yaml
spec:
  properties:
    publicNetworkAccess: Disabled
    privateEndpointConnections:
    - ...
```

### Soft Delete & Purge Protection
```yaml
spec:
  properties:
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
```

## Clean Up

```bash
# Delete secrets first
kubectl delete -f keyvault-secret.yaml

# Delete Key Vault
kubectl delete -f keyvault.yaml

# Verify deletion (may be in soft-delete state)
az keyvault list-deleted -o table
```

## Troubleshooting

### Access Denied
- Verify access policy or RBAC permissions
- Check managed identity assignment
- Ensure network access is allowed

### Secret Not Found
- Verify secret name spelling
- Check secret is provisioned
- Ensure Key Vault is ready

### Cannot Delete Key Vault
- Soft delete may be enabled
- Purge protection may prevent deletion
- Check for active private endpoints

## Next Steps
- Proceed to Example 06 for composite patterns
- Integrate Key Vault with your applications
- Set up automatic secret rotation
- Implement certificate management
- Configure diagnostic logging
