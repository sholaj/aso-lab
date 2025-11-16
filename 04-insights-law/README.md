# Phase 3: Log Analytics Workspace

Deploy a Log Analytics Workspace (LAW) for monitoring and observability.

## What is Log Analytics?

Log Analytics Workspace is Azure's centralized logging and monitoring solution. It collects telemetry from:
- AKS clusters
- Azure resources
- Application logs
- Performance metrics

## Deploy

```bash
kubectl apply -f loganalytics.yaml
```

## Monitor

```bash
# Watch the workspace creation
kubectl get workspace -w

# Describe the workspace
kubectl describe workspace law-aso-lab-shola

# Get workspace details from Azure
az monitor log-analytics workspace show \
  --workspace-name law-aso-lab-shola \
  --resource-group rg-aso-workloads-shola
```

## Key Concepts

1. **SKU**: PerGB2018 is pay-as-you-go (no upfront commitment)
2. **Retention**: 30 days minimum for cost optimization in lab
3. **Public Access**: Enabled for easy testing (restrict in production)

## Use with AKS

This workspace can be integrated with AKS for container insights:

```bash
az aks enable-addons \
  --resource-group rg-aso-lab-shola \
  --name aks-aso-lab-shola \
  --addons monitoring \
  --workspace-resource-id $(az monitor log-analytics workspace show \
    --workspace-name law-aso-lab-shola \
    --resource-group rg-aso-workloads-shola \
    --query id -o tsv)
```

## Query Logs

Access the workspace in Azure Portal or use Kusto Query Language (KQL):

```kql
// Example: View all container logs
ContainerLog
| where TimeGenerated > ago(1h)
| limit 50
```
