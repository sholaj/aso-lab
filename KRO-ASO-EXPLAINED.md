# How KRO and ASO Work Together

A comprehensive guide to understanding the relationship between Kubernetes Resource Orchestrator (KRO) and Azure Service Operator (ASO).

## The Analogy

Think of building infrastructure like building houses:

| Concept | Analogy | Technical Equivalent |
|---------|---------|---------------------|
| **ASO** | Construction workers who know how to build with bricks, wood, concrete | Direct Azure resource provisioning via API |
| **KRO** | Architect who creates blueprints for "3-bedroom house", "office building" | Template engine for resource composition |
| **Developer** | Customer who says "I need a house" | Application team requesting infrastructure |

**Without KRO**: Customer tells workers exactly where to put every brick (tedious, error-prone)
**With KRO**: Customer picks a blueprint, architect generates detailed plans, workers execute

---

## The Technical Relationship

### Layer 1: ASO (The Execution Layer)

ASO is a **Kubernetes Operator** that:

1. **Installs Custom Resource Definitions (CRDs)** for Azure services
   ```bash
   kubectl get crds | grep azure.com
   # resourcegroups.resources.azure.com
   # storageaccounts.storage.azure.com
   # vaults.keyvault.azure.com
   # ... 200+ more
   ```

2. **Watches Kubernetes resources** and reconciles them with Azure
   ```
   User creates:           ASO sees:              ASO calls:
   StorageAccount CRD  →   Event in etcd     →    Azure Storage API
                                                   ↓
                                              Creates actual storage
   ```

3. **Manages the complete lifecycle**:
   - **Create**: Kubernetes apply → Azure resource created
   - **Update**: Kubernetes edit → Azure resource updated
   - **Delete**: Kubernetes delete → Azure resource deleted
   - **Drift**: Azure portal change → ASO reverts to Kubernetes state

**ASO's Superpower**: It makes Azure feel like native Kubernetes resources!

---

### Layer 2: KRO (The Composition Layer)

KRO is a **Meta-Operator** that:

1. **Defines new APIs** from existing Kubernetes resources
   ```yaml
   # You define a template
   apiVersion: kro.run/v1alpha1
   kind: ResourceGroup
   metadata:
     name: webapp-template
   spec:
     schema:
       kind: WebApp  # ← New custom API!
       spec:
         appName: string
         environment: string
   ```

2. **Generates multiple resources** from a single API call
   ```
   User creates:        KRO generates:         ASO executes:
   WebApp CRD      →    ResourceGroup     →    az group create
                        StorageAccount    →    az storage account create
                        KeyVault          →    az keyvault create
                        AppService        →    az webapp create
   ```

3. **Provides abstraction and governance**:
   - Hide Azure complexity from developers
   - Enforce naming conventions
   - Apply security policies
   - Ensure consistency

**KRO's Superpower**: It creates "platform APIs" from infrastructure building blocks!

---

## How They Complement Each Other

### The Delegation Pattern

```
                    ┌──────────────────┐
                    │   Application    │
                    │   Developer      │
                    └────────┬─────────┘
                             │
                             │ "I need a web app"
                             ▼
                    ┌──────────────────┐
                    │   KRO Template   │  ← Platform Team maintains
                    │   (WebApp API)   │
                    └────────┬─────────┘
                             │
                             │ Generates 5 resources
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
    ┌─────────┐        ┌─────────┐       ┌─────────┐
    │   ASO   │        │   ASO   │       │   ASO   │
    │Resource │        │Resource │       │Resource │
    │  (RG)   │        │ (Store) │       │  (KV)   │
    └────┬────┘        └────┬────┘       └────┬────┘
         │                  │                  │
         │ Azure API calls  │                  │
         ▼                  ▼                  ▼
    ┌─────────┐        ┌─────────┐       ┌─────────┐
    │  Azure  │        │  Azure  │       │  Azure  │
    │Resource │        │Resource │       │Resource │
    │  Group  │        │ Storage │       │Key Vault│
    └─────────┘        └─────────┘       └─────────┘
```

**Key Insight**:
- KRO doesn't know how to create Azure resources (that's ASO's job)
- ASO doesn't know how to compose resources into patterns (that's KRO's job)
- Together they create a **Platform as a Product**

---

## Concrete Example: The Journey of a Request

Let's trace what happens when a developer requests infrastructure:

### Step 1: Developer Creates Simple Request

```yaml
apiVersion: v1alpha1
kind: InfraComposition
metadata:
  name: myapp-prod
spec:
  projectName: myapp-prod
  location: northeurope
  tenantId: "16dd244e-243f-4809-a631-3e28e1f08d98"
  owner: shola
```

### Step 2: KRO Receives the Request

```
KRO Controller watches for InfraComposition resources
  ↓
Sees new resource: myapp-prod
  ↓
Looks up template: infra-composition-template
  ↓
Reads template definition with 4 resources
  ↓
Substitutes variables:
  {{ .spec.projectName }} → myapp-prod
  {{ .spec.location }} → northeurope
  {{ .spec.tenantId }} → 16dd244e...
  {{ .spec.owner }} → shola
```

### Step 3: KRO Generates ASO Resources

```yaml
# Generated Resource 1
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: rg-myapp-prod
  ownerReferences:
    - apiVersion: v1alpha1
      kind: InfraComposition
      name: myapp-prod
spec:
  location: northeurope
  tags:
    project: myapp-prod
    owner: shola
    managed-by: kro

---
# Generated Resource 2
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: stmyappprod001
  ownerReferences:
    - apiVersion: v1alpha1
      kind: InfraComposition
      name: myapp-prod
spec:
  location: northeurope
  owner:
    name: rg-myapp-prod  # ← Links to ResourceGroup
  kind: StorageV2
  sku:
    name: Standard_LRS

---
# Generated Resource 3 (Key Vault)
# Generated Resource 4 (Log Analytics)
# ... etc
```

### Step 4: ASO Takes Over

For **each generated resource**, ASO:

```
ASO Controller watches for StorageAccount resources
  ↓
Sees new resource: stmyappprod001
  ↓
Validates the spec against CRD schema
  ↓
Checks if resource exists in Azure (GET API call)
  ↓
Not found → Creates it (PUT API call):
  PUT https://management.azure.com/subscriptions/.../
      resourceGroups/rg-myapp-prod/providers/
      Microsoft.Storage/storageAccounts/stmyappprod001
  Body: {
    "location": "northeurope",
    "sku": {"name": "Standard_LRS"},
    "kind": "StorageV2",
    ...
  }
  ↓
Azure returns: "Provisioning in progress..."
  ↓
ASO polls Azure every 15s for status
  ↓
Azure returns: "Succeeded"
  ↓
ASO updates Kubernetes resource status:
  status:
    conditions:
      - type: Ready
        status: True
        reason: Succeeded
```

### Step 5: Status Flows Back

```
Azure Resource
  ↓ (polling)
ASO updates status
  ↓
StorageAccount.status.conditions = Ready
  ↓
KRO sees all child resources Ready
  ↓
InfraComposition.status.conditions = Ready
  ↓
Developer sees: kubectl get infracomposition myapp-prod
  NAME          READY   AGE
  myapp-prod    True    2m
```

---

## The Power of Owner References

KRO creates **owner references** linking everything together:

```
InfraComposition (myapp-prod)
  ├─ ResourceGroup (rg-myapp-prod)
  ├─ StorageAccount (stmyappprod001)
  │    └─ ownerRef: rg-myapp-prod
  ├─ KeyVault (kv-myapp-prod)
  │    └─ ownerRef: rg-myapp-prod
  └─ Workspace (law-myapp-prod)
       └─ ownerRef: rg-myapp-prod
```

**Magic Cleanup**:
```bash
kubectl delete infracomposition myapp-prod
```

Kubernetes **Garbage Collection** automatically:
1. Deletes all resources with `ownerRef: myapp-prod`
2. ASO sees the deletions
3. ASO deletes Azure resources
4. Everything is cleaned up!

---

## Benefits of KRO + ASO Together

### 1. **Developer Self-Service**

**Without KRO + ASO**:
```bash
# Developer needs to know Azure
az group create --name rg-myapp --location northeurope
az storage account create --name stmyapp --resource-group rg-myapp ...
az keyvault create --name kv-myapp --resource-group rg-myapp ...
# Then they need to manage state, track resources, handle dependencies...
```

**With KRO + ASO**:
```bash
# Developer uses simple API
kubectl apply -f myapp-infra.yaml
# Done! Everything is created and tracked.
```

### 2. **Platform Team Governance**

Platform team controls:
- Naming conventions (enforced in template)
- Security defaults (RBAC, encryption, etc.)
- Cost optimization (SKU sizes)
- Compliance (tags, policies)
- Network topology (subnets, NSGs)

Developers get:
- Fast provisioning
- No Azure expertise needed
- Consistent infrastructure
- GitOps workflow

### 3. **Infrastructure as Code 2.0**

Traditional IaC (Terraform, ARM):
- State files to manage
- Drift detection is separate
- No native Kubernetes integration
- Two systems to maintain

KRO + ASO:
- Kubernetes is the state (etcd)
- Drift detection built-in (ASO reconciles)
- Native Kubernetes resources
- Single control plane (kubectl)

### 4. **Reusability at Scale**

One template → Infinite instances:

```yaml
# Same template used for:
- Dev environment
- Test environment
- Staging environment
- Production environment
- DR environment
- 50 different app teams
```

### 5. **GitOps Native**

With Flux or Argo CD:

```
Git Repository
  ├── templates/
  │   └── infra-composition.yaml (maintained by platform team)
  ├── dev/
  │   └── myapp-infra.yaml (managed by dev team)
  ├── staging/
  │   └── myapp-infra.yaml
  └── prod/
      └── myapp-infra.yaml
```

Flux/Argo watches Git → applies to cluster → KRO generates → ASO creates → Azure resources

**Result**: Git is the single source of truth for all infrastructure!

---

## When to Use What

### Use ASO Alone When:
- Prototyping / learning
- One-off resources
- Maximum control over every detail
- Small team with Azure expertise

### Use KRO + ASO When:
- Platform engineering at scale
- Multiple teams/environments
- Need governance and standards
- Developer self-service required
- Enterprise environments (like UBS UK8s)

---

## Comparison with Alternatives

| Feature | ASO Alone | KRO + ASO | Terraform | Crossplane |
|---------|-----------|-----------|-----------|------------|
| Azure Native | ✅ | ✅ | ✅ | ❌ (multi-cloud) |
| Composition | ❌ | ✅ | ✅ (modules) | ✅ |
| Kubernetes Native | ✅ | ✅ | ❌ | ✅ |
| Drift Detection | ✅ | ✅ | ❌ (separate) | ✅ |
| Template Complexity | N/A | Simple | Complex | Complex |
| Learning Curve | Medium | Low (for users) | High | Very High |
| State Management | k8s etcd | k8s etcd | State files | k8s etcd |
| GitOps Ready | ✅ | ✅ | ⚠️ (requires wrapper) | ✅ |
| Azure API Coverage | 200+ resources | 200+ resources | Excellent | Good |

---

## Real-World Scaling Example

### Scenario: 100 App Teams at UBS

**Without KRO + ASO**:
- 100 teams × 3 environments = 300 sets of infrastructure
- Each set = ~10 Azure resources
- Total = 3,000 YAML files or Terraform modules to maintain
- Different patterns, inconsistent security, compliance nightmares

**With KRO + ASO**:
- Platform team: 5 templates (WebApp, API, DataPipeline, ML, Database)
- App teams: 300 simple instance files (1 per environment)
- Total maintenance: 5 templates + 300 instances
- Consistent security, governance, compliance built-in

**Reduction**: 3,000 files → 305 files (90% reduction!)

---

## Try It Yourself!

Run the demo script to see KRO + ASO in action:

```bash
./test-kro-aso-together.sh
```

This will:
1. Install a KRO template
2. Create one simple API request
3. Watch KRO generate 4 ASO resources
4. Watch ASO create 4 Azure resources
5. Show you the complete flow

---

## Key Takeaways

1. **ASO = Kubernetes ↔ Azure bridge** (execution)
2. **KRO = Template engine** (composition)
3. **Together = Platform Engineering** (abstraction + execution)
4. **Result = Developer Joy** (simple APIs, fast provisioning)

**The Formula**:
```
KRO (1 simple API)
  ↓
Generates N ASO resources
  ↓
Creates N Azure resources
  ↓
All managed as one unit
  ↓
GitOps + Drift Detection + Lifecycle Management = ❤️
```

---

## Next Steps

1. **Learn by doing**: Run `./test-kro-aso-together.sh`
2. **Create templates**: Build your own KRO templates for common patterns
3. **Scale up**: Deploy to production AKS cluster
4. **Add GitOps**: Integrate with Flux or Argo CD
5. **Iterate**: Gather feedback from developers, improve templates

**Remember**: Start simple, iterate, scale. The power of KRO + ASO grows with your platform maturity!
