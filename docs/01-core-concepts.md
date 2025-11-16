# Azure Service Operator v2 Core Concepts

This guide covers the fundamental concepts you need to understand to work effectively with Azure Service Operator v2 (ASO v2).

## Table of Contents
- [What is ASO v2?](#what-is-aso-v2)
- [Custom Resource Definitions (CRDs)](#custom-resource-definitions-crds)
- [Reconciler Pattern](#reconciler-pattern)
- [API Versions](#api-versions)
- [Ownership Semantics](#ownership-semantics)

---

## What is ASO v2?

Azure Service Operator v2 (ASO v2) is a Kubernetes operator that enables you to manage Azure resources using Kubernetes Custom Resources. It bridges the gap between Kubernetes-native workflows and Azure resource management.

**Key Benefits:**
- ✅ Declarative Azure resource management
- ✅ GitOps-friendly workflows
- ✅ Consistent with Kubernetes patterns
- ✅ Infrastructure as Code using Kubernetes manifests
- ✅ Automatic reconciliation and state management

---

## Custom Resource Definitions (CRDs)

### What are CRDs?

CRDs extend the Kubernetes API to support custom resources. ASO v2 uses CRDs to represent Azure resources as Kubernetes objects.

### How ASO Uses CRDs

Each Azure resource type (Storage Account, Key Vault, AKS, etc.) has a corresponding CRD in ASO. These CRDs:

1. **Define the schema** for Azure resources
2. **Map Kubernetes YAML** to Azure ARM templates
3. **Enable kubectl operations** on Azure resources

### Example CRD Structure

```yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: my-resource-group
  namespace: default
spec:
  location: eastus
  tags:
    environment: dev
    project: aso-lab
```

### CRD Naming Convention

ASO v2 CRDs follow this pattern:
- **apiVersion**: `<service>.azure.com/<version>`
- **kind**: The Azure resource type (e.g., `StorageAccount`, `Vault`)

**Example:**
- Storage Account: `storage.azure.com/v1api20230101`
- Key Vault: `keyvault.azure.com/v1api20230701`

### Key CRD Features

1. **Spec**: Desired state of the Azure resource
2. **Status**: Current state and resource information
3. **Metadata**: Kubernetes-specific information (name, namespace, labels, annotations)

---

## Reconciler Pattern

### What is the Reconciler Pattern?

The reconciler pattern is a core Kubernetes concept where a controller continuously monitors resources and ensures the actual state matches the desired state.

### How ASO Implements Reconciliation

```
┌─────────────────────────────────────────────────┐
│  1. User creates/updates Kubernetes CR          │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  2. ASO Controller detects change                │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  3. Controller reads desired state (spec)        │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  4. Controller checks Azure for current state    │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  5. Controller reconciles differences            │
│     - Create new resources                       │
│     - Update existing resources                  │
│     - Delete removed resources                   │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  6. Controller updates CR status                 │
└─────────────────────────────────────────────────┘
```

### Reconciliation Loop

The ASO controller continuously:
1. **Watches** for changes to ASO Custom Resources
2. **Compares** the desired state (spec) with actual Azure state
3. **Reconciles** any differences by calling Azure APIs
4. **Updates** the status field with current information
5. **Retries** on failures with exponential backoff

### Observing Reconciliation

```bash
# Watch the status of a resource
kubectl get storageaccount my-storage -o yaml

# Check reconciliation events
kubectl describe storageaccount my-storage

# View ASO controller logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager
```

### Reconciliation States

- **Pending**: Resource creation/update is in progress
- **Ready**: Resource successfully reconciled and ready
- **Failed**: Reconciliation failed (check status.conditions for details)

---

## API Versions

### Understanding API Versions in ASO

ASO v2 supports multiple API versions for each Azure service, corresponding to different versions of the Azure Resource Manager (ARM) API.

### Version Format

```
<service>.azure.com/v1api<YYYYMMDD>
```

**Examples:**
- `storage.azure.com/v1api20230101` - Storage API from 2023-01-01
- `keyvault.azure.com/v1api20230701` - Key Vault API from 2023-07-01

### Why Multiple Versions?

1. **New Features**: Newer API versions support new Azure features
2. **Backward Compatibility**: Older versions remain supported
3. **Stability**: Choose stable versions for production
4. **Feature Adoption**: Adopt new features when needed

### Choosing the Right Version

```yaml
# Use latest stable version for new features
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
# ...

# Or use an older version for stability
apiVersion: storage.azure.com/v1api20210401
kind: StorageAccount
# ...
```

### Version Compatibility

- ASO v2 supports **multiple API versions simultaneously**
- You can **mix versions** in the same cluster
- Each CRD version has its own schema and features
- **Upgrade path**: Test with newer versions in dev, then promote to prod

### Finding Available Versions

```bash
# List all CRDs for a service
kubectl get crds | grep storage.azure.com

# View CRD details
kubectl get crd storageaccounts.storage.azure.com -o yaml
```

---

## Ownership Semantics

### What is Ownership?

Ownership defines the relationship between Kubernetes resources and controls lifecycle management, including garbage collection.

### ASO Ownership Model

ASO uses Kubernetes owner references to create parent-child relationships between resources.

```
ResourceGroup (Owner)
    │
    ├── StorageAccount (Owned)
    │   └── BlobService (Owned)
    │       └── Container (Owned)
    │
    └── KeyVault (Owned)
        └── Secret (Owned)
```

### Setting Up Ownership

```yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: my-rg
  namespace: default
spec:
  location: eastus
---
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorageacct
  namespace: default
spec:
  owner:
    name: my-rg  # References the ResourceGroup
  location: eastus
  kind: StorageV2
  sku:
    name: Standard_LRS
```

### Owner Reference Benefits

1. **Cascade Deletion**: Deleting the owner deletes all owned resources
2. **Lifecycle Management**: Owned resources follow owner's lifecycle
3. **Dependency Tracking**: Kubernetes tracks resource relationships
4. **Garbage Collection**: Automatic cleanup of orphaned resources

### Ownership Best Practices

✅ **DO:**
- Always use Resource Groups as top-level owners
- Create clear ownership hierarchies
- Use ownership for related resources

❌ **DON'T:**
- Create circular ownership (A owns B, B owns A)
- Change owners after creation (recreate instead)
- Mix ownership with manual Azure resource creation

### Cross-Namespace Ownership

ASO supports references across namespaces for multi-tenant scenarios:

```yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorageacct
  namespace: app-namespace
spec:
  owner:
    name: shared-rg
    # Owner is in different namespace
  location: eastus
  # ...
```

### Checking Ownership

```bash
# View owner references
kubectl get storageaccount mystorageacct -o jsonpath='{.metadata.ownerReferences}'

# Visualize resource hierarchy
kubectl tree storageaccount mystorageacct
```

---

## Summary

### Key Takeaways

1. **CRDs** extend Kubernetes to manage Azure resources
2. **Reconciler Pattern** ensures desired state matches actual state
3. **API Versions** provide flexibility and feature adoption
4. **Ownership** creates clear resource hierarchies and lifecycle management

### Next Steps

- Review [Prerequisites & Setup](./02-prerequisites.md)
- Explore [KRO Templates](../examples/kro-templates/)
- Deploy your first [Azure Service](../examples/azure-services/)

---

## Additional Resources

- [ASO v2 Documentation](https://azure.github.io/azure-service-operator/)
- [Kubernetes CRD Documentation](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Controller Pattern](https://kubernetes.io/docs/concepts/architecture/controller/)
- [Owner References](https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/)
