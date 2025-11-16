# Phase 4: KRO Templates

This directory contains Kubernetes Resource Orchestrator (KRO) templates for composing Azure resources.

## What is KRO?

KRO allows you to:
- Create reusable templates for complex resource compositions
- Define parameters and default values
- Manage multiple related resources as a single unit
- Build internal platform abstractions

## Templates

### 1. Resource Group Template
**File**: `resourcegroup-template.yaml`

Simple template for creating resource groups with customizable names and locations.

### 2. Key Vault Template
**File**: `keyvault-template.yaml`

Template for Key Vault with configurable RBAC, SKU, and tenant ID.

### 3. Infrastructure Composition
**File**: `infra-composition.yaml`

**Most powerful template** - creates a complete infrastructure stack:
- Resource Group
- Storage Account
- Key Vault
- Log Analytics Workspace

All resources are properly linked with owner references and consistent tagging.

## Usage

### Deploy the Templates (ResourceDefinitions)

```bash
# Install all KRO templates
kubectl apply -f resourcegroup-template.yaml
kubectl apply -f keyvault-template.yaml
kubectl apply -f infra-composition.yaml

# Verify templates are registered
kubectl get resourcegroup
```

### Use the Templates

Create instances using your templates:

#### Example 1: Using Resource Group Template

```yaml
apiVersion: v1alpha1
kind: ResourceGroupTemplate
metadata:
  name: my-rg-instance
spec:
  name: rg-myapp-prod
  location: westeurope
  tags:
    environment: production
    team: platform
```

#### Example 2: Using Key Vault Template

```yaml
apiVersion: v1alpha1
kind: KeyVaultTemplate
metadata:
  name: my-kv-instance
spec:
  name: kv-myapp-prod
  resourceGroup: rg-myapp-prod
  tenantId: "YOUR_TENANT_ID"
  enableRbac: true
  sku: premium
```

#### Example 3: Using Infrastructure Composition

```yaml
apiVersion: v1alpha1
kind: InfraComposition
metadata:
  name: myapp-infra
spec:
  projectName: myapp
  location: northeurope
  tenantId: "YOUR_TENANT_ID"
  owner: shola
```

This single resource will create:
- `rg-myapp` (Resource Group)
- `stmyapp001` (Storage Account)
- `kv-myapp` (Key Vault)
- `law-myapp` (Log Analytics Workspace)

### Deploy an Instance

```bash
# Get your tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create instance YAML
cat > infra-instance.yaml <<EOF
apiVersion: v1alpha1
kind: InfraComposition
metadata:
  name: testapp-infra
  namespace: default
spec:
  projectName: testapp
  location: northeurope
  tenantId: "$TENANT_ID"
  owner: shola
EOF

# Apply it
kubectl apply -f infra-instance.yaml

# Watch all resources being created
kubectl get resourcegroup,storageaccount,vault,workspace -w
```

## Key Concepts

1. **Template Definition**: `ResourceGroup` kind defines the template schema
2. **Instance Creation**: Users create instances using the schema you defined
3. **Composition**: Single instance → multiple Azure resources
4. **Ownership**: Resources created by KRO are owned by the instance
5. **Lifecycle**: Deleting the instance deletes all composed resources

## Benefits Over Plain ASO

- **Consistency**: Same structure for all projects
- **Simplicity**: One YAML → many resources
- **Governance**: Enforce standards (naming, tagging, security)
- **Reusability**: Define once, use everywhere
- **Platform Engineering**: Build internal abstractions

## Advanced: Parameterized Deployments

```bash
# Create multiple environments from same template
for ENV in dev staging prod; do
  cat <<EOF | kubectl apply -f -
apiVersion: v1alpha1
kind: InfraComposition
metadata:
  name: myapp-$ENV
spec:
  projectName: myapp-$ENV
  location: northeurope
  tenantId: "$TENANT_ID"
  owner: shola
EOF
done
```

## Next Steps

- Create more specialized templates (AKS, databases, networking)
- Add validation and constraints
- Build a platform team self-service catalog
