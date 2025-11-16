# ASO Lab - Quick Start Guide

Get up and running with Azure Service Operator in 30 minutes!

## Prerequisites Check

```bash
# Verify required tools
kubectl version --client
helm version
az version
git --version

# Login to Azure
az login
az account set --subscription 1aa6797c-bba1-4073-a0f8-e49d0e79fd4f
az account show
```

## Step-by-Step Setup

### Step 1: Create AKS Cluster (10-15 min)

```bash
cd 00-aks-bootstrap
./00-create-aks-cluster.sh
```

**Wait for**: Cluster creation to complete

**Verify**:
```bash
kubectl get nodes
kubectl cluster-info
```

---

### Step 2: Install ASO (5 min)

```bash
./01-install-aso.sh
```

**Wait for**: ASO pods to be ready

**Verify**:
```bash
kubectl get pods -n azureserviceoperator-system
kubectl get crds | grep azure.com | head -10
```

---

### Step 3: Install KRO (2 min)

```bash
./02-install-kro.sh
```

**Verify**:
```bash
kubectl get pods -n kro-system
```

---

### Step 4: Validate Setup (1 min)

```bash
./03-validate-setup.sh
```

You should see:
- ✅ ASO pods running
- ✅ KRO pods running
- ✅ Multiple CRDs installed

---

### Step 5: Deploy First Resource (2 min)

```bash
cd ../01-resource-group
kubectl apply -f resourcegroup.yaml
```

**Watch it reconcile**:
```bash
kubectl get resourcegroup -w
```

**Verify in Azure**:
```bash
az group show --name rg-aso-workloads-shola
```

**🎉 Success!** You've deployed an Azure resource using Kubernetes!

---

## Next Steps

### Deploy More Resources

```bash
# Get your tenant ID (needed for Key Vault)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Update Key Vault manifest
cd ../02-keyvault
sed -i "s/TENANT_ID_PLACEHOLDER/$TENANT_ID/g" keyvault.yaml

# Deploy Key Vault
kubectl apply -f keyvault.yaml

# Deploy Storage Account
cd ../03-storage
kubectl apply -f storageaccount.yaml

# Deploy Log Analytics
cd ../04-insights-law
kubectl apply -f loganalytics.yaml

# Deploy Container Registry
cd ../05-container-registry
kubectl apply -f acr.yaml
```

### Watch All Resources

```bash
kubectl get resourcegroup,vault,storageaccount,workspace,registry -w
```

### Try KRO Templates

```bash
cd ../kro-templates

# Install infrastructure composition template
kubectl apply -f infra-composition.yaml

# Create a full infrastructure stack with one command!
TENANT_ID=$(az account show --query tenantId -o tsv)
cat <<EOF | kubectl apply -f -
apiVersion: v1alpha1
kind: InfraComposition
metadata:
  name: demo-infra
spec:
  projectName: demo
  location: northeurope
  tenantId: "$TENANT_ID"
  owner: shola
EOF

# Watch 4 resources being created from 1 YAML!
kubectl get resourcegroup,storageaccount,vault,workspace -w
```

### Set Up GitOps

**With Flux**:
```bash
cd ../flux
./install-flux.sh
```

**With Argo CD**:
```bash
cd ../argo
./install-argo.sh
```

---

## Troubleshooting

### ASO Pods Not Starting

```bash
# Check pod status
kubectl get pods -n azureserviceoperator-system

# View logs
kubectl logs -n azureserviceoperator-system -l control-plane=controller-manager --tail=50

# Check secrets
kubectl get secret aso-controller-settings -n azureserviceoperator-system
```

### Resource Not Reconciling

```bash
# Describe the resource
kubectl describe <resource-type> <resource-name>

# Check events
kubectl get events --sort-by='.lastTimestamp' | grep <resource-name>

# View ASO logs
kubectl logs -n azureserviceoperator-system -l control-plane=controller-manager --tail=100 | grep <resource-name>
```

### Permission Errors

```bash
# Verify service principal role
az role assignment list --assignee $(az ad sp list --display-name sp-aso-lab-shola --query '[0].appId' -o tsv)

# Recreate service principal if needed
az ad sp delete --id $(az ad sp list --display-name sp-aso-lab-shola --query '[0].appId' -o tsv)
cd 00-aks-bootstrap
./01-install-aso.sh
```

---

## Common Commands

```bash
# List all ASO resources
kubectl get resourcegroup,vault,storageaccount,workspace,registry,managedcluster

# Get resource in YAML format
kubectl get vault kv-aso-lab-shola -o yaml

# Delete a resource (will delete from Azure too!)
kubectl delete vault kv-aso-lab-shola

# Force reconciliation
kubectl delete pod -n azureserviceoperator-system -l control-plane=controller-manager
```

---

## Cleanup

### Delete All Resources

```bash
# Delete all ASO resources
kubectl delete -f 01-resource-group/ -f 02-keyvault/ -f 03-storage/ -f 04-insights-law/ -f 05-container-registry/
```

### Delete Everything (including AKS)

```bash
# Delete from Azure (fastest)
az group delete --name rg-aso-workloads-shola --yes --no-wait
az group delete --name rg-aso-lab-shola --yes --no-wait
```

---

## What's Next?

1. **Read the full README**: [README.md](README.md)
2. **Explore KRO templates**: [kro-templates/README.md](kro-templates/README.md)
3. **Set up GitOps**: [flux/README.md](flux/README.md) or [argo/README.md](argo/README.md)
4. **Deploy AKS**: [kro-templates/aks-README.md](kro-templates/aks-README.md)

---

**Total Time**: ~30 minutes
**Cost**: ~$2-3/day (delete when not in use!)
**Outcome**: Full Azure infrastructure managed via Kubernetes! 🚀
