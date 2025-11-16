# KRO (Kubernetes Resource Operator) Patterns Guide

A comprehensive guide to understanding and mastering KRO patterns with Azure Service Operator.

## Table of Contents
- [What is KRO?](#what-is-kro)
- [Why Use KRO Patterns?](#why-use-kro-patterns)
- [Core Concepts](#core-concepts)
- [Pattern Categories](#pattern-categories)
- [Implementation Approaches](#implementation-approaches)
- [Best Practices](#best-practices)
- [Real-World Examples](#real-world-examples)

## What is KRO?

**KRO (Kubernetes Resource Operator)** refers to patterns and practices for:

1. **Composing Resources**: Combining multiple Kubernetes resources into logical units
2. **Abstracting Complexity**: Creating higher-level interfaces for complex infrastructure
3. **Enabling Reusability**: Building templates and patterns that can be reused
4. **Orchestrating Dependencies**: Managing resource relationships and creation order

In the context of ASO, KRO patterns help you:
- Group related Azure resources together
- Create reusable infrastructure templates
- Implement environment-specific configurations
- Build self-service platforms for development teams

## Why Use KRO Patterns?

### Without KRO Patterns
```bash
# Apply 10+ individual files
kubectl apply -f resourcegroup.yaml
kubectl apply -f vnet.yaml
kubectl apply -f subnet1.yaml
kubectl apply -f subnet2.yaml
kubectl apply -f nsg1.yaml
kubectl apply -f nsg2.yaml
kubectl apply -f storage.yaml
kubectl apply -f keyvault.yaml
# ... and so on
```

### With KRO Patterns
```bash
# Apply one composite file
kubectl apply -f web-application-stack.yaml

# Or use templating
kubectl apply -k overlays/production/

# Or use Helm
helm install myapp ./aso-stack -f values-prod.yaml
```

### Benefits
- ✅ **Reduced Complexity**: Manage fewer files
- ✅ **Better Organization**: Logical grouping of resources
- ✅ **Easier Maintenance**: Update one place, affect all
- ✅ **Environment Consistency**: Same pattern across dev/prod
- ✅ **Faster Deployment**: Apply multiple resources at once
- ✅ **GitOps Ready**: Single source of truth

## Core Concepts

### 1. Resource Composition

Combining multiple ASO resources into a single manifest:

```yaml
---
# Resource Group
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: app-rg
spec:
  location: eastus

---
# Virtual Network (depends on Resource Group)
apiVersion: network.azure.com/v1api20201101
kind: VirtualNetwork
metadata:
  name: app-vnet
spec:
  owner:
    name: app-rg  # References the ResourceGroup
  location: eastus
  addressSpace:
    addressPrefixes:
    - 10.0.0.0/16

---
# Storage Account (depends on Resource Group)
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: appstorageacct
spec:
  owner:
    name: app-rg  # References the ResourceGroup
  location: eastus
  kind: StorageV2
  sku:
    name: Standard_LRS
```

**Key Point**: Use `spec.owner` to establish parent-child relationships.

### 2. Resource Templating

Using tools to generate resource definitions:

#### Kustomize
```yaml
# base/kustomization.yaml
resources:
- resourcegroup.yaml
- vnet.yaml
- storage.yaml

# overlays/prod/kustomization.yaml
bases:
- ../../base
patches:
- path: production-patches.yaml
```

#### Helm
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

### 3. Parameterization

Making resources configurable:

```yaml
# ConfigMap with environment config
apiVersion: v1
kind: ConfigMap
metadata:
  name: azure-config
data:
  location: "eastus"
  environment: "production"
  sku: "Standard_GRS"
```

### 4. Dependency Management

ASO handles dependencies automatically through `spec.owner`:

```yaml
# Parent resource
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: parent-rg
spec:
  location: eastus

---
# Child resource - waits for parent
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: childsa
spec:
  owner:
    name: parent-rg  # ASO ensures parent exists first
```

## Pattern Categories

### 1. Basic Composition Pattern

**When to Use**: Small to medium deployments with few resources

**Structure**:
```
single-file.yaml
├── ResourceGroup
├── VirtualNetwork
├── StorageAccount
└── KeyVault
```

**Example**: See [three-tier-app.yaml](examples/06-composite-patterns/complete-stacks/three-tier-app.yaml)

### 2. Kustomize Pattern

**When to Use**: Multiple environments (dev/staging/prod) with shared base

**Structure**:
```
kustomize/
├── base/
│   ├── kustomization.yaml
│   ├── resourcegroup.yaml
│   ├── vnet.yaml
│   └── storage.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patches.yaml
    └── prod/
        ├── kustomization.yaml
        └── patches.yaml
```

**Advantages**:
- No templating (pure YAML)
- Git-friendly
- Built into kubectl
- Patch-based customization

**Example**: See [kustomize examples](examples/06-composite-patterns/kustomize/)

### 3. Helm Chart Pattern

**When to Use**: Complex parameterization, versioning, or package distribution

**Structure**:
```
helm-chart/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-prod.yaml
└── templates/
    ├── resourcegroup.yaml
    ├── vnet.yaml
    ├── storage.yaml
    └── keyvault.yaml
```

**Advantages**:
- Rich templating with Go templates
- Values files for configuration
- Release management
- Package distribution
- Rollback capability

**Example**: See [helm examples](examples/06-composite-patterns/helm/)

### 4. Custom Operator Pattern

**When to Use**: Complex orchestration logic, custom validation, or organization-wide platform

**Structure**:
```go
type AppStack struct {
    Name        string
    Environment string
    Region      string
    Size        string
}

func (r *Reconciler) Reconcile(ctx context.Context, req ctrl.Request) {
    // Read custom resource
    appStack := &AppStack{}
    r.Get(ctx, req.NamespacedName, appStack)
    
    // Generate and apply ASO resources
    rg := generateResourceGroup(appStack)
    vnet := generateVirtualNetwork(appStack)
    storage := generateStorageAccount(appStack)
    
    r.Create(ctx, rg)
    r.Create(ctx, vnet)
    r.Create(ctx, storage)
}
```

**Advantages**:
- Custom business logic
- Advanced validation
- Complex orchestration
- Custom status reporting
- Organization-specific abstractions

## Implementation Approaches

### Approach 1: Multi-Document YAML

**Best for**: Simple scenarios, learning, quick prototypes

```yaml
---
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
# ...

---
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
# ...
```

**Pros**: Simple, no tools needed
**Cons**: No parameterization, hard to maintain at scale

### Approach 2: Kustomize

**Best for**: Multiple environments, GitOps workflows

```bash
# Development
kubectl apply -k overlays/dev/

# Production
kubectl apply -k overlays/prod/
```

**Pros**: Pure YAML, kubectl built-in, Git-friendly
**Cons**: Limited templating, learning curve

### Approach 3: Helm

**Best for**: Complex configurations, versioned releases

```bash
helm install myapp ./chart \
  -f values-prod.yaml \
  --set location=westus
```

**Pros**: Rich templating, version control, rollback
**Cons**: Go template syntax, more complex

### Approach 4: Custom CRDs + Operator

**Best for**: Platform engineering, large organizations

```yaml
apiVersion: platform.company.com/v1
kind: WebApplication
metadata:
  name: myapp
spec:
  environment: production
  region: eastus
  size: medium
  highAvailability: true
```

**Pros**: Custom abstractions, full control, validation
**Cons**: Development overhead, maintenance burden

## Best Practices

### 1. Start Simple, Evolve

```
Phase 1: Single YAML file
  ↓
Phase 2: Add Kustomize for environments
  ↓
Phase 3: Add Helm for complex parameterization
  ↓
Phase 4: Build custom operator (if needed)
```

### 2. Use Consistent Naming

```yaml
# Pattern: {project}-{environment}-{resource-type}
resourceGroup: myapp-prod-rg
vnet: myapp-prod-vnet
storage: myappprodsa  # Storage names have restrictions
keyVault: myapp-prod-kv
```

### 3. Tag Everything

```yaml
tags:
  Project: myapp
  Environment: production
  ManagedBy: ASO
  Owner: platform-team
  CostCenter: engineering
  Stack: web-application
```

### 4. Document Dependencies

```yaml
# This resource depends on:
# - ResourceGroup: myapp-rg
# - VirtualNetwork: myapp-vnet (for subnet reference)
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
```

### 5. Use Labels for Querying

```yaml
metadata:
  labels:
    stack: web-application
    tier: storage
    environment: production
```

Query:
```bash
kubectl get all -l stack=web-application
kubectl get all -l tier=storage,environment=production
```

### 6. Version Your Patterns

```yaml
# Chart.yaml or git tags
version: 1.2.3

# In manifests
metadata:
  annotations:
    pattern-version: "1.2.3"
    last-updated: "2024-01-15"
```

### 7. Test Before Production

```bash
# Dry run
kubectl apply -f stack.yaml --dry-run=client

# Apply to dev first
kubectl apply -k overlays/dev/

# After validation, promote to prod
kubectl apply -k overlays/prod/
```

### 8. Monitor Resource Status

```bash
# Check all resources in stack
kubectl get -l stack=myapp --all-namespaces

# Watch for Ready status
kubectl wait --for=condition=Ready --timeout=600s -l stack=myapp

# Check for failures
kubectl get all -o json | \
  jq '.items[] | select(.status.conditions[]? | select(.status=="False"))'
```

## Real-World Examples

### Example 1: Microservices Platform

**Goal**: Standard infrastructure for each microservice

**Resources**:
- Resource Group
- Virtual Network with service subnet
- Storage Account for logs
- Key Vault for secrets
- Service Bus namespace
- Application Insights

**Implementation**: Helm chart with service name as parameter

```bash
helm install payment-service ./microservice-stack \
  --set serviceName=payment \
  --set environment=prod
```

### Example 2: Data Processing Pipeline

**Goal**: Repeatable data pipeline infrastructure

**Resources**:
- Resource Group
- Storage Account (data lake)
- Event Hub for streaming
- Azure Functions for processing
- Cosmos DB for results
- Log Analytics workspace

**Implementation**: Kustomize with pipeline-specific overlays

### Example 3: Multi-Region Application

**Goal**: Same stack deployed to multiple regions

**Resources**:
- Regional resource groups
- Regional VNets with peering
- Regional storage accounts
- Global Key Vault
- Traffic Manager for routing

**Implementation**: Helm with region loop or custom operator

```bash
for region in eastus westus westeurope; do
  helm install myapp-$region ./app-stack \
    --set region=$region \
    --set globalPrefix=myapp
done
```

## Learning Path

### Level 1: Beginner
- ✅ Create multi-resource YAML files
- ✅ Use `spec.owner` for dependencies
- ✅ Apply labels for organization

### Level 2: Intermediate
- ✅ Implement Kustomize base + overlays
- ✅ Create environment-specific configurations
- ✅ Use ConfigMaps for parameterization

### Level 3: Advanced
- ✅ Build Helm charts with complex templates
- ✅ Implement GitOps workflows
- ✅ Create reusable pattern libraries

### Level 4: Expert
- ✅ Develop custom operators
- ✅ Build platform engineering solutions
- ✅ Implement advanced orchestration

## Resources

- [ASO Documentation](https://azure.github.io/azure-service-operator/)
- [Kustomize Book](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)
- [Helm Documentation](https://helm.sh/docs/)
- [Operator SDK](https://sdk.operatorframework.io/)
- [GitOps with Flux](https://fluxcd.io/)
- [GitOps with ArgoCD](https://argo-cd.readthedocs.io/)

## Next Steps

1. **Practice**: Work through all examples in this repository
2. **Build**: Create patterns for your organization's needs
3. **Share**: Contribute patterns back to the community
4. **Scale**: Implement GitOps for production deployments

---

Happy building with KRO patterns! 🚀
