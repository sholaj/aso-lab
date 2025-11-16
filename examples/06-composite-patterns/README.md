# Example 06: Composite Patterns with KRO

## Overview
This example demonstrates Kubernetes Resource Operator (KRO) patterns for composing multiple ASO resources into reusable infrastructure templates.

## What You'll Learn
- Creating composite resource patterns
- Using Kustomize for resource templating
- Helm charts for ASO resources
- Building reusable infrastructure modules
- Implementing GitOps-ready patterns

## KRO Patterns Explained

KRO (Kubernetes Resource Operator) patterns help you:
1. **Compose** multiple resources into logical units
2. **Templatize** infrastructure for reusability
3. **Parameterize** configurations for different environments
4. **Orchestrate** complex resource dependencies

## Patterns in This Example

### Pattern 1: Three-Tier Application Stack
Complete infrastructure for a web application:
- Resource Group
- Virtual Network with subnets
- Storage Account
- Key Vault for secrets
- Application Insights

### Pattern 2: AKS Landing Zone
Production-ready AKS environment:
- Networking infrastructure
- AKS cluster with proper configuration
- Container registry
- Log Analytics workspace
- Managed identities

### Pattern 3: Database Environment
Secure database setup:
- Dedicated subnet
- Azure SQL Database
- Private endpoint
- Key Vault for credentials

## Directory Structure

```
06-composite-patterns/
├── README.md
├── kustomize/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── resourcegroup.yaml
│   │   ├── vnet.yaml
│   │   └── storage.yaml
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   └── patches.yaml
│       └── prod/
│           ├── kustomization.yaml
│           └── patches.yaml
├── helm/
│   └── aso-app-stack/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-prod.yaml
│       └── templates/
│           ├── resourcegroup.yaml
│           ├── vnet.yaml
│           ├── storage.yaml
│           └── keyvault.yaml
└── complete-stacks/
    ├── three-tier-app.yaml
    ├── aks-landing-zone.yaml
    └── database-environment.yaml
```

## Using Kustomize

### Base Configuration

Create reusable base resources:

```bash
# Apply base configuration
kubectl apply -k kustomize/base/

# Apply dev overlay
kubectl apply -k kustomize/overlays/dev/

# Apply prod overlay
kubectl apply -k kustomize/overlays/prod/
```

### Advantages of Kustomize
- No templates, pure YAML
- Git-friendly (diff, merge, review)
- Built into kubectl
- Environment-specific overlays
- Patch-based customization

## Using Helm

### Install Stack with Helm

```bash
# Install for development
helm install my-app-dev ./helm/aso-app-stack \
  -f ./helm/aso-app-stack/values-dev.yaml

# Install for production
helm install my-app-prod ./helm/aso-app-stack \
  -f ./helm/aso-app-stack/values-prod.yaml

# Upgrade
helm upgrade my-app-dev ./helm/aso-app-stack \
  -f ./helm/aso-app-stack/values-dev.yaml

# Uninstall
helm uninstall my-app-dev
```

### Advantages of Helm
- Rich templating with Go templates
- Values files for configuration
- Release management
- Rollback capability
- Package distribution

## Complete Stack Examples

### Three-Tier Application

```bash
# Deploy complete stack
kubectl apply -f complete-stacks/three-tier-app.yaml

# Monitor resources
kubectl get resourcegroups,virtualnetworks,storageaccounts,vaults

# Wait for all resources
kubectl wait --for=condition=Ready --timeout=600s -f complete-stacks/three-tier-app.yaml
```

This creates:
- Resource Group
- Virtual Network with 3 subnets (web, app, data)
- Storage Account for application data
- Key Vault for secrets
- Network Security Groups

### AKS Landing Zone

```bash
# Deploy AKS landing zone
kubectl apply -f complete-stacks/aks-landing-zone.yaml

# This takes 15-20 minutes
kubectl get managedcluster aks-landing-zone -w
```

This creates:
- Hub-spoke network topology
- AKS cluster with system and user node pools
- Azure Container Registry
- Log Analytics workspace
- Monitoring configuration
- Managed identities with proper RBAC

## Building Your Own Patterns

### Step 1: Identify Common Patterns

Look for infrastructure you deploy repeatedly:
- Web application stack
- Microservices environment
- Data processing pipeline
- Machine learning workspace

### Step 2: Extract Resources

List all ASO resources needed:
```yaml
resources:
  - ResourceGroup
  - VirtualNetwork
  - StorageAccount
  - ...
```

### Step 3: Define Dependencies

Map dependencies using `spec.owner`:
```yaml
spec:
  owner:
    name: parent-resource
```

### Step 4: Parameterize

Identify what should be configurable:
- Environment (dev/prod)
- Region
- Size/SKU
- Naming convention

### Step 5: Choose Tool

- **Simple**: Multi-resource YAML file
- **Environment variants**: Kustomize
- **Complex templating**: Helm
- **Custom logic**: Operator/Controller

## Best Practices for Composite Patterns

### 1. Naming Conventions
```yaml
# Use consistent naming
resourceGroup: "${project}-${env}-rg"
storageAccount: "${project}${env}sa"
keyVault: "${project}-${env}-kv"
```

### 2. Tagging Strategy
```yaml
tags:
  Environment: "${env}"
  Project: "${project}"
  ManagedBy: "ASO"
  Owner: "${team}"
  CostCenter: "${cost_center}"
```

### 3. Resource Organization
- Group related resources
- Use namespaces for isolation
- Maintain clear ownership hierarchy

### 4. Configuration Management
- Separate base from environment-specific config
- Use GitOps for deployment
- Version your patterns
- Document parameters

### 5. Testing Strategy
```bash
# Dry-run before apply
kubectl apply -f stack.yaml --dry-run=client

# Validate with kubeval or similar
kubeval stack.yaml

# Test in dev before prod
```

## GitOps Integration

### With Flux

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: aso-infrastructure
  namespace: flux-system
spec:
  interval: 10m
  path: ./infrastructure/overlays/prod
  prune: true
  sourceRef:
    kind: GitRepository
    name: infrastructure
```

### With ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aso-infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/infrastructure
    targetRevision: main
    path: infrastructure/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Advanced KRO Patterns

### Custom Operator

Build a custom operator that generates ASO resources:

```go
// Pseudocode for custom operator
func (r *AppStackReconciler) Reconcile(req ctrl.Request) {
  // Read custom AppStack resource
  appStack := &v1.AppStack{}
  
  // Generate ASO resources
  resourceGroup := generateResourceGroup(appStack)
  vnet := generateVNet(appStack)
  storage := generateStorage(appStack)
  
  // Apply ASO resources
  client.Create(resourceGroup)
  client.Create(vnet)
  client.Create(storage)
}
```

### Crossplane Composition

Use Crossplane for higher-level abstractions:

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: webapp-stack
spec:
  compositeTypeRef:
    apiVersion: example.com/v1alpha1
    kind: WebApp
  resources:
  - base:
      apiVersion: resources.azure.com/v1api20200601
      kind: ResourceGroup
  - base:
      apiVersion: storage.azure.com/v1api20230101
      kind: StorageAccount
```

## Real-World Example: Multi-Region Deployment

Deploy the same stack in multiple regions:

```bash
# Using Kustomize with region overlays
for region in eastus westus westeurope; do
  kustomize build overlays/$region | kubectl apply -f -
done

# Using Helm
for region in eastus westus westeurope; do
  helm install myapp-$region ./helm/aso-app-stack \
    --set region=$region \
    --set namePrefix=myapp-$region
done
```

## Monitoring and Observability

Track your composite stacks:

```bash
# Get all resources in a stack
kubectl get all -l stack=three-tier-app

# Check status of all resources
kubectl get resourcegroups,vaults,storageaccounts -l stack=three-tier-app

# Describe failed resources
kubectl get all -o json | jq '.items[] | select(.status.conditions[].status=="False")'
```

## Cost Management

Tag resources for cost tracking:

```yaml
tags:
  CostCenter: "Engineering"
  Project: "WebApp"
  Environment: "Production"
  Stack: "three-tier-app"
```

Query costs by tags:
```bash
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --query "[?tags.Stack=='three-tier-app']"
```

## Clean Up

```bash
# Delete complete stack
kubectl delete -f complete-stacks/three-tier-app.yaml

# Delete Kustomize overlay
kubectl delete -k kustomize/overlays/dev/

# Delete Helm release
helm uninstall my-app-dev
```

## Next Steps
- Build your own composite patterns
- Implement GitOps workflow
- Create organization-specific templates
- Develop custom operators for complex scenarios
- Integrate with CI/CD pipelines

## Resources
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Crossplane](https://www.crossplane.io/)
- [Flux GitOps](https://fluxcd.io/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
