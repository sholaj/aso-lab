# Phase 3: Azure Container Registry (ACR)

Deploy an Azure Container Registry for storing container images.

## Important Notes

- Registry names must be globally unique
- Only alphanumeric characters allowed (no hyphens)
- If `acrasoshola001` is taken, modify the name in the YAML

## Deploy

```bash
kubectl apply -f acr.yaml
```

## Monitor

```bash
# Watch the registry creation
kubectl get registry -w

# Describe the registry
kubectl describe registry acrasoshola001

# Get registry details from Azure
az acr show --name acrasoshola001 --resource-group rg-aso-workloads-shola
```

## Key Concepts

1. **SKU Tiers**:
   - **Basic**: Cost-optimized for dev/test (used in this lab)
   - **Standard**: Production workloads
   - **Premium**: Geo-replication, content trust, private link

2. **Authentication**: Admin user disabled; use Azure RBAC or AKS integration

## Integrate with AKS

Allow your AKS cluster to pull images from ACR:

```bash
# Attach ACR to AKS
az aks update \
  --resource-group rg-aso-lab-shola \
  --name aks-aso-lab-shola \
  --attach-acr acrasoshola001
```

## Test the Registry

```bash
# Login to ACR
az acr login --name acrasoshola001

# Pull a public image
docker pull nginx:latest

# Tag it for your registry
docker tag nginx:latest acrasoshola001.azurecr.io/nginx:latest

# Push to your registry
docker push acrasoshola001.azurecr.io/nginx:latest

# List images
az acr repository list --name acrasoshola001 --output table
```

## Use in Kubernetes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-from-acr
spec:
  containers:
  - name: nginx
    image: acrasoshola001.azurecr.io/nginx:latest
```
