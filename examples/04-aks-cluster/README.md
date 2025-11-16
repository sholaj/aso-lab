# Example 04: Azure Kubernetes Service (AKS)

## Overview
This example shows how to create an Azure Kubernetes Service cluster using ASO, demonstrating infrastructure as code for Kubernetes itself.

## What You'll Learn
- Creating AKS clusters with ASO
- Configuring node pools
- Setting up managed identity
- Understanding AKS network configuration

## Prerequisites
- ASO installed with containerservice CRDs
- Resource group and VNet created (Examples 01 and 03)
- Managed identity for AKS

## Files
- `managed-identity.yaml`: Identity for AKS cluster
- `aks-cluster-basic.yaml`: Basic AKS cluster
- `aks-cluster-advanced.yaml`: Production-ready AKS configuration

## Important Notes

⚠️ **Cost Warning**: AKS clusters incur costs. Remember to delete when done learning.

⚠️ **Provisioning Time**: AKS clusters take 10-15 minutes to provision.

## Apply the Resources

```bash
# Step 1: Create managed identity first
kubectl apply -f managed-identity.yaml
kubectl wait --for=condition=Ready --timeout=300s managedidentity/aks-identity

# Step 2: Create AKS cluster
kubectl apply -f aks-cluster-basic.yaml

# Monitor creation (takes 10-15 minutes)
kubectl get managedcluster aso-lab-aks -w

# Check detailed status
kubectl describe managedcluster aso-lab-aks
```

## Verify in Azure

```bash
# Show AKS cluster details
az aks show -n aso-lab-aks -g aso-lab-rg

# Get credentials to access the cluster
az aks get-credentials -n aso-lab-aks -g aso-lab-rg --overwrite-existing

# Verify connectivity to the new cluster
kubectl get nodes
```

## Understanding AKS Configuration

### Managed Identity
AKS requires an identity to manage Azure resources:
- Control plane uses this to create load balancers, disks, etc.
- More secure than service principal approach
- Automatically managed by Azure

### Node Pools
- **System pool**: Required, runs system pods
- **User pool**: Optional, for application workloads
- Configure size, count, and VM size per pool

### Network Plugin
- **kubenet**: Basic, Azure-managed routing
- **azure**: Advanced, VNet-integrated pods
- **azure (overlay)**: Overlay networking

### DNS and Service CIDR
Must not overlap with VNet:
- Service CIDR: `10.2.0.0/16`
- DNS Service IP: `10.2.0.10`
- Docker Bridge: `172.17.0.1/16`

## Configuration Options

### VM Sizes
Choose based on workload:
- `Standard_B2s`: Development/testing (2 vCPU, 4 GB)
- `Standard_D4s_v3`: General purpose (4 vCPU, 16 GB)
- `Standard_E8s_v3`: Memory optimized (8 vCPU, 64 GB)
- `Standard_F16s_v2`: Compute optimized (16 vCPU, 32 GB)

### Node Count
- Minimum: 1 (dev), 3 (prod)
- Enable autoscaling for production
- Consider availability zones for HA

### Kubernetes Version
```bash
# List available versions
az aks get-versions -l eastus -o table

# Use in manifest
spec:
  kubernetesVersion: "1.28.0"
```

## Advanced Features

### Auto-scaling
```yaml
spec:
  agentPoolProfiles:
  - name: default
    enableAutoScaling: true
    minCount: 1
    maxCount: 5
```

### Azure CNI with Dynamic IP Allocation
```yaml
spec:
  networkProfile:
    networkPlugin: azure
    networkPluginMode: overlay
```

### Managed Identity for Pods (AAD Pod Identity)
```yaml
spec:
  addonProfiles:
    azureKeyvaultSecretsProvider:
      enabled: true
```

### Azure Monitor Integration
```yaml
spec:
  addonProfiles:
    omsAgent:
      enabled: true
      config:
        logAnalyticsWorkspaceResourceId: /subscriptions/.../workspaces/...
```

## Accessing the Cluster

After creation, get credentials:

```bash
# Get credentials
az aks get-credentials -n aso-lab-aks -g aso-lab-rg

# Switch context
kubectl config use-context aso-lab-aks

# Verify access
kubectl get nodes
kubectl get pods -A
```

## Common Use Cases

### Development Cluster
- Small VM size (Standard_B2s)
- Single node or small count
- Basic networking (kubenet)

### Production Cluster
- Larger VMs (Standard_D4s_v3+)
- Multiple nodes with autoscaling
- Azure CNI networking
- Multiple node pools
- Availability zones

## Integration with Other Examples

### Deploy Application Using Storage Account
```bash
# Cluster uses managed identity
# Can access storage account from Example 02
# Configure CSI driver for blob/file mounting
```

### Connect to VNet Resources
```bash
# Pods can reach resources in VNet
# No additional configuration needed
# Subject to NSG rules
```

## Clean Up

```bash
# Delete AKS cluster (takes 5-10 minutes)
kubectl delete -f aks-cluster-basic.yaml

# Delete managed identity
kubectl delete -f managed-identity.yaml

# Verify deletion
az aks show -n aso-lab-aks -g aso-lab-rg
```

## Troubleshooting

### Provisioning Fails
- Check managed identity exists and is ready
- Verify VNet subnet has enough IPs
- Check Azure subscription quota
- Review ASO operator logs

### Cannot Access Cluster
- Ensure `az aks get-credentials` succeeded
- Check kubectl context: `kubectl config current-context`
- Verify network connectivity to Azure

### Node Creation Fails
- Check VM size availability in region
- Verify subnet size supports node count
- Check service principal/managed identity permissions

## Cost Optimization

- Use smaller VMs for development
- Enable autoscaling to scale to zero user nodes
- Use spot instances for fault-tolerant workloads
- Delete clusters when not in use
- Use Azure reservations for long-running clusters

## Next Steps
- Proceed to Example 05 for Key Vault integration
- Deploy applications to your AKS cluster
- Configure ingress controllers
- Implement GitOps with Flux or ArgoCD
- Set up monitoring and logging
