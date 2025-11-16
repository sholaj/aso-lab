# Flux CD + ASO Integration

This directory contains examples for using Flux CD with Azure Service Operator v2 for GitOps workflows.

## What is Flux?

Flux is a GitOps tool that automatically ensures your Kubernetes cluster matches the configuration defined in Git. When combined with ASO, it enables GitOps-based Azure resource management.

## Benefits of Flux + ASO

- ✅ **Declarative Infrastructure**: Define Azure resources in Git
- ✅ **Automatic Reconciliation**: Flux keeps cluster in sync with Git
- ✅ **Version Control**: Track all infrastructure changes
- ✅ **Pull-based Deployment**: Secure, cluster-initiated deployments
- ✅ **Multi-Environment**: Manage dev/staging/prod from Git

## Quick Start

### Install Flux

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installation
flux --version

# Bootstrap Flux in your cluster
export GITHUB_TOKEN=<your-github-token>
export GITHUB_USER=<your-github-username>
export GITHUB_REPO=<your-repo-name>

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/my-cluster \
  --personal
```

### Setup ASO with Flux

```bash
# Create namespace
kubectl create namespace azureserviceoperator-system

# Create ASO credentials secret
kubectl create secret generic aso-credential \
  --namespace azureserviceoperator-system \
  --from-literal=AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
  --from-literal=AZURE_TENANT_ID=$AZURE_TENANT_ID \
  --from-literal=AZURE_CLIENT_ID=$AZURE_CLIENT_ID \
  --from-literal=AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET

# Deploy examples
kubectl apply -f 01-flux-setup.yaml
```

## Directory Structure

```
examples/gitops/flux/
├── README.md                          # This file
├── 01-flux-setup.yaml                 # Flux sources and HelmRelease for ASO
├── 02-gitrepository-source.yaml       # Git repository source configuration
├── 03-kustomization-infrastructure.yaml  # Infrastructure Kustomization
└── infrastructure/
    ├── kustomization.yaml             # Kustomization for all infra
    ├── resource-groups.yaml           # Resource groups
    ├── storage.yaml                   # Storage accounts
    └── keyvault.yaml                  # Key Vaults
```

## Flux Concepts

### Sources

Sources define where Flux reads manifests from:
- **GitRepository**: Git repositories
- **HelmRepository**: Helm chart repositories
- **Bucket**: S3-compatible storage

### Kustomizations

Kustomizations define how Flux applies resources:
- Dependencies between resources
- Health checks
- Retry logic
- Pruning old resources

### HelmReleases

HelmReleases manage Helm chart deployments:
- Chart version
- Values overrides
- Automated upgrades

## Example Workflows

### Workflow 1: Single Environment

```
Git Repository (main branch)
    └── clusters/my-cluster/
        ├── flux-system/          # Flux controllers
        └── infrastructure/        # ASO resources
            ├── resource-groups.yaml
            ├── storage.yaml
            └── keyvault.yaml
```

### Workflow 2: Multi-Environment

```
Git Repository
    ├── base/                      # Shared base configs
    │   ├── resource-groups/
    │   ├── storage/
    │   └── keyvault/
    └── overlays/
        ├── dev/                   # Dev-specific configs
        ├── staging/               # Staging configs
        └── production/            # Production configs
```

### Workflow 3: Multi-Tenant

```
Git Repository
    ├── tenants/
    │   ├── tenant-a/
    │   │   ├── resource-groups.yaml
    │   │   └── storage.yaml
    │   └── tenant-b/
    │       ├── resource-groups.yaml
    │       └── keyvault.yaml
    └── shared/
        └── log-analytics.yaml
```

## Monitoring Flux

```bash
# Check Flux controllers
flux get sources git
flux get kustomizations
flux get helmreleases

# View reconciliation status
flux get all

# Watch for changes
flux logs --follow

# Trigger immediate reconciliation
flux reconcile source git <source-name>
flux reconcile kustomization <kustomization-name>
```

## Troubleshooting

### Flux not syncing

```bash
# Check Flux system pods
kubectl get pods -n flux-system

# Check source status
flux get sources git -A

# View logs
flux logs
```

### ASO resources not creating

```bash
# Check kustomization status
flux get kustomizations

# Check ASO controller logs
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -c manager

# Describe ASO resource
kubectl describe <resource-type> <resource-name>
```

### Git authentication issues

```bash
# Recreate Git source with updated credentials
flux create source git <name> \
  --url=https://github.com/<org>/<repo> \
  --branch=main \
  --username=<username> \
  --password=<token>
```

## Best Practices

### Git Structure

✅ **DO:**
- Use separate directories for different environments
- Keep sensitive data in Kubernetes secrets (sealed secrets)
- Use Kustomize for environment-specific configs
- Tag releases for production deployments

❌ **DON'T:**
- Commit secrets to Git
- Mix different environments in same directory
- Use overly complex directory structures

### Flux Configuration

✅ **DO:**
- Set appropriate reconciliation intervals
- Use health checks for critical resources
- Implement proper dependencies
- Enable prune for automatic cleanup

❌ **DON'T:**
- Set very short reconciliation intervals (causes load)
- Ignore failed reconciliations
- Create circular dependencies

### Security

✅ **DO:**
- Use SOPS or Sealed Secrets for sensitive data
- Limit Flux service account permissions
- Use separate Git repositories for different environments
- Enable Git signature verification

❌ **DON'T:**
- Store credentials in Git
- Use overly permissive RBAC
- Disable security features

## Advanced Topics

### Automated Secrets Management

Use SOPS (Secrets OPerationS) with Flux:

```bash
# Install SOPS
brew install sops  # macOS
# or download from https://github.com/mozilla/sops

# Encrypt a secret
sops --encrypt --age <age-key> secret.yaml > secret.enc.yaml

# Configure Flux to decrypt
flux create kustomization my-app \
  --source=GitRepository/my-repo \
  --path="./deploy" \
  --prune=true \
  --decryption-provider=sops
```

### Image Automation

Automatically update image tags:

```bash
# Install Flux image controllers
flux install --components-extra=image-reflector-controller,image-automation-controller

# Configure image repository
flux create image repository nginx \
  --image=nginx \
  --interval=1m

# Configure image policy
flux create image policy nginx \
  --image-ref=nginx \
  --select-semver=">=1.20.0"
```

### Notifications

Send Flux notifications to Slack/Teams:

```bash
# Create a notification provider
flux create alert-provider slack \
  --type=slack \
  --channel=flux-notifications \
  --address=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Create an alert
flux create alert my-app \
  --provider-ref=slack \
  --event-severity=info \
  --event-source=GitRepository/*,Kustomization/*
```

## References

- [Flux Documentation](https://fluxcd.io/docs/)
- [Flux GitOps Toolkit](https://fluxcd.io/flux/components/)
- [ASO + Flux Example](https://github.com/Azure/azure-service-operator/tree/main/v2/samples)
- [GitOps Principles](https://opengitops.dev/)
