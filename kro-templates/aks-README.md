# Phase 5: AKS Deployment with ASO + KRO

Deploy Azure Kubernetes Service (AKS) clusters using ASO and KRO templates.

## Files

- **aks-template.yaml**: KRO template definition for AKS clusters
- **aks-example-instance.yaml**: Example instance using the template
- **aks-with-nodepool.yaml**: Example of adding additional node pools

## Prerequisites

1. Resource Group must exist: `rg-aso-workloads-shola`
2. (Optional) Log Analytics Workspace for monitoring
3. ASO and KRO installed in the cluster

## Deploy AKS Using KRO Template

### Step 1: Install the AKS Template

```bash
kubectl apply -f aks-template.yaml

# Verify template is registered
kubectl get resourcegroup | grep aks-cluster-template
```

### Step 2: Customize and Deploy Instance

```bash
# Edit the instance file if needed
vi aks-example-instance.yaml

# Deploy the AKS cluster
kubectl apply -f aks-example-instance.yaml
```

### Step 3: Monitor Deployment

AKS cluster creation takes 10-15 minutes:

```bash
# Watch the cluster status
kubectl get managedcluster -w

# Describe the cluster
kubectl describe managedcluster aks-workload-cluster

# Check events
kubectl get events --field-selector involvedObject.name=aks-workload-cluster
```

### Step 4: Get AKS Credentials

Once the cluster is ready:

```bash
az aks get-credentials \
  --resource-group rg-aso-workloads-shola \
  --name aks-workload-cluster \
  --overwrite-existing

# Verify access
kubectl get nodes
```

## Add Additional Node Pools

After the cluster is created, add user node pools:

```bash
# Update the owner reference in aks-with-nodepool.yaml
# Then apply:
kubectl apply -f aks-with-nodepool.yaml

# Monitor node pool creation
kubectl get managedclustersagentpool -w
```

## Key Features Included

### 1. Managed Identity
- System-assigned identity (no password management)
- Used for Azure resource access

### 2. Network Configuration
- **Azure CNI Overlay**: Efficient IP usage
- **Standard Load Balancer**: Production-ready
- **Custom CIDR**: Service CIDR 10.0.0.0/16

### 3. Security
- **RBAC Enabled**: Kubernetes role-based access control
- **Workload Identity**: Secure pod-to-Azure authentication
- **OIDC Issuer**: Modern authentication
- **Azure Key Vault CSI Driver**: Inject secrets as volumes

### 4. Scalability
- **Auto-scaling**: Min 1, Max 5 nodes per pool
- **Multiple Node Pools**: System pool + user pools
- **Availability Zones**: High availability (in user pool example)

### 5. Monitoring (Optional)
- **Log Analytics Integration**: Container insights
- **Azure Defender**: Security monitoring (disabled for cost in lab)

### 6. Maintenance
- **Auto-upgrade**: Stable channel
- **Managed Kubernetes version**: Automatic patches

## Customization Options

Edit `aks-example-instance.yaml` to customize:

```yaml
spec:
  # Change cluster size
  nodeCount: 3
  nodeVMSize: Standard_D4s_v3

  # Change Kubernetes version
  kubernetesVersion: "1.29.0"

  # Change location
  location: westeurope

  # Add monitoring
  logAnalyticsWorkspace: "/subscriptions/.../workspaces/my-law"
```

## Cost Optimization for Lab

The default configuration uses:
- **Standard_D2s_v3**: 2 vCPUs, 8 GB RAM
- **2 nodes**: Minimum for production-like experience
- **Auto-scaling**: Scale down to 1 during inactivity

To minimize costs:
```yaml
spec:
  nodeCount: 1
  nodeVMSize: Standard_B2s  # Cheapest option
```

## Testing the Cluster

Deploy a test application:

```bash
# Create a test namespace
kubectl create namespace test-app

# Deploy nginx
kubectl create deployment nginx --image=nginx --namespace=test-app

# Expose it
kubectl expose deployment nginx --port=80 --type=LoadBalancer --namespace=test-app

# Get the external IP
kubectl get svc -n test-app -w
```

## Scale the Cluster

```bash
# Scale the default node pool
kubectl get managedcluster aks-workload-cluster -o yaml | \
  grep -A 5 agentPoolProfiles

# To scale, edit the instance YAML and reapply, or use Azure CLI:
az aks nodepool scale \
  --resource-group rg-aso-workloads-shola \
  --cluster-name aks-workload-cluster \
  --name systempool \
  --node-count 3
```

## Clean Up

```bash
# Delete the AKS cluster (takes 5-10 minutes)
kubectl delete -f aks-example-instance.yaml

# Or delete from Azure directly
az aks delete \
  --resource-group rg-aso-workloads-shola \
  --name aks-workload-cluster \
  --yes --no-wait
```

## Next Steps

- Integrate with Azure Key Vault for secrets
- Set up Azure Monitor for container insights
- Configure network policies
- Implement GitOps with Flux (Phase 6)
