# Azure Log Analytics Workspace Examples

This directory contains examples for deploying Azure Log Analytics Workspace using ASO v2.

## Examples

1. **basic-log-analytics.yaml** - Basic Log Analytics workspace
2. **log-analytics-with-solutions.yaml** - Workspace with monitoring solutions

## Quick Start

```bash
# Deploy Log Analytics workspace
kubectl apply -f basic-log-analytics.yaml

# Check status
kubectl get workspace myloganalytics001 -n azure-monitoring -w

# View in Azure
az monitor log-analytics workspace show --workspace-name myloganalytics001 --resource-group monitoring-demo-rg
```

## Log Analytics Workspace Overview

Azure Log Analytics is a service that collects and analyzes telemetry data from cloud and on-premises environments.

### Key Features
- Centralized logging and monitoring
- Integration with Azure Monitor
- Query logs using KQL (Kusto Query Language)
- Alerts and dashboards
- Integration with Azure Sentinel

## Common Use Cases

### Cluster Monitoring
- AKS container logs
- Application logs
- Performance metrics
- Security events

### Application Insights
- Application performance monitoring
- Distributed tracing
- Error tracking

### Security & Compliance
- Azure Sentinel integration
- Security audit logs
- Compliance reporting

## Pricing Tiers

### Pay-as-you-go
- $2.30 per GB ingested
- Best for: Variable workloads, development

### Commitment Tiers
- 100 GB/day - 500 GB/day
- Lower per-GB cost
- Best for: Predictable workloads, production

### Retention
- Default: 30 days (included)
- Extended: Up to 730 days (additional cost)

## Integration with AKS

```bash
# Enable Container Insights for AKS
az aks enable-addons \
  --resource-group <rg-name> \
  --name <aks-cluster-name> \
  --addons monitoring \
  --workspace-resource-id <workspace-resource-id>
```

## Useful Queries

### View container logs
```kql
ContainerLog
| where TimeGenerated > ago(1h)
| project TimeGenerated, Computer, ContainerID, LogEntry
| order by TimeGenerated desc
```

### CPU and Memory usage
```kql
Perf
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores" or CounterName == "memoryWorkingSetBytes"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), CounterName
```

### Error logs
```kql
ContainerLog
| where LogEntry contains "error" or LogEntry contains "exception"
| order by TimeGenerated desc
```

## Troubleshooting

### Workspace not receiving data
```bash
# Check diagnostic settings are configured
az monitor diagnostic-settings list --resource <resource-id>

# Verify agent is running (for AKS)
kubectl get pods -n kube-system | grep omsagent
```

### Query performance
- Use time ranges to limit data scanned
- Filter early in the query
- Use summarize for aggregations
- Create custom tables for high-volume data

## References

- [Log Analytics Documentation](https://docs.microsoft.com/azure/azure-monitor/logs/log-analytics-overview)
- [KQL Reference](https://docs.microsoft.com/azure/data-explorer/kusto/query/)
- [Container Insights](https://docs.microsoft.com/azure/azure-monitor/containers/container-insights-overview)
