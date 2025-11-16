# Phase 6: GitOps with Argo CD (Alternative to Flux)

Implement GitOps workflow using Argo CD as an alternative to Flux.

## Argo CD vs Flux

| Feature | Argo CD | Flux CD |
|---------|---------|---------|
| **UI** | ✅ Rich web UI | ❌ CLI only (Weave GitOps available) |
| **Learning Curve** | Easier (visual) | Steeper (CLI-focused) |
| **CNCF Status** | Graduated | Graduated |
| **Multi-tenancy** | Built-in Projects | Requires configuration |
| **Helm Support** | Native | Via HelmRelease CRD |
| **App of Apps** | Native pattern | Kustomization dependencies |

Choose **Argo CD** if you prefer a UI. Choose **Flux** for pure GitOps CLI workflow.

## Installation

```bash
# Make script executable
chmod +x install-argo.sh

# Run installation
./install-argo.sh
```

The script will:
1. Create `argocd` namespace
2. Install Argo CD components
3. Display admin password
4. Install Argo CD CLI (optional)

## Access Argo CD UI

### Option 1: Port Forward (Quick)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open: https://localhost:8080

### Option 2: LoadBalancer (Persistent)

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for external IP
kubectl get svc argocd-server -n argocd -w
```

### Option 3: Ingress (Production)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
  tls:
  - hosts:
    - argocd.yourdomain.com
    secretName: argocd-server-tls
```

## Login

### Via UI
1. Navigate to https://localhost:8080
2. Username: `admin`
3. Password: (from installation script output)

### Via CLI

```bash
# Login
argocd login localhost:8080

# Change password
argocd account update-password
```

## Create Applications

### Method 1: Via UI

1. Click "+ NEW APP"
2. Fill in:
   - **Application Name**: aso-infrastructure
   - **Project**: default
   - **Sync Policy**: Automatic
   - **Repository URL**: https://github.com/sholaj/aso-lab
   - **Path**: 01-resource-group
   - **Cluster URL**: https://kubernetes.default.svc
   - **Namespace**: default
3. Click "CREATE"

### Method 2: Via YAML

```bash
# Update the repository URL in application.yaml
sed -i '' 's|sholaj|your-github-username|g' application.yaml

# Apply
kubectl apply -f application.yaml

# Verify
argocd app list
```

### Method 3: Via CLI

```bash
argocd app create aso-infrastructure \
  --repo https://github.com/sholaj/aso-lab \
  --path 01-resource-group \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

## Monitor Applications

### Via UI

Navigate to the app in the UI to see:
- **Resource topology** (visual graph)
- **Sync status**
- **Health status**
- **Events and logs**

### Via CLI

```bash
# List applications
argocd app list

# Get app details
argocd app get aso-infrastructure

# Watch sync status
argocd app wait aso-infrastructure

# View logs
argocd app logs aso-infrastructure
```

## Sync Applications

### Auto-sync (Recommended)

Already configured in `application.yaml`:

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources not in Git
    selfHeal: true   # Auto-fix manual changes
```

### Manual Sync

```bash
# Via CLI
argocd app sync aso-infrastructure

# Via UI
Click "SYNC" button
```

## Testing Drift Detection

Argo CD continuously monitors for drift (like Flux).

### Test: Manual Change

```bash
# Manually delete a resource
kubectl delete resourcegroup rg-aso-workloads-shola

# Argo CD will detect drift and auto-heal (recreate) within seconds
# Watch in the UI or:
argocd app get aso-infrastructure --refresh
```

### Test: Git Change

```bash
# Make a change in Git
echo "  updated: true" >> 01-resource-group/resourcegroup.yaml
git add .
git commit -m "Test change"
git push

# Argo CD detects and syncs within 3 minutes (default)
# Force refresh:
argocd app get aso-infrastructure --refresh
```

## App of Apps Pattern

Deploy multiple applications from a single "parent" app:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aso-lab-root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/sholaj/aso-lab
    targetRevision: main
    path: argo/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Then create `argo/apps/` directory with application manifests.

## Multi-Environment Management

Create projects for each environment:

```bash
# Create dev project
argocd proj create dev

# Create staging project
argocd proj create staging

# Create prod project with restrictions
argocd proj create prod \
  --dest https://kubernetes.default.svc,prod-namespace \
  --src https://github.com/sholaj/aso-lab
```

## RBAC and Security

### Create Additional Users

```bash
# Edit argocd-cm ConfigMap
kubectl edit configmap argocd-cm -n argocd
```

Add:
```yaml
data:
  accounts.developer: apiKey,login
  accounts.viewer: login
```

### Set Passwords

```bash
argocd account update-password --account developer
```

### Set Permissions

```bash
# Edit argocd-rbac-cm
kubectl edit configmap argocd-rbac-cm -n argocd
```

Add:
```yaml
data:
  policy.csv: |
    p, role:developer, applications, *, dev/*, allow
    p, role:viewer, applications, get, */*, allow
    g, developer, role:developer
    g, viewer, role:viewer
```

## Troubleshooting

### App Stuck in Syncing

```bash
# Refresh and hard refresh
argocd app get aso-infrastructure --refresh --hard-refresh

# Delete and recreate
argocd app delete aso-infrastructure
argocd app create aso-infrastructure ...
```

### Out of Sync Despite No Changes

```bash
# Check diff
argocd app diff aso-infrastructure

# Ignore specific fields
kubectl edit application aso-infrastructure -n argocd
```

Add ignoreDifferences:
```yaml
spec:
  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas
```

## Notifications

Configure Slack/Teams notifications:

```bash
# Install notifications controller
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/release-1.0/manifests/install.yaml

# Configure Slack
kubectl edit configmap argocd-notifications-cm -n argocd
```

## Cleanup

```bash
# Delete applications
argocd app delete aso-infrastructure aso-storage aso-keyvault

# Uninstall Argo CD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

## Next Steps

- Configure SSO (Azure AD, GitHub, Google)
- Set up image updater for automated container updates
- Implement app of apps pattern for multi-environment
- Integrate with CI/CD pipelines
