# Flexible Federated Identity Credentials Migration Guide

## Overview

This document outlines the enhancements made to `40_workload_identity_setup.sh` to support flexible federated identity credentials, specifically designed for your "cattle not pets" approach to AKS cluster management.

## Key Enhancements

### 1. Flexible Federated Credentials Support

**Before (Traditional):**
```bash
az identity federated-credential create \
    --name "specific-credential" \
    --identity-name "$identity_name" \
    --resource-group "$resource_group" \
    --issuer "$AKS_OIDC_ISSUER" \
    --subject "system:serviceaccount:flux-system:source-controller"
```

**After (Flexible):**
```bash
az rest --method PUT \
    --uri "/subscriptions/$SUBSCRIPTION/resourceGroups/$resource_group/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identity_name/federatedIdentityCredentials/$credential_name" \
    --body '{
        "properties": {
            "audiences": ["api://AzureADTokenExchange"],
            "issuer": "$AKS_OIDC_ISSUER", 
            "claimsMatchingExpression": {
                "value": "claims[\"sub\"] matches \"system:serviceaccount:flux-*:source-controller\"",
                "languageVersion": 1
            }
        }
    }'
```

### 2. Pattern-Based Credentials for Cattle Environment

The new script implements flexible patterns perfect for ephemeral clusters:

#### Flux Controllers
- **Pattern**: `claims['sub'] matches 'system:serviceaccount:flux-*:*-controller'`
- **Supports**: Dynamic flux namespaces across environments
- **Benefit**: Single credential works for `flux-system`, `flux-dev`, `flux-staging`, etc.

#### Environment-Specific Workloads
- **Pattern**: `claims['sub'] matches 'system:serviceaccount:${ENV}-*:workload-*'`
- **Supports**: Dev/test namespaces with workload service accounts
- **Benefit**: Handles daily cluster recreation without credential recreation

#### Certificate Management
- **Pattern**: `claims['sub'] matches 'system:serviceaccount:cert-manager*:cert-manager*'`
- **Supports**: Various cert-manager deployment patterns
- **Benefit**: Works across different cert-manager namespace configurations

### 3. Enhanced Functions

#### `check_flexible_federated_credentials()`
- Uses REST API to query flexible credentials
- Supports pattern-based credential detection
- Provides detailed logging for troubleshooting

#### `create_flexible_federated_credential()`
- Creates flexible credentials via REST API
- Includes claims expression validation
- Provides detailed error handling

#### `update_federated_credentials_flexible()`
- Main orchestration function
- Handles both flexible and legacy credential creation
- Includes conflict detection and resolution

### 4. Cattle-Optimized Patterns

For your daily cluster refresh pipeline, the script now creates these flexible patterns:

```bash
# Flux namespace flexibility
"claims['sub'] matches 'system:serviceaccount:flux-system:source-controller' or claims['sub'] matches 'system:serviceaccount:flux-*:source-controller'"

# Environment-specific workloads  
"claims['sub'] matches 'system:serviceaccount:${ENV}-*:workload-*'"

# Generic service account patterns
"claims['sub'] matches 'system:serviceaccount:*:platform-*'"
```

## Migration Benefits for Cattle Architecture

### 1. Reduced Management Overhead
- **Before**: Need to create specific credentials for each cluster/namespace combination
- **After**: Single flexible credential covers multiple deployment patterns

### 2. Daily Cluster Refresh Support
- **Before**: Recreating clusters required recreating specific federated credentials
- **After**: Flexible patterns automatically work with new cluster deployments

### 3. Multi-Environment Support
- **Before**: Separate credentials needed for dev/test/staging environments
- **After**: Environment variables (`${ENV}`) in patterns handle multiple environments

### 4. GitOps Flexibility
- **Before**: Fixed namespace assumptions in credentials
- **After**: Supports dynamic GitOps namespace patterns

## Implementation Strategy

### Phase 1: Parallel Deployment
1. Deploy enhanced script alongside existing script
2. Test flexible credentials in dev environment
3. Validate pattern matching works with existing deployments

### Phase 2: Migration
1. Run enhanced script on existing clusters
2. Validate both traditional and flexible credentials work
3. Monitor for any authentication issues

### Phase 3: Optimization
1. Remove legacy credential creation where flexible patterns are sufficient
2. Optimize patterns based on actual usage patterns
3. Update GitLab pipeline to use enhanced script

## GitLab CI Integration

Update your `.gitlab-ci.yml` to use the enhanced script:

```yaml
1. Create workloadIdentity:
  extends:
    - .get-vault-secrets
    - .workloadIdentity-setup
  script:
    - sh pipelines/scripts/40_workload_identity_setup_flexible.sh  # Updated script
  needs:
    - job: 2. Build variables
      artifacts: true
```

## Validation Commands

After deployment, validate flexible credentials are working:

```bash
# Check flexible credentials exist
az rest --method GET \
    --uri "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$IDENTITY_NAME/federatedIdentityCredentials" \
    --query "value[?properties.claimsMatchingExpression != null]"

# Test token acquisition from pod
kubectl run test-pod --image=mcr.microsoft.com/azure-cli \
    --labels="azure.workload.identity/use=true" \
    --serviceaccount=workload-identity-sa \
    --command -- sleep 3600

kubectl exec test-pod -- az account get-access-token --resource https://management.azure.com/
```

## Troubleshooting

### Common Issues

1. **Claims Expression Syntax Errors**
   - Ensure proper escaping of single quotes in expressions
   - Validate JSON syntax in REST API calls

2. **Pattern Not Matching**
   - Check actual service account names against patterns
   - Use `kubectl get serviceaccounts -A` to verify naming

3. **Legacy Tool Conflicts**
   - Azure CLI doesn't display flexible credentials properly
   - Use REST API or Azure Portal for validation

### Debug Commands

```bash
# Show actual claims in JWT token
kubectl get serviceaccount workload-identity-sa -o yaml
kubectl describe pod <pod-name>

# Check federation status
az identity federated-credential list --identity-name $IDENTITY_NAME --resource-group $RG
```

## Performance Considerations

- Flexible credentials reduce the total number of federated credentials needed
- Single credential can replace 5-10 traditional credentials
- Reduced Azure AD token exchange overhead
- Faster cluster provisioning due to fewer credential creation API calls

## Security Considerations

- Patterns should be as specific as possible while maintaining flexibility
- Regular review of pattern effectiveness
- Monitor for overly permissive patterns
- Maintain principle of least privilege within pattern scope

## Future Enhancements

1. **Dynamic Pattern Generation**: Based on actual cluster usage patterns
2. **Pattern Optimization**: Machine learning to optimize patterns over time
3. **Cross-Subscription Patterns**: For multi-subscription cattle deployments
4. **Integration with ASO**: For full infrastructure-as-code cattle management
