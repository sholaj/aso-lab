# Prerequisites & Setup

This guide will help you set up your environment for working with Azure Service Operator v2.

## Table of Contents
- [Azure Requirements](#azure-requirements)
- [Kubernetes Cluster](#kubernetes-cluster)
- [Required CLI Tools](#required-cli-tools)
- [Installing ASO v2](#installing-aso-v2)
- [Configuration](#configuration)
- [Verification](#verification)

---

## Azure Requirements

### Azure Subscription

You need an active Azure subscription. If you don't have one:
- [Create a free Azure account](https://azure.microsoft.com/free/)
- Students can use [Azure for Students](https://azure.microsoft.com/free/students/)

### Azure Credentials

ASO v2 needs credentials to manage Azure resources. You have two options:

#### Option 1: Service Principal (Recommended for Learning)

```bash
# Create a service principal
az ad sp create-for-rbac --name aso-lab-sp --role Contributor --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>

# Save the output - you'll need:
# - appId (Client ID)
# - password (Client Secret)
# - tenant (Tenant ID)
```

#### Option 2: Managed Identity (Recommended for Production)

If running on Azure (AKS), use Workload Identity or Pod Identity.

---

## Kubernetes Cluster

### Minimum Requirements

- Kubernetes version: **1.23+**
- kubectl access with cluster-admin permissions
- At least 2GB RAM and 2 CPU cores available

### Cluster Options

#### Local Development

**Kind (Kubernetes in Docker)**
```bash
# Install kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/

# Create a cluster
kind create cluster --name aso-lab

# Verify
kubectl cluster-info --context kind-aso-lab
```

**Minikube**
```bash
# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start --cpus=2 --memory=4096 --driver=docker

# Verify
kubectl get nodes
```

**k3d**
```bash
# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Create cluster
k3d cluster create aso-lab --agents 2

# Verify
kubectl get nodes
```

#### Cloud Options

**Azure Kubernetes Service (AKS)**
```bash
# Create resource group
az group create --name aso-lab-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group aso-lab-rg \
  --name aso-lab-cluster \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group aso-lab-rg --name aso-lab-cluster
```

---

## Required CLI Tools

### kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

### Azure CLI

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Set subscription
az account set --subscription <YOUR_SUBSCRIPTION_ID>

# Verify
az account show
```

### Helm (v3)

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

### Optional but Recommended

**jq** (JSON processor)
```bash
sudo apt-get install jq -y
```

**yq** (YAML processor)
```bash
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**kubectl plugins**
```bash
# krew (kubectl plugin manager)
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

# Add to PATH
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Useful plugins
kubectl krew install tree
kubectl krew install neat
```

---

## Installing ASO v2

### Method 1: Using Helm (Recommended)

```bash
# Add the ASO Helm repository
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts

# Update Helm repositories
helm repo update

# Create namespace
kubectl create namespace azureserviceoperator-system

# Install ASO v2
helm install aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set azureSubscriptionID=<YOUR_SUBSCRIPTION_ID> \
  --set azureTenantID=<YOUR_TENANT_ID> \
  --set azureClientID=<YOUR_CLIENT_ID> \
  --set azureClientSecret=<YOUR_CLIENT_SECRET>
```

### Method 2: Using kubectl with manifests

```bash
# Install cert-manager (required for ASO)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager

# Install ASO v2 CRDs and controller
kubectl apply --server-side -f https://github.com/Azure/azure-service-operator/releases/download/v2.5.0/azureserviceoperator_v2.5.0.yaml

# Create secret with Azure credentials
kubectl create namespace azureserviceoperator-system

kubectl create secret generic aso-credential \
  --namespace azureserviceoperator-system \
  --from-literal=AZURE_SUBSCRIPTION_ID=<YOUR_SUBSCRIPTION_ID> \
  --from-literal=AZURE_TENANT_ID=<YOUR_TENANT_ID> \
  --from-literal=AZURE_CLIENT_ID=<YOUR_CLIENT_ID> \
  --from-literal=AZURE_CLIENT_SECRET=<YOUR_CLIENT_SECRET>
```

### Installing Specific CRDs

By default, ASO installs CRDs for all Azure services. To optimize, you can install only what you need:

```bash
# Install only specific service CRDs
helm install aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set crdPattern='resources.azure.com/*;storage.azure.com/*;keyvault.azure.com/*' \
  --set azureSubscriptionID=<YOUR_SUBSCRIPTION_ID> \
  --set azureTenantID=<YOUR_TENANT_ID> \
  --set azureClientID=<YOUR_CLIENT_ID> \
  --set azureClientSecret=<YOUR_CLIENT_SECRET>
```

---

## Configuration

### Setting Default Subscription

Create a global configuration:

```yaml
# aso-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aso-controller-settings
  namespace: azureserviceoperator-system
data:
  AZURE_SUBSCRIPTION_ID: "<YOUR_SUBSCRIPTION_ID>"
  AZURE_TENANT_ID: "<YOUR_TENANT_ID>"
```

### Using Multiple Subscriptions

You can specify different subscriptions per resource:

```yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: my-rg
  namespace: default
  annotations:
    serviceoperator.azure.com/credential-from: azure-credentials
spec:
  azureName: my-rg
  location: eastus
```

### Credential Management

Store credentials securely:

```bash
# Create namespace-specific credentials
kubectl create secret generic azure-credentials \
  --namespace default \
  --from-literal=AZURE_SUBSCRIPTION_ID=<SUBSCRIPTION_ID> \
  --from-literal=AZURE_TENANT_ID=<TENANT_ID> \
  --from-literal=AZURE_CLIENT_ID=<CLIENT_ID> \
  --from-literal=AZURE_CLIENT_SECRET=<CLIENT_SECRET>
```

---

## Verification

### Verify ASO Installation

```bash
# Check ASO pods are running
kubectl get pods -n azureserviceoperator-system

# Expected output:
# NAME                                                READY   STATUS    RESTARTS   AGE
# azureserviceoperator-controller-manager-xxxxx       2/2     Running   0          2m

# Check installed CRDs
kubectl get crds | grep azure.com | wc -l

# Should show 200+ CRDs

# Check specific service CRDs
kubectl get crds | grep storage.azure.com
kubectl get crds | grep keyvault.azure.com
```

### Test Basic Functionality

Create a simple resource group:

```bash
# Create test resource group
cat <<EOF | kubectl apply -f -
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: aso-test-rg
  namespace: default
spec:
  location: eastus
  tags:
    environment: test
EOF

# Watch the resource
kubectl get resourcegroup aso-test-rg -w

# Check status (wait for Ready condition)
kubectl get resourcegroup aso-test-rg -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# Verify in Azure
az group show --name aso-test-rg

# Cleanup
kubectl delete resourcegroup aso-test-rg
```

### Verify Logs

```bash
# Check controller logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -c manager --tail=50

# Watch for reconciliation events
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -c manager -f | grep reconcile
```

---

## Troubleshooting

### Common Issues

**Issue: Pods not starting**
```bash
# Check pod events
kubectl describe pod -n azureserviceoperator-system <pod-name>

# Check for image pull issues
kubectl get events -n azureserviceoperator-system --sort-by='.lastTimestamp'
```

**Issue: Authentication failures**
```bash
# Verify secret exists
kubectl get secret -n azureserviceoperator-system aso-credential

# Verify secret contents (be careful with sensitive data)
kubectl get secret -n azureserviceoperator-system aso-credential -o yaml

# Test Azure credentials manually
az login --service-principal -u <CLIENT_ID> -p <CLIENT_SECRET> --tenant <TENANT_ID>
```

**Issue: CRDs not found**
```bash
# List all CRDs
kubectl get crds | grep azure.com

# Reinstall CRDs
kubectl apply --server-side -f https://github.com/Azure/azure-service-operator/releases/download/v2.5.0/azureserviceoperator_v2.5.0.yaml
```

### Getting Help

- Check [ASO v2 Troubleshooting Guide](https://azure.github.io/azure-service-operator/guide/troubleshooting/)
- Review [GitHub Issues](https://github.com/Azure/azure-service-operator/issues)
- Join [CNCF Slack #azure-service-operator](https://cloud-native.slack.com/)

---

## Next Steps

Now that your environment is set up:

1. Review [Core Concepts](./01-core-concepts.md) if you haven't already
2. Explore [KRO Templates](../examples/kro-templates/)
3. Deploy your first [Azure Service](../examples/azure-services/storage/)

---

## Quick Reference

### Environment Variables
```bash
export AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
export AZURE_TENANT_ID="<your-tenant-id>"
export AZURE_CLIENT_ID="<your-client-id>"
export AZURE_CLIENT_SECRET="<your-client-secret>"
```

### Useful Commands
```bash
# Watch all ASO resources
kubectl get resourcegroups,storageaccounts,vaults --all-namespaces -w

# Get resource status
kubectl get <resource-type> <name> -o jsonpath='{.status.conditions}'

# View resource in Azure format
kubectl get <resource-type> <name> -o jsonpath='{.status}'

# Delete resource (cascade to Azure)
kubectl delete <resource-type> <name>
```
