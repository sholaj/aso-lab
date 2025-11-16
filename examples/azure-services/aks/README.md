# Azure Kubernetes Service (AKS) Examples

This directory contains examples for deploying AKS clusters using ASO v2.

## Examples

1. **basic-aks-cluster.yaml** - Simple AKS cluster with system node pool
2. **aks-with-monitoring.yaml** - AKS with Log Analytics integration
3. **production-aks.yaml** - Production-ready AKS with multiple node pools

## Quick Start

```bash
# Deploy basic AKS cluster
kubectl apply -f basic-aks-cluster.yaml

# Check status (this takes 10-15 minutes)
kubectl get managedcluster myakscluster -n azure-aks -w

# Get credentials after cluster is ready
az aks get-credentials --resource-group aks-demo-rg --name myakscluster
```

## AKS Cluster Naming Rules

- 1-63 characters
- Alphanumeric and hyphens only
- Start and end with alphanumeric
- Lowercase recommended

## Architecture Options

### Basic (Development)
- Single node pool
- Standard_D2s_v3 VMs
- 1-3 nodes
- No availability zones

### Standard (Production)
- System + User node pools
- Standard_D4s_v3 or larger VMs
- 3+ nodes
- Availability zones
- Monitoring enabled

### Advanced (Enterprise)
- Multiple node pools (system, apps, GPU, spot)
- Autoscaling enabled
- Private cluster
- Network policies
- Azure AD integration
- Workload identity

## Node Pool Types

### System Node Pool
- Required for system pods (CoreDNS, metrics-server, etc.)
- Should not run application workloads
- Minimum 2 nodes recommended
- Use taints to prevent app pods

### User Node Pool
- For application workloads
- Can have multiple user node pools
- Can use different VM sizes
- Can enable autoscaling

## Networking Options

### kubenet (Basic)
- Default option
- Simple networking
- Uses Azure-assigned IPs
- Good for development

### Azure CNI
- Advanced networking
- Pods get Azure VNET IPs
- Required for: Private clusters, Windows nodes, Network policies
- More IP address consumption

## Common Features

### Auto-scaling
- Cluster Autoscaler: Scales nodes automatically
- Horizontal Pod Autoscaler (HPA): Scales pods
- Vertical Pod Autoscaler (VPA): Adjusts pod resources

### Monitoring
- Container Insights
- Log Analytics integration
- Prometheus & Grafana
- Azure Monitor alerts

### Security
- Azure AD integration
- Kubernetes RBAC
- Azure RBAC for cluster access
- Pod security policies/standards
- Network policies

## Cluster Upgrades

```bash
# Check available versions
az aks get-versions --location eastus --output table

# Upgrade cluster
az aks upgrade \
  --resource-group aks-demo-rg \
  --name myakscluster \
  --kubernetes-version 1.28.3
```

## Cost Optimization

### Development
- Use Standard_B2s or Standard_D2s_v3
- Single node pool
- Stop cluster when not in use

### Production
- Use Reserved Instances
- Enable cluster autoscaler
- Use spot instances for fault-tolerant workloads
- Right-size node pools

## Troubleshooting

### Cluster creation fails
```bash
# Check ASO logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -c manager --tail=100

# Check resource status
kubectl describe managedcluster myakscluster -n azure-aks
```

### Node pool issues
```bash
# List node pools
az aks nodepool list --resource-group aks-demo-rg --cluster-name myakscluster

# Check node pool status
kubectl get nodes
kubectl describe node <node-name>
```

### Connectivity issues
```bash
# Verify network configuration
az aks show --resource-group aks-demo-rg --name myakscluster --query networkProfile

# Check DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

## Best Practices

✅ **DO:**
- Use managed identity
- Enable monitoring and logging
- Use multiple node pools for different workloads
- Enable autoscaling for production
- Use availability zones
- Implement network policies
- Regular cluster upgrades
- Use Azure Policy for governance

❌ **DON'T:**
- Run apps on system node pool
- Use single node in production
- Ignore security updates
- Over-provision nodes
- Skip monitoring setup
- Use default service principal credentials

## References

- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [AKS Networking](https://docs.microsoft.com/azure/aks/concepts-network)
- [AKS Security](https://docs.microsoft.com/azure/aks/concepts-security)
