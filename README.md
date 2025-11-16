# Azure Service Operator (ASO) Learning Lab

A comprehensive guide to learn and master Azure Service Operator (ASO) and Kubernetes Resource Operator (KRO) for building Azure infrastructure.

## Table of Contents
- [What is ASO?](#what-is-aso)
- [What is KRO?](#what-is-kro)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## What is ASO?

**Azure Service Operator (ASO)** is a Kubernetes operator that allows you to manage Azure resources using Kubernetes Custom Resource Definitions (CRDs). With ASO, you can:

- Define Azure resources using YAML manifests
- Manage Azure infrastructure alongside your Kubernetes applications
- Use GitOps workflows for infrastructure provisioning
- Leverage Kubernetes native tools (kubectl, Helm, Kustomize)
- Implement Infrastructure as Code (IaC) with Kubernetes declarative approach

### Key Benefits
- **Unified Management**: Manage both Azure resources and Kubernetes workloads in one place
- **GitOps Ready**: Store infrastructure definitions in Git and use GitOps tools
- **Declarative**: Define desired state and let ASO handle the rest
- **Kubernetes Native**: Use familiar Kubernetes tools and workflows

## What is KRO?

**Kubernetes Resource Operator (KRO)** is a pattern and sometimes refers to custom operators that manage Kubernetes resources. In the context of ASO:

- KRO patterns help organize and structure resource definitions
- Enables creation of higher-level abstractions over ASO resources
- Supports composition of multiple Azure resources into logical units
- Facilitates reusable infrastructure patterns

### KRO Patterns with ASO
1. **Resource Groups as Namespaces**: Map Azure Resource Groups to Kubernetes namespaces
2. **Composite Resources**: Combine multiple ASO resources into single deployable units
3. **Template-based Provisioning**: Use Helm/Kustomize to template common patterns
4. **Custom Controllers**: Build operators that orchestrate ASO resources

## Prerequisites

Before starting, ensure you have:

- **Kubernetes Cluster**: v1.20 or later (can be local like kind/minikube or AKS)
- **kubectl**: Kubernetes command-line tool
- **Azure Subscription**: Active Azure subscription with appropriate permissions
- **Azure CLI**: For authentication and resource verification
- **Helm** (optional): For easier installation

### Required Azure Permissions
- Contributor or Owner role on the subscription or resource group
- Ability to create service principals (for ASO authentication)

## Installation

### Step 1: Install ASO using Helm

```bash
# Add the ASO Helm repository
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts

# Update Helm repositories
helm repo update

# Install cert-manager (required by ASO)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
```

### Step 2: Create Azure Service Principal

```bash
# Set your subscription
az account set --subscription "<your-subscription-id>"

# Create service principal
az ad sp create-for-rbac -n "aso-lab-sp" --role contributor \
  --scopes /subscriptions/<your-subscription-id>

# Output will contain:
# - appId (CLIENT_ID)
# - password (CLIENT_SECRET)
# - tenant (TENANT_ID)
```

### Step 3: Configure ASO Credentials

```bash
# Create azureserviceoperator-system namespace
kubectl create namespace azureserviceoperator-system

# Create secret with Azure credentials
kubectl create secret generic aso-controller-settings \
  -n azureserviceoperator-system \
  --from-literal=AZURE_SUBSCRIPTION_ID="<your-subscription-id>" \
  --from-literal=AZURE_TENANT_ID="<your-tenant-id>" \
  --from-literal=AZURE_CLIENT_ID="<your-client-id>" \
  --from-literal=AZURE_CLIENT_SECRET="<your-client-secret>"
```

### Step 4: Install ASO Operator

```bash
# Install ASO with common CRDs
helm install aso2 aso2/azure-service-operator \
  --create-namespace \
  --namespace azureserviceoperator-system \
  --set crdPattern='resources.azure.com/*;containerservice.azure.com/*;keyvault.azure.com/*;managedidentity.azure.com/*;eventhub.azure.com/*;storage.azure.com/*'

# Verify installation
kubectl get pods -n azureserviceoperator-system
```

## Getting Started

### Basic Workflow

1. **Create a Resource Group** (Azure's container for resources)
2. **Define Azure Resources** (Storage Account, VNet, etc.)
3. **Apply manifests** using kubectl
4. **Verify in Azure** using Azure Portal or CLI

### Your First ASO Resource

Create a simple Resource Group:

```yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: aso-lab-rg
  namespace: default
spec:
  location: eastus
```

Apply it:
```bash
kubectl apply -f resourcegroup.yaml

# Check status
kubectl get resourcegroups
kubectl describe resourcegroup aso-lab-rg

# Verify in Azure
az group show -n aso-lab-rg
```

## Examples

Comprehensive examples are available in the `/examples` directory:

- **01-resource-group**: Basic resource group creation
- **02-storage-account**: Storage account with access keys
- **03-virtual-network**: VNet with subnets
- **04-aks-cluster**: Azure Kubernetes Service cluster
- **05-key-vault**: Key Vault with secrets
- **06-composite-patterns**: Multi-resource patterns using KRO concepts

## Best Practices

### 1. Resource Organization
- Use Kubernetes namespaces to organize resources by environment or project
- Map Azure Resource Groups to namespaces for clarity
- Use labels and annotations for resource tracking

### 2. Authentication & Security
- Use Managed Identity when running ASO on AKS
- Store credentials securely using Kubernetes secrets
- Follow principle of least privilege for service principals
- Rotate credentials regularly

### 3. Resource Naming
- Use consistent naming conventions
- Include environment/purpose in names
- Consider Azure naming restrictions (length, characters)

### 4. GitOps Integration
- Store all manifests in Git repositories
- Use tools like Flux or ArgoCD for automated deployment
- Implement PR-based workflows for infrastructure changes

### 5. Resource Dependencies
- Use `spec.owner` to establish parent-child relationships
- Leverage ASO's built-in dependency resolution
- Be aware of Azure resource provisioning times

### 6. Monitoring & Observability
- Monitor ASO operator logs
- Set up alerts for resource provisioning failures
- Use `kubectl describe` to check resource status

## Troubleshooting

### Common Issues

#### 1. Resource Not Provisioning
```bash
# Check resource status
kubectl describe <resource-type> <resource-name>

# Check ASO operator logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager

# Verify Azure credentials
kubectl get secret aso-controller-settings -n azureserviceoperator-system -o yaml
```

#### 2. Authentication Errors
- Verify service principal credentials
- Check subscription ID is correct
- Ensure service principal has appropriate permissions
- Verify tenant ID matches your Azure AD

#### 3. CRD Not Found
```bash
# List installed CRDs
kubectl get crds | grep azure.com

# Install missing CRDs by updating Helm installation
helm upgrade aso2 aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set crdPattern='resources.azure.com/*;...'
```

#### 4. Resource Stuck in Provisioning
- Check Azure Portal for resource status
- Review Azure Activity Log for errors
- Verify resource configuration meets Azure requirements
- Check for quota limitations

### Useful Commands

```bash
# Get all ASO resources
kubectl get resourcegroups,storageaccounts,virtualnetworks

# Watch resource creation
kubectl get resourcegroup aso-lab-rg -w

# Get detailed error information
kubectl describe resourcegroup aso-lab-rg | grep -A 10 "Events:"

# Delete Azure resource via ASO
kubectl delete resourcegroup aso-lab-rg
```

## Learning Path

1. **Beginner**: Start with resource groups and storage accounts
2. **Intermediate**: Explore networking (VNets, NSGs) and AKS
3. **Advanced**: Implement composite patterns, custom operators, and GitOps

## Resources

- [ASO GitHub Repository](https://github.com/Azure/azure-service-operator)
- [ASO Documentation](https://azure.github.io/azure-service-operator/)
- [Azure Resource Reference](https://learn.microsoft.com/en-us/azure/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

## Contributing

This is a learning lab. Feel free to:
- Add more examples
- Improve documentation
- Share your learning experiences
- Report issues or suggestions

## License

This project is for educational purposes.
