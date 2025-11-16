# Getting Started with ASO Lab

This quick start guide will help you get started with the ASO lab in 15 minutes.

## Prerequisites Check

Before starting, ensure you have:
- [ ] Azure subscription
- [ ] kubectl installed
- [ ] Azure CLI installed and logged in
- [ ] A Kubernetes cluster (kind, minikube, or AKS)

## Step 1: Install ASO v2 (5 minutes)

```bash
# Set your Azure credentials
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"

# Install cert-manager (required)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager

# Install ASO v2
kubectl apply --server-side -f https://github.com/Azure/azure-service-operator/releases/download/v2.5.0/azureserviceoperator_v2.5.0.yaml

# Create credentials secret
kubectl create namespace azureserviceoperator-system

kubectl create secret generic aso-credential \
  --namespace azureserviceoperator-system \
  --from-literal=AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
  --from-literal=AZURE_TENANT_ID=$AZURE_TENANT_ID \
  --from-literal=AZURE_CLIENT_ID=$AZURE_CLIENT_ID \
  --from-literal=AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET

# Verify installation
kubectl get pods -n azureserviceoperator-system
```

## Step 2: Deploy Your First Resource (5 minutes)

```bash
# Clone this repository
git clone https://github.com/sholaj/aso-lab.git
cd aso-lab

# Deploy a simple storage account
kubectl apply -f examples/azure-services/storage/basic-storage-account.yaml

# Watch it being created
kubectl get storageaccount mysa001 -n azure-storage -w

# Check status (wait for Ready condition)
kubectl get storageaccount mysa001 -n azure-storage -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

## Step 3: Explore the Lab (5 minutes)

### Learn Core Concepts
```bash
# Read core concepts
cat docs/01-core-concepts.md
```

### Try a Composite Resource
```bash
# Deploy storage with containers
kubectl apply -f examples/kro-templates/02-composite-resource.yaml

# Watch all resources
kubectl get resourcegroups,storageaccounts,storageaccountsblobservices,storageaccountsblobservicescontainers -n aso-composite -w
```

### Deploy Key Vault
```bash
# Deploy Key Vault (remember to update tenantId in the YAML)
kubectl apply -f examples/azure-services/key-vault/basic-keyvault.yaml

# Monitor
kubectl get vault mykeyvault001 -n azure-keyvault -w
```

## Common Commands

### Check Resource Status
```bash
# Get all ASO resources
kubectl get resourcegroups,storageaccounts,vaults --all-namespaces

# Describe a resource
kubectl describe storageaccount <name> -n <namespace>

# View detailed status
kubectl get storageaccount <name> -n <namespace> -o yaml
```

### Verify in Azure
```bash
# List resource groups
az group list --output table

# Check storage account
az storage account show --name mysa001 --resource-group storage-demo-rg

# List Key Vaults
az keyvault list --output table
```

### Cleanup
```bash
# Delete a specific resource
kubectl delete storageaccount mysa001 -n azure-storage

# Delete entire namespace (and all resources in it)
kubectl delete namespace azure-storage

# Or delete resource group (cascades to all children)
kubectl delete resourcegroup storage-demo-rg -n azure-storage
```

## Next Steps

1. **Learn more concepts**: Read [Core Concepts](docs/01-core-concepts.md)
2. **Deploy complex services**: Try [AKS](examples/azure-services/aks/) or [Log Analytics](examples/azure-services/log-analytics/)
3. **Setup GitOps**: Implement [Flux](examples/gitops/flux/) or [Argo CD](examples/gitops/argocd/)
4. **Customize templates**: Modify [KRO templates](examples/kro-templates/) for your needs

## Troubleshooting

### ASO pods not starting
```bash
kubectl get events -n azureserviceoperator-system --sort-by='.lastTimestamp'
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -c manager
```

### Resource not creating
```bash
kubectl describe <resource-type> <name> -n <namespace>
kubectl get <resource-type> <name> -n <namespace> -o jsonpath='{.status.conditions}'
```

### Authentication issues
```bash
# Verify secret exists
kubectl get secret aso-credential -n azureserviceoperator-system

# Test Azure credentials
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
```

## Learning Path

### Week 1: Basics
- Day 1: Install ASO, deploy simple resources
- Day 2: Understand CRDs and reconciliation
- Day 3: Practice with storage and Key Vault
- Day 4: Learn ownership and dependencies
- Day 5: Deploy complex resources

### Week 2: Advanced
- Day 1: KRO templates
- Day 2: Multi-resource patterns
- Day 3: GitOps with Flux
- Day 4: GitOps with Argo CD
- Day 5: Deploy full application stack

## Resources

- [ASO Documentation](https://azure.github.io/azure-service-operator/)
- [Azure Documentation](https://docs.microsoft.com/azure/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitOps Guide](https://opengitops.dev/)

## Need Help?

- Check [Prerequisites](docs/02-prerequisites.md) for setup issues
- Review service-specific READMEs in [examples/azure-services/](examples/azure-services/)
- Open an issue on GitHub
- Consult ASO documentation

Happy learning! 🚀
