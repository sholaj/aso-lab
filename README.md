# ASO + KRO Practical Learning Lab

A comprehensive hands-on lab for learning **Azure Service Operator v2 (ASO)** and **Kubernetes Resource Orchestrator (KRO)** using a real Azure subscription.

## 🎯 What You'll Learn

- Deploy Azure resources (Key Vault, Storage, AKS, ACR, Log Analytics) using Kubernetes manifests
- Understand ASO CRDs, reconciliation patterns, and ownership semantics
- Build reusable infrastructure templates with KRO
- Implement GitOps workflows with Flux CD or Argo CD
- Develop muscle memory for modern cloud-native infrastructure management

## 📋 Prerequisites

Before starting, ensure you have:

- **Azure Subscription** with Owner or Contributor role
  - Subscription ID: `1aa6797c-bba1-4073-a0f8-e49d0e79fd4f`
  - Region: `North Europe`
- **Tools Installed**:
  - `kubectl` - Kubernetes CLI
  - `helm` - Package manager for Kubernetes
  - `az` - Azure CLI
  - `git` - Version control
  - (Optional) `flux` or `argocd` - GitOps tools

## 🚀 Quick Start

### 1. Create Bootstrap Infrastructure

```bash
cd 00-aks-bootstrap

# Create AKS cluster (10-15 minutes)
./00-create-aks-cluster.sh

# Install ASO v2 (5 minutes)
./01-install-aso.sh

# Install KRO (2 minutes)
./02-install-kro.sh

# Validate installation
./03-validate-setup.sh
```

### 2. Deploy Your First ASO Resource

```bash
cd ../01-resource-group

# Deploy a Resource Group to Azure via Kubernetes
kubectl apply -f resourcegroup.yaml

# Watch it reconcile
kubectl get resourcegroup -w

# Verify in Azure
az group show --name rg-aso-workloads-shola
```

**🎉 Congratulations!** You've just managed Azure infrastructure using Kubernetes!

## 📚 Learning Path

Follow these phases in order to build expertise:

### **Phase 1: Install the Tools** ✅
Location: `00-aks-bootstrap/`

- [x] Create AKS cluster
- [x] Install ASO v2 with Helm
- [x] Install KRO
- [x] Validate CRDs

**Outcome**: Kubernetes becomes your Azure control plane

---

### **Phase 2: Understand ASO Core Mechanics** 🧠
Location: All phase directories

Tasks:
- Inspect ASO CRDs with `kubectl explain`
- Watch reconciliation loops with `kubectl get events`
- Understand API version mapping to Azure REST API
- Test resource lifecycle (create, update, delete)

**Key Commands**:
```bash
# Explore CRDs
kubectl get crds | grep azure.com

# Explain a CRD schema
kubectl explain vault.spec --recursive

# Watch events
kubectl get events --sort-by='.lastTimestamp' -w

# See reconciliation status
kubectl describe resourcegroup rg-aso-workloads-shola
```

**Outcome**: Deep understanding of how ASO maps Kubernetes ↔ Azure

---

### **Phase 3: Build Foundational Resources** 🏗️
Location: `01-resource-group/`, `02-keyvault/`, `03-storage/`, `04-insights-law/`, `05-container-registry/`

Deploy these Azure resources using ASO:

| Resource | File | Description |
|----------|------|-------------|
| Resource Group | `01-resource-group/resourcegroup.yaml` | Logical container |
| Key Vault | `02-keyvault/keyvault.yaml` | Secrets management |
| Storage Account | `03-storage/storageaccount.yaml` | Blob/file storage |
| Log Analytics | `04-insights-law/loganalytics.yaml` | Monitoring workspace |
| Container Registry | `05-container-registry/acr.yaml` | Docker images |

**Important**: Update `TENANT_ID_PLACEHOLDER` in Key Vault manifest:
```bash
TENANT_ID=$(az account show --query tenantId -o tsv)
sed -i "s/TENANT_ID_PLACEHOLDER/$TENANT_ID/g" 02-keyvault/keyvault.yaml
```

**Outcome**: Build complete Azure infrastructure using only YAML

---

### **Phase 4: Templating with KRO** 🎨
Location: `kro-templates/`

Convert individual resources into reusable templates:

1. **Resource Group Template** - Basic parameterization
2. **Key Vault Template** - Advanced configuration
3. **Infrastructure Composition** - Multi-resource stack (RG + KV + Storage + LAW)

**Example Usage**:
```bash
# Install templates
kubectl apply -f kro-templates/infra-composition.yaml

# Create instance (deploys 4 resources!)
TENANT_ID=$(az account show --query tenantId -o tsv)
cat <<EOF | kubectl apply -f -
apiVersion: v1alpha1
kind: InfraComposition
metadata:
  name: myapp-infra
spec:
  projectName: myapp
  location: northeurope
  tenantId: "$TENANT_ID"
  owner: shola
EOF

# Watch all resources being created
kubectl get resourcegroup,storageaccount,vault,workspace -w
```

**Outcome**: Build platform engineering abstractions

---

### **Phase 5: Deploy AKS with ASO** ☸️
Location: `kro-templates/aks-*.yaml`

Deploy production-grade AKS clusters using KRO templates:

**Features Included**:
- Managed Identity
- Azure CNI Overlay networking
- Auto-scaling (1-5 nodes)
- OIDC issuer + Workload Identity
- Azure Key Vault CSI driver
- Log Analytics integration (optional)

**Deploy**:
```bash
# Install AKS template
kubectl apply -f kro-templates/aks-template.yaml

# Deploy cluster instance
kubectl apply -f kro-templates/aks-example-instance.yaml

# Monitor (10-15 minutes)
kubectl get managedcluster -w
```

**Outcome**: Replicate production AKS patterns declaratively

---

### **Phase 6: GitOps Integration** 🔄
Location: `flux/` or `argo/`

Implement end-to-end GitOps workflow:

**Choose Your Tool**:

#### **Option A: Flux CD** (CLI-focused)
```bash
cd flux
./install-flux.sh

# Bootstrap with GitHub
flux bootstrap github \
  --owner=sholaj \
  --repository=aso-lab \
  --branch=main \
  --path=./flux/clusters/lab \
  --personal
```

#### **Option B: Argo CD** (UI-focused)
```bash
cd argo
./install-argo.sh

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080

# Create applications
kubectl apply -f application.yaml
```

**Test Drift Detection**:
```bash
# Delete a resource manually
kubectl delete resourcegroup rg-aso-workloads-shola

# Watch GitOps recreate it automatically!
kubectl get resourcegroup -w
```

**Outcome**: Fully automated infrastructure-as-code with Git as source of truth

---

## 📁 Repository Structure

```
aso-lab/
├── 00-aks-bootstrap/          # Phase 1: Setup scripts
│   ├── 00-create-aks-cluster.sh
│   ├── 01-install-aso.sh
│   ├── 02-install-kro.sh
│   └── 03-validate-setup.sh
│
├── 01-resource-group/         # Phase 3: Resource Group
│   ├── resourcegroup.yaml
│   └── README.md
│
├── 02-keyvault/               # Phase 3: Key Vault
│   ├── keyvault.yaml
│   └── README.md
│
├── 03-storage/                # Phase 3: Storage Account
│   ├── storageaccount.yaml
│   └── README.md
│
├── 04-insights-law/           # Phase 3: Log Analytics
│   ├── loganalytics.yaml
│   └── README.md
│
├── 05-container-registry/     # Phase 3: Container Registry
│   ├── acr.yaml
│   └── README.md
│
├── kro-templates/             # Phase 4 & 5: KRO Templates
│   ├── resourcegroup-template.yaml
│   ├── keyvault-template.yaml
│   ├── infra-composition.yaml
│   ├── aks-template.yaml
│   ├── aks-with-nodepool.yaml
│   ├── aks-example-instance.yaml
│   ├── README.md
│   └── aks-README.md
│
├── flux/                      # Phase 6: Flux GitOps
│   ├── install-flux.sh
│   ├── git-repository.yaml
│   ├── kustomization.yaml
│   └── README.md
│
├── argo/                      # Phase 6: Argo CD GitOps
│   ├── install-argo.sh
│   ├── application.yaml
│   └── README.md
│
├── .claude.md                 # Learning blueprint
└── README.md                  # This file
```

## 🛠️ Common Operations

### Check ASO Resource Status

```bash
# List all ASO resources
kubectl get resourcegroup,vault,storageaccount,workspace,registry,managedcluster

# Describe a resource
kubectl describe vault kv-aso-lab-shola

# View events
kubectl get events --sort-by='.lastTimestamp' | grep kv-aso-lab-shola
```

### Debugging ASO Issues

```bash
# Check ASO controller logs
kubectl logs -n azureserviceoperator-system -l control-plane=controller-manager --tail=100

# Check resource conditions
kubectl get vault kv-aso-lab-shola -o jsonpath='{.status.conditions}' | jq

# Force reconciliation (delete and recreate)
kubectl delete vault kv-aso-lab-shola
kubectl apply -f 02-keyvault/keyvault.yaml
```

### Cost Management

**Minimize Costs**:
- Use `Standard_B2s` VMs for AKS (cheapest)
- Set node count to 1 for lab clusters
- Delete resources when not in use:
  ```bash
  # Delete specific resources
  kubectl delete -f kro-templates/aks-example-instance.yaml

  # Or delete entire resource group from Azure
  az group delete --name rg-aso-workloads-shola --yes --no-wait
  ```

**Monitor Costs**:
```bash
# List all resource groups
az group list --query "[?tags.owner=='shola']" -o table

# Get cost estimate (requires cost management enabled)
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31
```

## 🔧 Troubleshooting

### ASO Installation Issues

**Service Principal Already Exists**:
```bash
# List existing SPs
az ad sp list --display-name sp-aso-lab-shola

# Delete and recreate
az ad sp delete --id <app-id>
./01-install-aso.sh
```

**CRDs Not Installing**:
```bash
# Manually install ASO with all CRDs
helm upgrade --install aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --create-namespace \
  --set crdPattern='*'
```

### Resource Reconciliation Failures

**Check Status**:
```bash
kubectl describe <resource-type> <resource-name>

# Look for errors in "Status" section
```

**Common Issues**:
1. **Invalid Tenant ID**: Update `TENANT_ID_PLACEHOLDER` in manifests
2. **Naming Conflicts**: Storage/ACR names must be globally unique
3. **Permission Issues**: Ensure service principal has Contributor role
4. **API Version Mismatch**: Use compatible ASO CRD versions

### GitOps Not Syncing

**Flux**:
```bash
# Force reconciliation
flux reconcile source git aso-lab
flux reconcile kustomization aso-infrastructure

# Check logs
flux logs --all-namespaces --follow
```

**Argo CD**:
```bash
# Refresh application
argocd app get aso-infrastructure --refresh

# Check sync status
argocd app sync aso-infrastructure
```

## 🎓 Learning Resources

### Azure Service Operator
- [ASO Documentation](https://azure.github.io/azure-service-operator/)
- [ASO GitHub](https://github.com/Azure/azure-service-operator)
- [CRD Reference](https://azure.github.io/azure-service-operator/reference/)

### Kubernetes Resource Orchestrator
- [KRO Documentation](https://github.com/Azure/kro)
- [KRO Examples](https://github.com/Azure/kro/tree/main/examples)

### GitOps
- [Flux Documentation](https://fluxcd.io/docs/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)

### Kubernetes
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## 🧹 Cleanup

### Delete All Resources

**Option 1: Delete from Kubernetes** (ASO will delete from Azure)
```bash
# Delete all resources
kubectl delete -f 01-resource-group/ -f 02-keyvault/ -f 03-storage/ -f 04-insights-law/ -f 05-container-registry/

# Verify deletion in Azure
az group list --query "[?tags.owner=='shola']" -o table
```

**Option 2: Delete Resource Group from Azure**
```bash
# Delete workloads resource group
az group delete --name rg-aso-workloads-shola --yes --no-wait

# Delete lab infrastructure (AKS cluster)
az group delete --name rg-aso-lab-shola --yes --no-wait
```

**Uninstall Tools**:
```bash
# Uninstall Flux
flux uninstall

# Uninstall Argo CD
kubectl delete namespace argocd

# Uninstall KRO
kubectl delete -f https://github.com/Azure/kro/releases/download/v0.1.0/kro.yaml

# Uninstall ASO
helm uninstall aso2 -n azureserviceoperator-system
kubectl delete namespace azureserviceoperator-system
```

## 🤝 Contributing

This is a personal learning lab, but suggestions are welcome!

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📝 License

MIT License - Free to use for learning and education.

## ✨ Credits

Built as a learning lab for mastering Azure Service Operator v2 and KRO.

**Author**: Shola
**Purpose**: Hands-on ASO/KRO learning for UBS UK8s GitOps migration
**Region**: North Europe
**Subscription**: 1aa6797c-bba1-4073-a0f8-e49d0e79fd4f

---

**Happy Learning! 🚀**

Start with Phase 1: `cd 00-aks-bootstrap && ./00-create-aks-cluster.sh`
