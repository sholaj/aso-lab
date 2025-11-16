# Phase 6: GitOps with Flux CD

Implement GitOps workflow for managing Azure infrastructure using Flux CD + ASO.

## What is GitOps?

GitOps is a paradigm where:
- **Git is the single source of truth** for infrastructure and applications
- **Declarative configurations** are stored in Git
- **Automated agents** (Flux) ensure cluster state matches Git
- **Changes via Git commits** (no manual kubectl apply)

## Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Git Repo  │─────▶│  Flux CD     │─────▶│  Kubernetes │
│  (Source)   │      │  (Operator)  │      │  Cluster    │
└─────────────┘      └──────────────┘      └─────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │   ASO/KRO    │
                     │  (Reconcile) │
                     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │    Azure     │
                     └──────────────┘
```

## Prerequisites

1. AKS cluster with ASO and KRO installed
2. Git repository (this repo!)
3. GitHub account (for bootstrap)
4. Flux CLI installed

## Installation

### Option 1: Quick Install (No Git Integration)

```bash
# Make script executable
chmod +x install-flux.sh

# Run installation
./install-flux.sh

# Verify
flux check
kubectl get pods -n flux-system
```

### Option 2: Bootstrap with GitHub (Recommended)

```bash
# Install Flux CLI
brew install fluxcd/tap/flux  # macOS
# or
curl -s https://fluxcd.io/install.sh | sudo bash  # Linux

# Export GitHub token
export GITHUB_TOKEN=<your-github-personal-access-token>

# Bootstrap Flux
flux bootstrap github \
  --owner=sholaj \
  --repository=aso-lab \
  --branch=main \
  --path=./flux/clusters/lab \
  --personal
```

This will:
- Install Flux on the cluster
- Create a deploy key in GitHub
- Commit Flux manifests to your repo
- Set up automatic reconciliation

## Configure Git Source

### 1. Update Git Repository URL

Edit `git-repository.yaml`:

```yaml
spec:
  url: https://github.com/sholaj/aso-lab
```

### 2. Apply Git Source

```bash
kubectl apply -f git-repository.yaml
```

### 3. Verify Source

```bash
flux get sources git
kubectl describe gitrepository aso-lab -n flux-system
```

## Deploy Infrastructure via GitOps

### 1. Apply Kustomizations

```bash
kubectl apply -f kustomization.yaml
```

### 2. Watch Flux Deploy Resources

```bash
# Watch Flux kustomizations
flux get kustomizations -w

# Watch ASO resources being created
kubectl get resourcegroup,storageaccount,vault -w
```

### 3. Check Reconciliation Status

```bash
# Get all Flux resources
flux get all

# Describe a specific kustomization
flux describe kustomization aso-infrastructure
```

## Making Changes via Git

### Workflow

1. **Edit manifests** in your local Git repo
2. **Commit and push** to GitHub
3. **Flux detects changes** (within 1 minute)
4. **Flux applies changes** to the cluster
5. **ASO reconciles** with Azure

### Example: Add a new storage account

```bash
# Create new manifest
cat > 03-storage/storageaccount-2.yaml <<EOF
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: stasoshola002
  namespace: default
spec:
  location: northeurope
  owner:
    name: rg-aso-workloads-shola
  kind: StorageV2
  sku:
    name: Standard_LRS
EOF

# Commit and push
git add 03-storage/storageaccount-2.yaml
git commit -m "Add second storage account"
git push

# Flux will detect and apply within 1 minute
# Watch it happen:
flux logs --follow
```

## Testing Drift Detection

Flux continuously ensures cluster state matches Git.

### Test 1: Manual Change (Drift)

```bash
# Manually delete a resource
kubectl delete storageaccount stasoshola001

# Watch Flux recreate it automatically
kubectl get storageaccount -w

# Check Flux logs
flux logs --kind=Kustomization --name=aso-storage
```

### Test 2: Force Reconciliation

```bash
# Trigger immediate reconciliation
flux reconcile kustomization aso-infrastructure --with-source

# Check status
flux get kustomizations
```

## Suspend/Resume Reconciliation

Temporarily stop Flux from applying changes:

```bash
# Suspend
flux suspend kustomization aso-infrastructure

# Make manual changes...

# Resume
flux resume kustomization aso-infrastructure
```

## Monitoring and Debugging

### View Flux Logs

```bash
# All Flux logs
flux logs --all-namespaces --follow

# Specific kustomization
flux logs --kind=Kustomization --name=aso-storage
```

### Check Resource Status

```bash
# Get all Flux resources
flux get all

# Get specific types
flux get sources git
flux get kustomizations
```

### Debug Failed Reconciliation

```bash
# Describe the kustomization
flux describe kustomization aso-infrastructure

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -n flux-system -l app=kustomize-controller --tail=50
```

## Benefits for UBS UK8s Migration

1. **Audit Trail**: All infrastructure changes in Git history
2. **Review Process**: Pull requests for infrastructure changes
3. **Rollback**: `git revert` to undo changes
4. **Consistency**: Same state across environments
5. **Disaster Recovery**: Rebuild entire infrastructure from Git
6. **Compliance**: Approved changes only (branch protection)

## Advanced: Multi-Environment Setup

```
flux/
  ├── base/                    # Shared resources
  │   ├── kro-templates/
  │   └── kustomization.yaml
  ├── environments/
  │   ├── dev/
  │   │   └── kustomization.yaml
  │   ├── staging/
  │   │   └── kustomization.yaml
  │   └── prod/
  │       └── kustomization.yaml
```

Each environment overlay customizes base resources with different:
- Resource sizes
- Replica counts
- Regions
- Security settings

## Security Best Practices

1. **Use Deploy Keys**: Flux uses read-only deploy key (auto-configured in bootstrap)
2. **RBAC**: Limit Flux service account permissions
3. **Secret Management**: Use Sealed Secrets or SOPS for sensitive data
4. **Branch Protection**: Require PR reviews for main branch
5. **Image Scanning**: Integrate with Azure Defender

## Cleanup

```bash
# Uninstall Flux (keeps CRDs and resources)
flux uninstall

# Delete everything including resources
flux uninstall --crds
```

## Next Steps

- Set up notifications (Slack, Teams, email)
- Implement Sealed Secrets for sensitive data
- Configure image automation for container updates
- Set up multi-tenancy with Flux multi-tenancy lockdown
