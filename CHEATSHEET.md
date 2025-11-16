# ASO & KRO Cheat Sheet

Quick reference guide for common commands and patterns.

## Quick Links

- [Installation](#installation)
- [Common Commands](#common-commands)
- [Resource Templates](#resource-templates)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Installation

### Install ASO
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create credentials secret
kubectl create namespace azureserviceoperator-system
kubectl create secret generic aso-controller-settings \
  -n azureserviceoperator-system \
  --from-literal=AZURE_SUBSCRIPTION_ID="<subscription-id>" \
  --from-literal=AZURE_TENANT_ID="<tenant-id>" \
  --from-literal=AZURE_CLIENT_ID="<client-id>" \
  --from-literal=AZURE_CLIENT_SECRET="<client-secret>"

# Install ASO with Helm
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo update
helm install aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set crdPattern='resources.azure.com/*;storage.azure.com/*;network.azure.com/*'
```

## Common Commands

### Resource Management
```bash
# Apply resources
kubectl apply -f resource.yaml

# Apply directory
kubectl apply -f directory/

# Apply with Kustomize
kubectl apply -k overlays/dev/

# Delete resources
kubectl delete -f resource.yaml

# Delete by label
kubectl delete all -l stack=myapp
```

### Checking Status
```bash
# List resources
kubectl get resourcegroups
kubectl get storageaccounts
kubectl get virtualnetworks
kubectl get managedclusters  # AKS

# Get all ASO resources
kubectl get resourcegroups,storageaccounts,virtualnetworks,vaults

# Describe resource (see events)
kubectl describe resourcegroup my-rg

# Watch resource creation
kubectl get resourcegroup my-rg -w

# Wait for resource to be ready
kubectl wait --for=condition=Ready --timeout=300s resourcegroup/my-rg
```

### Debugging
```bash
# Check ASO operator logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager

# Follow logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -f

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check resource status
kubectl get resourcegroup my-rg -o yaml

# Get error details
kubectl describe resourcegroup my-rg | grep -A 10 "Events:"
```

### Azure CLI Verification
```bash
# Verify resource group
az group show -n my-rg

# Verify storage account
az storage account show -n mystorageacct -g my-rg

# Verify VNet
az network vnet show -n my-vnet -g my-rg

# Verify AKS
az aks show -n my-aks -g my-rg
```

## Resource Templates

### Resource Group
```yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: my-rg
  namespace: default
spec:
  location: eastus
  tags:
    Environment: dev
```

### Storage Account
```yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorageacct
  namespace: default
spec:
  location: eastus
  owner:
    name: my-rg
  kind: StorageV2
  sku:
    name: Standard_LRS
  accessTier: Hot
```

### Virtual Network
```yaml
apiVersion: network.azure.com/v1api20201101
kind: VirtualNetwork
metadata:
  name: my-vnet
  namespace: default
spec:
  location: eastus
  owner:
    name: my-rg
  addressSpace:
    addressPrefixes:
    - 10.0.0.0/16
  subnets:
  - name: default-subnet
    properties:
      addressPrefix: 10.0.1.0/24
```

### Key Vault
```yaml
apiVersion: keyvault.azure.com/v1api20210401preview
kind: Vault
metadata:
  name: my-kv
  namespace: default
spec:
  location: eastus
  owner:
    name: my-rg
  properties:
    sku:
      family: A
      name: standard
    tenantId: "<tenant-id>"
    enableSoftDelete: true
    enableRbacAuthorization: true
```

### AKS Cluster
```yaml
apiVersion: containerservice.azure.com/v1api20231001
kind: ManagedCluster
metadata:
  name: my-aks
  namespace: default
spec:
  location: eastus
  owner:
    name: my-rg
  dnsPrefix: my-aks
  kubernetesVersion: "1.28.0"
  identity:
    type: SystemAssigned
  agentPoolProfiles:
  - name: system
    count: 3
    vmSize: Standard_D2s_v3
    mode: System
  networkProfile:
    networkPlugin: azure
    serviceCidr: 10.2.0.0/16
    dnsServiceIP: 10.2.0.10
```

## Kustomize Patterns

### Base Structure
```bash
base/
├── kustomization.yaml
├── resourcegroup.yaml
└── storage.yaml
```

### Overlay Structure
```bash
overlays/
├── dev/
│   └── kustomization.yaml
└── prod/
    └── kustomization.yaml
```

### Base Kustomization
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- resourcegroup.yaml
- storage.yaml
```

### Overlay Kustomization
```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base
nameSuffix: -dev
commonLabels:
  environment: dev
```

### Apply with Kustomize
```bash
# Build and preview
kubectl kustomize overlays/dev/

# Apply
kubectl apply -k overlays/dev/

# Delete
kubectl delete -k overlays/dev/
```

## Helm Patterns

### Chart Structure
```bash
my-chart/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-prod.yaml
└── templates/
    ├── resourcegroup.yaml
    └── storage.yaml
```

### Chart.yaml
```yaml
apiVersion: v2
name: my-infrastructure
version: 1.0.0
description: Azure infrastructure using ASO
```

### Template with Values
```yaml
# templates/storage.yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: {{ .Values.storage.name }}
spec:
  location: {{ .Values.location }}
  sku:
    name: {{ .Values.storage.sku }}
```

### Helm Commands
```bash
# Install
helm install myapp ./my-chart -f values-dev.yaml

# Upgrade
helm upgrade myapp ./my-chart -f values-prod.yaml

# Uninstall
helm uninstall myapp

# List releases
helm list

# Get values
helm get values myapp
```

## Troubleshooting

### Resource Not Creating

**Check resource status:**
```bash
kubectl describe resourcegroup my-rg
```

**Check ASO logs:**
```bash
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager --tail=100
```

**Common issues:**
- Invalid credentials
- Insufficient permissions
- Name conflicts
- Quota limits

### Authentication Errors

**Verify secret:**
```bash
kubectl get secret aso-controller-settings -n azureserviceoperator-system -o yaml
```

**Check service principal:**
```bash
az ad sp show --id <client-id>
az role assignment list --assignee <client-id>
```

### Resource Stuck

**Force delete:**
```bash
kubectl delete resourcegroup my-rg --grace-period=0 --force
```

**Remove finalizers:**
```bash
kubectl patch resourcegroup my-rg -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### CRD Issues

**List installed CRDs:**
```bash
kubectl get crds | grep azure.com
```

**Install missing CRDs:**
```bash
helm upgrade aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set crdPattern='resources.azure.com/*;storage.azure.com/*;...'
```

## Best Practices

### Naming Conventions
```yaml
# Use consistent patterns
resourceGroup: {project}-{env}-rg
storage: {project}{env}sa
vnet: {project}-{env}-vnet
keyVault: {project}-{env}-kv
```

### Tagging
```yaml
tags:
  Environment: production
  Project: myapp
  ManagedBy: ASO
  Owner: team-name
  CostCenter: department
```

### Labels
```yaml
metadata:
  labels:
    stack: myapp
    tier: storage
    environment: prod
```

### Dependencies
```yaml
# Use spec.owner for dependencies
spec:
  owner:
    name: parent-resource
```

### Secrets Management
```yaml
# Export to Kubernetes secret
operatorSpec:
  secrets:
    key1:
      name: my-secret
      key: storageKey
```

## Useful Aliases

Add to your `.bashrc` or `.zshrc`:

```bash
# ASO aliases
alias k='kubectl'
alias kgaso='kubectl get resourcegroups,storageaccounts,virtualnetworks,vaults'
alias kdaso='kubectl describe'
alias kaaso='kubectl apply -f'
alias kkdev='kubectl apply -k overlays/dev/'
alias kkprod='kubectl apply -k overlays/prod/'

# ASO operator logs
alias asologs='kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager'
alias asofollow='kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -f'

# Watch resources
alias kwatch='watch -n 2 kubectl get resourcegroups,storageaccounts,virtualnetworks'
```

## Environment Variables

```bash
# Azure
export AZURE_SUBSCRIPTION_ID="<subscription-id>"
export AZURE_TENANT_ID="<tenant-id>"
export AZURE_CLIENT_ID="<client-id>"
export AZURE_CLIENT_SECRET="<client-secret>"

# Kubernetes
export KUBECONFIG=~/.kube/config
```

## Quick Reference URLs

- ASO GitHub: https://github.com/Azure/azure-service-operator
- ASO Docs: https://azure.github.io/azure-service-operator/
- Kubernetes Docs: https://kubernetes.io/docs/
- Azure Docs: https://learn.microsoft.com/azure/

## Example Workflows

### Deploy New Environment
```bash
# 1. Update values file
vim overlays/staging/kustomization.yaml

# 2. Preview changes
kubectl kustomize overlays/staging/

# 3. Apply
kubectl apply -k overlays/staging/

# 4. Verify
kubectl get all -l environment=staging
```

### Update Existing Resources
```bash
# 1. Edit manifest
vim storage.yaml

# 2. Apply changes
kubectl apply -f storage.yaml

# 3. Watch update
kubectl get storageaccount mysa -w
```

### Clean Up Environment
```bash
# Delete by label
kubectl delete all -l environment=dev

# Or delete by file
kubectl delete -k overlays/dev/

# Verify in Azure
az resource list -g my-dev-rg
```

## Getting Help

```bash
# ASO documentation
kubectl explain resourcegroup
kubectl explain storageaccount.spec

# General help
kubectl --help
helm --help
kustomize --help
```

---

Keep this cheat sheet handy for quick reference! 🚀
