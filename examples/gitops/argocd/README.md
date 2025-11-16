# Argo CD + ASO Integration

This directory contains examples for using Argo CD with Azure Service Operator v2 for GitOps workflows.

## What is Argo CD?

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It monitors Git repositories and automatically syncs cluster state with Git-defined desired state.

## Benefits of Argo CD + ASO

- ✅ **Visual UI**: Web interface for monitoring deployments
- ✅ **Multi-Cluster**: Manage multiple clusters from single Argo instance
- ✅ **Sync Strategies**: Auto-sync or manual approval
- ✅ **Rollback**: Easy rollback to previous Git commits
- ✅ **RBAC**: Fine-grained access control
- ✅ **SSO Integration**: Enterprise authentication

## Quick Start

### Install Argo CD

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Username: admin
# Password: (from previous command)
```

### Install Argo CD CLI

```bash
# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# macOS
brew install argocd

# Login
argocd login localhost:8080
```

### Setup ASO with Argo CD

```bash
# Create ASO credentials
kubectl create namespace azureserviceoperator-system

kubectl create secret generic aso-credential \
  --namespace azureserviceoperator-system \
  --from-literal=AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
  --from-literal=AZURE_TENANT_ID=$AZURE_TENANT_ID \
  --from-literal=AZURE_CLIENT_ID=$AZURE_CLIENT_ID \
  --from-literal=AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET

# Apply Argo CD applications
kubectl apply -f 01-aso-application.yaml
```

## Directory Structure

```
examples/gitops/argocd/
├── README.md                          # This file
├── 01-aso-application.yaml            # Argo Application for ASO
├── 02-infrastructure-app.yaml         # Application for infrastructure
├── 03-app-of-apps.yaml                # App-of-Apps pattern
└── infrastructure/
    ├── resource-groups.yaml
    ├── storage.yaml
    └── keyvault.yaml
```

## Argo CD Concepts

### Applications

Applications define:
- **Source**: Git repository and path
- **Destination**: Target cluster and namespace
- **Sync Policy**: Manual or automatic synchronization
- **Health**: Resource health status

### Projects

Projects provide:
- Multi-tenancy
- RBAC boundaries
- Resource restrictions
- Allowed destinations

### Sync Strategies

- **Manual Sync**: Require manual approval
- **Auto Sync**: Automatic sync on Git changes
- **Auto Prune**: Delete resources not in Git
- **Self Heal**: Restore resources if manually changed

## Example Workflows

### Workflow 1: Single Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: azure-infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: infrastructure
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Workflow 2: App of Apps

Manage multiple applications with a parent app:

```
Parent App (app-of-apps)
    ├── ASO Installation App
    ├── Infrastructure App
    │   ├── Resource Groups
    │   ├── Storage
    │   └── Key Vault
    └── Application App
        ├── Deployment
        └── Service
```

### Workflow 3: Multi-Environment

```
Git Repository
    ├── base/
    │   └── infrastructure/
    └── overlays/
        ├── dev/
        ├── staging/
        └── production/

Argo Applications:
    ├── infra-dev (points to overlays/dev)
    ├── infra-staging (points to overlays/staging)
    └── infra-production (points to overlays/production)
```

## Monitoring Argo CD

### CLI Commands

```bash
# List applications
argocd app list

# Get application details
argocd app get <app-name>

# View sync status
argocd app sync <app-name>

# Watch sync progress
argocd app sync <app-name> --watch

# View application history
argocd app history <app-name>

# Rollback application
argocd app rollback <app-name> <revision>
```

### UI Monitoring

1. Open Argo CD UI: https://localhost:8080
2. View application tree
3. Click resources to see details
4. Check sync status and health
5. View events and logs

## Troubleshooting

### Application OutOfSync

```bash
# View differences
argocd app diff <app-name>

# Force sync
argocd app sync <app-name> --force

# Refresh cache
argocd app get <app-name> --refresh
```

### Sync Failures

```bash
# View sync logs
argocd app logs <app-name>

# Check application events
kubectl describe application <app-name> -n argocd

# Check ASO controller
kubectl logs -n azureserviceoperator-system deployment/azureserviceoperator-controller-manager -c manager
```

### Health Check Issues

```bash
# View resource health
argocd app get <app-name> --show-operation

# Describe unhealthy resource
kubectl describe <resource-type> <resource-name> -n <namespace>
```

## Best Practices

### Application Configuration

✅ **DO:**
- Use projects for multi-tenancy
- Enable auto-sync for non-production
- Use manual sync for production
- Enable self-heal for stateless apps
- Set resource limits

❌ **DON'T:**
- Auto-sync everything in production
- Ignore health checks
- Use default project for everything
- Disable prune without reason

### Repository Structure

✅ **DO:**
- Separate apps into different paths
- Use Kustomize/Helm for environments
- Keep secrets in sealed-secrets
- Document sync waves

❌ **DON'T:**
- Mix environments in same path
- Commit secrets to Git
- Create overly complex structures

### Security

✅ **DO:**
- Enable SSO/RBAC
- Use projects for isolation
- Restrict cluster access
- Enable audit logging
- Use sealed secrets

❌ **DON'T:**
- Use default admin password
- Grant cluster-admin to all users
- Store credentials in Git
- Disable RBAC

## Sync Waves

Control deployment order using sync waves:

```yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: my-rg
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Deploy first
---
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mysa
  annotations:
    argocd.argoproj.io/sync-wave: "1"  # Deploy after RG
```

## Health Checks

Custom health checks for ASO resources:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations: |
    storage.azure.com/StorageAccount:
      health.lua: |
        hs = {}
        if obj.status ~= nil and obj.status.conditions ~= nil then
          for i, condition in ipairs(obj.status.conditions) do
            if condition.type == "Ready" and condition.status == "True" then
              hs.status = "Healthy"
              hs.message = "Storage account is ready"
              return hs
            end
          end
        end
        hs.status = "Progressing"
        hs.message = "Waiting for storage account"
        return hs
```

## Advanced Features

### Notifications

Configure Slack/Teams notifications:

```bash
# Install notifications controller
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/release-1.0/manifests/install.yaml

# Configure Slack
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  template.app-deployed: |
    message: Application {{.app.metadata.name}} is now running.
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
EOF
```

### Progressive Delivery

Use Argo Rollouts for advanced deployments:

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### Multi-Cluster Management

Register additional clusters:

```bash
# Get cluster context
kubectl config get-contexts

# Add cluster to Argo CD
argocd cluster add <context-name>

# Deploy to remote cluster
argocd app create my-app \
  --repo https://github.com/your-org/repo \
  --path apps \
  --dest-server https://remote-cluster:6443 \
  --dest-namespace default
```

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
