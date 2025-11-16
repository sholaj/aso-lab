# Architecture & Concepts

Visual guide to understanding ASO and KRO architecture and concepts.

## ASO Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Your Applications & Workloads                     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Azure Service Operator (ASO)                      │    │
│  │  ┌──────────────┐  ┌──────────────┐               │    │
│  │  │ Controller   │  │  CRDs        │               │    │
│  │  │ Manager      │  │  - RG        │               │    │
│  │  │              │  │  - Storage   │               │    │
│  │  │ Reconciles   │  │  - VNet      │               │    │
│  │  │ Resources    │  │  - AKS       │               │    │
│  │  │              │  │  - KeyVault  │               │    │
│  │  └──────────────┘  └──────────────┘               │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↕                                   │
│                   Kubernetes API                            │
│                          ↕                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │  kubectl apply -f resourcegroup.yaml               │    │
│  └────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
                           ↕
                    Azure ARM API
                           ↕
┌─────────────────────────────────────────────────────────────┐
│                      Azure Cloud                            │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Resource │  │ Storage  │  │ Virtual  │  │   AKS    │  │
│  │  Groups  │  │ Accounts │  │ Networks │  │ Clusters │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │   Key    │  │   SQL    │  │  Event   │  │   ...    │  │
│  │  Vault   │  │ Database │  │   Hubs   │  │          │  │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## How ASO Works

### 1. You Define Infrastructure in Kubernetes

```yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: my-app-rg
spec:
  location: eastus
```

### 2. ASO Watches for Changes

```
Kubernetes API Server
       ↓
   ASO Controller detects new ResourceGroup
       ↓
   Reconciliation Loop starts
```

### 3. ASO Creates Azure Resources

```
ASO Controller
       ↓
   Calls Azure ARM API
       ↓
   Creates Resource Group in Azure
       ↓
   Updates Kubernetes object status
```

### 4. Status Sync

```yaml
# ASO updates the Kubernetes object with Azure status
status:
  conditions:
  - type: Ready
    status: "True"
    reason: Succeeded
  id: /subscriptions/.../resourceGroups/my-app-rg
```

## KRO Pattern Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: Platform Abstractions (Custom Operators)          │
│  ┌────────────────────────────────────────────────────┐    │
│  │ apiVersion: platform.company.com/v1                │    │
│  │ kind: WebApplication                               │    │
│  │ spec:                                              │    │
│  │   name: myapp                                      │    │
│  │   environment: production                          │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Templated Patterns (Helm/Kustomize)              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ helm install myapp ./aso-stack                     │    │
│  │   --set environment=prod                           │    │
│  │   --set region=eastus                              │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Composite Resources (Multi-resource YAML)         │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ---                                                │    │
│  │ ResourceGroup                                      │    │
│  │ ---                                                │    │
│  │ VirtualNetwork                                     │    │
│  │ ---                                                │    │
│  │ StorageAccount                                     │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Individual ASO Resources                          │
│  ┌────────────────────────────────────────────────────┐    │
│  │ apiVersion: resources.azure.com/v1api20200601      │    │
│  │ kind: ResourceGroup                                │    │
│  │ spec:                                              │    │
│  │   location: eastus                                 │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Resource Relationship Patterns

### Parent-Child Relationship

```
┌──────────────────┐
│ ResourceGroup    │  ← Parent (Owner)
└────────┬─────────┘
         │ spec.owner references
         ├─────────────────────┬─────────────────────┐
         ↓                     ↓                     ↓
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ VirtualNetwork  │  │ StorageAccount  │  │   KeyVault      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                                          
         │ spec.owner references                   
         ↓                                          
┌─────────────────┐                                
│    Subnet       │  ← Child of VirtualNetwork    
└─────────────────┘                                
```

### Example YAML

```yaml
# Parent
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: parent-rg

---
# Child - references parent
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: childsa
spec:
  owner:
    name: parent-rg  # ← Creates dependency
```

## Three-Tier Application Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Cloud                             │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Resource Group: three-tier-app-rg                 │    │
│  │                                                     │    │
│  │  ┌──────────────────────────────────────────────┐ │    │
│  │  │  Virtual Network: 10.100.0.0/16              │ │    │
│  │  │                                               │ │    │
│  │  │  ┌─────────────────────────────────────┐    │ │    │
│  │  │  │  Web Tier Subnet: 10.100.1.0/24     │    │ │    │
│  │  │  │  ┌────────┐  ┌────────┐             │    │ │    │
│  │  │  │  │  VM    │  │  NSG   │             │    │ │    │
│  │  │  │  └────────┘  └────────┘             │    │ │    │
│  │  │  └─────────────────────────────────────┘    │ │    │
│  │  │                                               │ │    │
│  │  │  ┌─────────────────────────────────────┐    │ │    │
│  │  │  │  App Tier Subnet: 10.100.2.0/24     │    │ │    │
│  │  │  │  ┌────────┐  ┌────────┐             │    │ │    │
│  │  │  │  │  VM    │  │  NSG   │             │    │ │    │
│  │  │  │  └────────┘  └────────┘             │    │ │    │
│  │  │  └─────────────────────────────────────┘    │ │    │
│  │  │                                               │ │    │
│  │  │  ┌─────────────────────────────────────┐    │ │    │
│  │  │  │  Data Tier Subnet: 10.100.3.0/24    │    │ │    │
│  │  │  │  ┌────────┐  ┌────────┐             │    │ │    │
│  │  │  │  │  DB    │  │  NSG   │             │    │ │    │
│  │  │  │  └────────┘  └────────┘             │    │ │    │
│  │  │  └─────────────────────────────────────┘    │ │    │
│  │  └──────────────────────────────────────────────┘ │    │
│  │                                                     │    │
│  │  ┌──────────┐  ┌──────────┐                       │    │
│  │  │ Storage  │  │   Key    │                       │    │
│  │  │ Account  │  │  Vault   │                       │    │
│  │  └──────────┘  └──────────┘                       │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## AKS Landing Zone Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Subscription                       │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Resource Group: aks-landing-zone-rg               │    │
│  │                                                     │    │
│  │  ┌──────────────────────────────────────────────┐ │    │
│  │  │  VNet: 10.200.0.0/16                         │ │    │
│  │  │                                               │ │    │
│  │  │  ┌─────────────────────────────────────┐    │ │    │
│  │  │  │  AKS System Subnet                  │    │ │    │
│  │  │  │  10.200.0.0/22                      │    │ │    │
│  │  │  │  ┌──────────────────────────┐       │    │ │    │
│  │  │  │  │  AKS Cluster             │       │    │ │    │
│  │  │  │  │  - System Node Pool      │       │    │ │    │
│  │  │  │  │  - 3 nodes (HA)          │       │    │ │    │
│  │  │  │  └──────────────────────────┘       │    │ │    │
│  │  │  └─────────────────────────────────────┘    │ │    │
│  │  │                                               │ │    │
│  │  │  ┌─────────────────────────────────────┐    │ │    │
│  │  │  │  Workload Subnet                    │    │ │    │
│  │  │  │  10.200.4.0/22                      │    │ │    │
│  │  │  └─────────────────────────────────────┘    │ │    │
│  │  │                                               │ │    │
│  │  │  ┌─────────────────────────────────────┐    │ │    │
│  │  │  │  Private Endpoint Subnet            │    │ │    │
│  │  │  │  10.200.9.0/24                      │    │ │    │
│  │  │  └─────────────────────────────────────┘    │ │    │
│  │  └──────────────────────────────────────────────┘ │    │
│  │                                                     │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐        │    │
│  │  │  Key     │  │ Storage  │  │ Managed  │        │    │
│  │  │  Vault   │  │ Account  │  │ Identity │        │    │
│  │  └──────────┘  └──────────┘  └──────────┘        │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Development Workflow

### Traditional Approach

```
Developer → Azure Portal → Click, Click, Click → Resources Created
                                                         ↓
                                              No Version Control
                                              No Reproducibility
                                              Manual Process
```

### ASO + KRO Approach

```
Developer → Write YAML → Git Commit → Git Push
                                          ↓
                                     GitOps Tool
                                     (Flux/ArgoCD)
                                          ↓
                                   kubectl apply
                                          ↓
                                    ASO Controller
                                          ↓
                                   Azure Resources
                                          
Benefits:
✓ Version Controlled
✓ Code Reviewed
✓ Reproducible
✓ Automated
✓ Auditable
```

## Environment Progression

### Using Kustomize

```
┌──────────────┐
│  base/       │  ← Common resources
│  - rg.yaml   │
│  - vnet.yaml │
│  - sa.yaml   │
└──────┬───────┘
       │
       ├──────────────────┬──────────────────┐
       ↓                  ↓                  ↓
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ overlays/dev │   │overlays/stage│   │overlays/prod │
│ - patches    │   │ - patches    │   │ - patches    │
│ - dev config │   │ - stage cfg  │   │ - prod cfg   │
└──────────────┘   └──────────────┘   └──────────────┘
       ↓                  ↓                  ↓
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Dev Azure   │   │ Stage Azure  │   │  Prod Azure  │
│  Resources   │   │  Resources   │   │  Resources   │
└──────────────┘   └──────────────┘   └──────────────┘
```

## Secret Management Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Key Vault                           │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Secrets:                                          │    │
│  │  - db-connection-string                            │    │
│  │  - api-keys                                        │    │
│  │  - certificates                                    │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           ↓
                    CSI Secret Driver
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                          │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Pod Volume Mount:                                 │    │
│  │  /mnt/secrets/db-connection-string                 │    │
│  │                                                     │    │
│  │  Environment Variable:                             │    │
│  │  DB_CONN=$(<secret-mount)                          │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## GitOps Architecture

```
┌────────────────┐
│   Git Repo     │
│  (Source of    │
│    Truth)      │
└────────┬───────┘
         │
         │ Git Push
         ↓
┌────────────────┐
│  GitHub/GitLab │
└────────┬───────┘
         │
         │ Webhook/Poll
         ↓
┌────────────────┐       ┌─────────────────┐
│  Flux/ArgoCD   │  ───→ │   Kubernetes    │
│  (GitOps Tool) │       │   API Server    │
└────────────────┘       └────────┬────────┘
                                  │
                                  ↓
                         ┌────────────────┐
                         │  ASO Controller│
                         └────────┬───────┘
                                  │
                                  ↓
                         ┌────────────────┐
                         │  Azure Cloud   │
                         │   Resources    │
                         └────────────────┘
```

## Learning Progression Path

```
Week 1: Fundamentals
├── Install ASO
├── Create Resource Group
├── Create Storage Account
└── Understand basic concepts

Week 2: Networking & Compute
├── Create Virtual Networks
├── Configure Subnets
├── Deploy AKS cluster
└── Manage identities

Week 3: Security & Data
├── Set up Key Vault
├── Manage secrets
├── Configure access policies
└── Implement private endpoints

Week 4: Patterns & Automation
├── Build composite resources
├── Learn Kustomize
├── Create Helm charts
└── Implement GitOps

Beyond: Advanced Topics
├── Custom operators
├── Multi-region deployments
├── Disaster recovery
└── Platform engineering
```

## Summary

- **ASO**: Manages Azure resources from Kubernetes
- **KRO Patterns**: Organize and template infrastructure
- **Composition**: Combine resources into logical units
- **Templating**: Kustomize/Helm for parameterization
- **GitOps**: Automated deployment from Git
- **Best Practices**: Start simple, evolve as needed

This architecture enables Infrastructure as Code with Kubernetes-native tools, bringing DevOps best practices to Azure infrastructure management.
