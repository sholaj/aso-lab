# Example 03: Virtual Network

## Overview
This example demonstrates creating Azure Virtual Networks (VNets) and subnets using ASO. VNets are fundamental to Azure networking.

## What You'll Learn
- Creating virtual networks with ASO
- Defining subnets within VNets
- Understanding address spaces and CIDR notation
- Network security concepts

## Prerequisites
- ASO installed
- Resource group created

## Files
- `virtualnetwork.yaml`: Basic VNet with single subnet
- `virtualnetwork-multi-subnet.yaml`: VNet with multiple subnets
- `network-security-group.yaml`: NSG for subnet protection

## Apply the Resources

```bash
# Create the virtual network
kubectl apply -f virtualnetwork.yaml

# Check status
kubectl get virtualnetworks
kubectl describe virtualnetwork aso-lab-vnet

# Wait for provisioning
kubectl wait --for=condition=Ready --timeout=300s virtualnetwork/aso-lab-vnet
```

## Verify in Azure

```bash
# Show VNet details
az network vnet show -n aso-lab-vnet -g aso-lab-rg

# List subnets
az network vnet subnet list -g aso-lab-rg --vnet-name aso-lab-vnet -o table
```

## Understanding VNet Configuration

### Address Space
The overall IP range for the VNet:
- Use private IP ranges (RFC 1918):
  - 10.0.0.0/8 (10.0.0.0 - 10.255.255.255)
  - 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
  - 192.168.0.0/16 (192.168.0.0 - 192.168.255.255)

### Subnet Planning
- Each subnet gets a portion of the VNet address space
- Azure reserves 5 IPs per subnet
- Plan for growth and future subnets

Example layout for 10.0.0.0/16:
- `10.0.1.0/24` - Web tier (251 usable IPs)
- `10.0.2.0/24` - App tier (251 usable IPs)
- `10.0.3.0/24` - Data tier (251 usable IPs)
- `10.0.4.0/24` - Management (251 usable IPs)

## Network Topology Example

```
VNet: aso-lab-vnet (10.0.0.0/16)
├── frontend-subnet (10.0.1.0/24)
│   └── Web servers, load balancers
├── backend-subnet (10.0.2.0/24)
│   └── Application servers
├── data-subnet (10.0.3.0/24)
│   └── Databases, storage
└── aks-subnet (10.0.10.0/24)
    └── AKS nodes
```

## Subnets as Separate Resources

You can define subnets inline or as separate resources:

```yaml
# Inline (in virtualnetwork.yaml)
spec:
  subnets:
  - name: default-subnet
    addressPrefix: 10.0.1.0/24

# Separate resource
apiVersion: network.azure.com/v1api20201101
kind: Subnet
metadata:
  name: app-subnet
spec:
  owner:
    name: aso-lab-vnet
  addressPrefix: 10.0.2.0/24
```

## Network Security Groups

NSGs control traffic to and from subnets:

```bash
# Apply NSG
kubectl apply -f network-security-group.yaml

# Associate NSG with subnet (update VNet manifest)
```

## Key Concepts

### Owner References
Subnets must reference their VNet:
```yaml
spec:
  owner:
    name: aso-lab-vnet
```

### Service Endpoints
Enable direct connectivity to Azure services:
```yaml
serviceEndpoints:
- service: Microsoft.Storage
- service: Microsoft.Sql
```

### Delegation
Some services require subnet delegation:
```yaml
delegations:
- name: aks-delegation
  serviceName: Microsoft.ContainerService/managedClusters
```

## Common Patterns

### Three-Tier Architecture
```yaml
subnets:
- name: web-tier
  addressPrefix: 10.0.1.0/24
- name: app-tier  
  addressPrefix: 10.0.2.0/24
- name: db-tier
  addressPrefix: 10.0.3.0/24
```

### AKS with Separate Subnets
```yaml
subnets:
- name: aks-nodes
  addressPrefix: 10.0.10.0/23  # Larger for node scaling
- name: aks-pods
  addressPrefix: 10.0.20.0/22  # Even larger for pods
```

## Clean Up

```bash
# Delete VNet (and all subnets)
kubectl delete -f virtualnetwork.yaml

# Verify deletion
az network vnet show -n aso-lab-vnet -g aso-lab-rg
```

## Next Steps
- Proceed to Example 04 for AKS clusters
- Try creating VNet peering between networks
- Implement hub-and-spoke network topology
- Add route tables for custom routing
