#!/bin/bash

set -euo pipefail # Exit on error, undefined variable, or pipe failure

# Source shared UAMI selection logic
. "${dirname "$0"}/26_select_flux_managedidentity.sh"

export FLUX_MANAGEDIDENTITY="$SELECTED_UAMI"
echo "[INFO] Using FLUX_MANAGEDIDENTITY=$FLUX_MANAGEDIDENTITY"

# Set subscription for AKS cluster operations
az account set --subscription "$SUBSCRIPTION" --output none

CLUSTER_COUNT=$(az aks list --resource-group ${resourceGroupName} --query "length(@)" --output tsv)
if [ "$CLUSTER_COUNT" -eq 1 ]; then
    echo "[INFO] Number of clusters in the RG ${resourceGroupName}: $CLUSTER_COUNT"
else
    echo "[ERROR] Cannot proceed further as there are more than 1 clusters in this RG ${resourceGroupName}"
    exit 1
fi

echo "[INFO] Get Cluster name"
ClusterName=$(az aks list --resource-group ${resourceGroupName} --query "[].name" --output tsv)
echo "[DEBUG] ClusterName=$ClusterName"

echo "[INFO] Get AKS OIDC Issuer"
export AKS_OIDC_ISSUER=$(az aks show --resource-group ${resourceGroupName} --name ${ClusterName} --query "oidcIssuerProfile.issuerUrl" -o tsv)
echo "[DEBUG] AKS_OIDC_ISSUER=$AKS_OIDC_ISSUER"

# Enhanced function to check for federated credentials with flexible credential support
function check_flexible_federated_credentials() {
    local identity_name="$1"
    local resource_group="$2"
    local issuer="$3"
    local pattern_name="$4"
    
    echo "[INFO] Checking for flexible federated credentials on identity ${identity_name} with pattern ${pattern_name}"
    
    # Query federated credentials using REST API to support flexible credentials
    local credentials_json
    credentials_json=$(az rest --method GET \
        --uri "/subscriptions/${SUBSCRIPTION}/resourceGroups/${resource_group}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}/federatedIdentityCredentials" \
        --query "value[?contains(name, '${pattern_name}')]" \
        -o json 2>/dev/null || echo "[]")
    
    local count=$(echo "$credentials_json" | jq '. | length')
    echo "$count"
}

# Enhanced function to create flexible federated credentials
function create_flexible_federated_credential() {
    local identity_name="$1"
    local resource_group="$2" 
    local credential_name="$3"
    local issuer="$4"
    local claims_expression="$5"
    local description="$6"
    
    echo "[INFO] Creating flexible federated credential: $credential_name for $identity_name"
    echo "[DEBUG] Claims expression: $claims_expression"
    
    local request_body=$(cat <<EOF
{
    "properties": {
        "audiences": ["api://AzureADTokenExchange"],
        "issuer": "${issuer}",
        "subject": null,
        "claimsMatchingExpression": {
            "value": "${claims_expression}",
            "languageVersion": 1
        }
    }
}
EOF
)

    echo "[DEBUG] Request body: $request_body"
    
    if az rest --method PUT \
        --uri "/subscriptions/${SUBSCRIPTION}/resourceGroups/${resource_group}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${identity_name}/federatedIdentityCredentials/${credential_name}" \
        --body "$request_body" \
        --output none; then
        echo "[SUCCESS] Flexible federated credential '${credential_name}' created for ${identity_name} (${description})"
        return 0
    else
        echo "[ERROR] Failed to create flexible federated credential '${credential_name}' for ${identity_name}"
        return 1
    fi
}

# Enhanced function to update federated credentials with flexible support
function update_federated_credentials_flexible() {
    local identity_name="$1"
    local resource_group="$2"
    local subscription="$3"
    local credential_base_name="$4"
    local claims_expression="$5"
    local description="$6"
    
    echo "[INFO] Processing flexible federated credentials for ${identity_name}"
    
    # Generate unique credential name with timestamp to avoid conflicts
    local timestamp=$(date +%s)
    local flexible_credential_name="${credential_base_name}-flexible-${timestamp}"
    
    # Check for existing flexible credentials with similar pattern
    local existing_count
    existing_count=$(check_flexible_federated_credentials "$identity_name" "$resource_group" "$AKS_OIDC_ISSUER" "$credential_base_name")
    
    if [ "$existing_count" -gt 0 ]; then
        echo "[INFO] Found $existing_count existing flexible credential(s) for ${identity_name}"
        echo "[INFO] Creating additional flexible credential: $flexible_credential_name"
    else
        echo "[INFO] No existing flexible credentials found. Creating new credential: $flexible_credential_name"
    fi
    
    # Create the flexible federated credential
    if create_flexible_federated_credential "$identity_name" "$resource_group" "$flexible_credential_name" "$AKS_OIDC_ISSUER" "$claims_expression" "$description"; then
        echo "[SUCCESS] Flexible federated credential created for $identity_name"
    else
        echo "[ERROR] Failed to create flexible federated credential for $identity_name"
        exit 1
    fi
}

# Legacy function for creating traditional federated credentials (fallback)
function update_federated_credentials_legacy() {
    local identity_name="$1"
    local resource_group="$2" 
    local subscription="$3"
    local federated_credentials="$4"
    local subject="$5"
    
    echo "[INFO] Creating legacy federated credential for ${identity_name} with subject: ${subject}"
    
    if ! az identity federated-credential create \
        --name "$federated_credentials" \
        --identity-name "$identity_name" \
        --resource-group "$resource_group" \
        --issuer "$AKS_OIDC_ISSUER" \
        --subject "$subject" \
        --audience "api://AzureADTokenExchange"; then
        echo "[ERROR] Failed to create legacy federated credential for $federated_credentials"
        exit 1
    else
        echo "[SUCCESS] Legacy federated credential created for $federated_credentials"
    fi
}

# Main function to handle both flexible and legacy credential creation
function update_federated_credentials() {
    local identity_name="$1"
    local resource_group="$2"
    local subscription="$3" 
    local federated_credentials="$4"
    local claims_expression="$5"
    local description="$6"
    local use_flexible="${7:-true}"  # Default to flexible unless specified otherwise
    
    echo "[INFO] Updating federated credentials for ${identity_name}"
    echo "[DEBUG] Use flexible credentials: $use_flexible"
    
    if [[ "$use_flexible" == "true" ]]; then
        update_federated_credentials_flexible "$identity_name" "$resource_group" "$subscription" "$federated_credentials" "$claims_expression" "$description"
    else
        # Fallback to legacy method - extract subject from claims expression if needed
        local subject="system:serviceaccount:${ENV}:${federated_credentials}"
        update_federated_credentials_legacy "$identity_name" "$resource_group" "$subscription" "$federated_credentials" "$subject"
    fi
}

echo "[INFO] Create Federated Credentials"
# Flux = use FLUX_MANAGEDIDENTITY_SUBSCRIPTION and FLUX_MANAGEDIDENTITY_RG

# Enhanced flexible credentials for Flux with patterns that support your cattle approach
update_federated_credentials "${FLUX_MANAGEDIDENTITY}" "${FLUX_MANAGEDIDENTITY_RG}" "${FLUX_MANAGEDIDENTITY_SUBSCRIPTION}" \
    "federated_workload_identity_flux_source" \
    "claims['sub'] matches 'system:serviceaccount:flux-system:source-controller' or claims['sub'] matches 'system:serviceaccount:flux-*:source-controller'" \
    "Flux source controller with flexible namespace support"

update_federated_credentials "${FLUX_MANAGEDIDENTITY}" "${FLUX_MANAGEDIDENTITY_RG}" "${FLUX_MANAGEDIDENTITY_SUBSCRIPTION}" \
    "federated_workload_identity_flux_image" \
    "claims['sub'] matches 'system:serviceaccount:flux-system:image-*-controller' or claims['sub'] matches 'system:serviceaccount:flux-*:image-*-controller'" \
    "Flux image controllers with flexible namespace and service account patterns"

update_federated_credentials "${FLUX_MANAGEDIDENTITY}" "${FLUX_MANAGEDIDENTITY_RG}" "${FLUX_MANAGEDIDENTITY_SUBSCRIPTION}" \
    "federated_workload_identity_flux_kustomization" \
    "claims['sub'] matches 'system:serviceaccount:flux-system:kustomize-controller' or claims['sub'] matches 'system:serviceaccount:flux-*:kustomize-controller'" \
    "Flux kustomize controller with flexible namespace support"

update_federated_credentials "${FLUX_MANAGEDIDENTITY}" "${FLUX_MANAGEDIDENTITY_RG}" "${FLUX_MANAGEDIDENTITY_SUBSCRIPTION}" \
    "federated_workload_identity_flux_helm" \
    "claims['sub'] matches 'system:serviceaccount:flux-system:helm-controller' or claims['sub'] matches 'system:serviceaccount:flux-*:helm-controller'" \
    "Flux helm controller with flexible namespace support"

update_federated_credentials "${FLUX_MANAGEDIDENTITY}" "${FLUX_MANAGEDIDENTITY_RG}" "${FLUX_MANAGEDIDENTITY_SUBSCRIPTION}" \
    "federated_workload_identity_flux_notification" \
    "claims['sub'] matches 'system:serviceaccount:flux-system:notification-controller' or claims['sub'] matches 'system:serviceaccount:flux-*:notification-controller'" \
    "Flux notification controller with flexible namespace support"

# Other managed identities use SUBSCRIPTION (AKS cluster subscription)

# CERT-MGR with flexible credentials for ephemeral environments
update_federated_credentials "${CERT_MGR_MANAGEDIDENTITY}" "${UAMI_RESOURCE_GROUP}" "${SUBSCRIPTION}" \
    "federated_workload_identity_certmanager" \
    "claims['sub'] matches 'system:serviceaccount:cert-manager:cert-manager' or claims['sub'] matches 'system:serviceaccount:cert-manager-*:cert-manager*'" \
    "Cert-manager with flexible namespace and service account patterns"

# External Secrets with flexible credentials for dynamic environments
update_federated_credentials "${EXTSECRET_MANAGEDIDENTITY}" "${UAMI_RESOURCE_GROUP}" "${SUBSCRIPTION}" \
    "federated_workload_identity_external_secrets" \
    "claims['sub'] matches 'system:serviceaccount:external-secrets-*:external-secrets-*' or claims['sub'] matches 'system:serviceaccount:external-dns:external-secrets-*'" \
    "External secrets with flexible namespace and service account patterns"

# Additional flexible credential for generic workloads in ephemeral environments
update_federated_credentials "${EXTSECRET_MANAGEDIDENTITY}" "${UAMI_RESOURCE_GROUP}" "${SUBSCRIPTION}" \
    "federated_workload_identity_generic_workloads" \
    "claims['sub'] matches 'system:serviceaccount:${ENV}-*:workload-*' or claims['sub'] matches 'system:serviceaccount:default:workload-identity-*'" \
    "Generic workloads in ephemeral ${ENV} environments"

echo "[INFO] Flexible Federated Credentials setup completed for cattle-style cluster management"

# Create suffix to append to federated credentials to support multiple clusters using one UAMI
if [ "$common_useNewNamingConvention" = "false" ]; then
    trimmed_clusterprefix="${common_oldClusterNameSuffix//\"*/}"  # Removes ALL quotes
    echo "New trimmed_clusterprefix=$trimmed_clusterprefix"
else
    trimmed_clusterprefix="${common_newClusterName}"
    echo "Old trimmed_clusterprefix=$trimmed_clusterprefix"
fi

echo "[INFO] Create UAMIs in AKS cluster subscription for ephemeral environments"

# Enhanced UAMI creation with flexible credential support
function create_uami_with_flexible_credentials() {
    local uami_name="$1"
    local description="$2"
    local claims_pattern="$3"
    
    echo "[INFO] Creating UAMI: $uami_name"
    
    if az identity create --resource-group "${UAMI_RESOURCE_GROUP}" --name "$uami_name"; then
        echo "[SUCCESS] $uami_name created in resource group ${UAMI_RESOURCE_GROUP}"
        
        # Create flexible federated credential for the new UAMI
        local credential_name="${uami_name}-flexible-$(date +%s)"
        update_federated_credentials "$uami_name" "${UAMI_RESOURCE_GROUP}" "${SUBSCRIPTION}" \
            "$credential_name" \
            "$claims_pattern" \
            "$description"
    else
        echo "[ERROR] Failed to create $uami_name"
        exit 1
    fi
}

# Create UAMIs with flexible credentials for your cattle environment
create_uami_with_flexible_credentials "${EXTNDS_MANAGEDIDENTITY}" \
    "External DNS with flexible environment support" \
    "claims['sub'] matches 'system:serviceaccount:external-dns:external-dns' or claims['sub'] matches 'system:serviceaccount:${ENV}-*:external-dns*'"

create_uami_with_flexible_credentials "${CERT_MGR_MANAGEDIDENTITY}" \
    "Certificate Manager with flexible environment support" \
    "claims['sub'] matches 'system:serviceaccount:cert-manager:cert-manager*' or claims['sub'] matches 'system:serviceaccount:cert-manager-*:cert-manager*'"

create_uami_with_flexible_credentials "${EXTSECRET_MANAGEDIDENTITY}" \
    "External Secrets with flexible environment support" \
    "claims['sub'] matches 'system:serviceaccount:external-secrets:external-secrets*' or claims['sub'] matches 'system:serviceaccount:external-secrets-*:external-secrets*'"

echo "[INFO] Enhanced workload identity setup completed with flexible federated credentials"
echo "[INFO] This setup supports your cattle-style approach with daily cluster refresh capabilities"
echo "[INFO] Credentials will work across ephemeral namespaces and dynamic service accounts"

# No longer required vault inject has been removed.
# update_federated_credentials ${UAMI} federated_workload_identity.vault${trimmed_clusterprefix} system:serviceaccount:ubs-system:vault-sa

echo "[INFO] Managed Identity Client IDs for HelmRelease updates"
echo "\n[INFO] Managed Identity Client IDs for HelmRelease updates ---"

# Output client IDs for configuration
function output_client_ids() {
    local identity_name="$1"
    local resource_group="$2"
    local description="$3"
    
    local client_id
    client_id=$(az identity show --name "$identity_name" --resource-group "$resource_group" --query "clientId" -o tsv)
    echo "$description: $client_id"
}

# Switch to AKS cluster subscription for non-flux identities
az account set --subscription "$SUBSCRIPTION" --output none

output_client_ids "${EXTNDS_MANAGEDIDENTITY}" "${UAMI_RESOURCE_GROUP}" "External DNS Client ID"
output_client_ids "${CERT_MGR_MANAGEDIDENTITY}" "${UAMI_RESOURCE_GROUP}" "Certificate Manager Client ID" 
output_client_ids "${EXTSECRET_MANAGEDIDENTITY}" "${UAMI_RESOURCE_GROUP}" "External Secrets Client ID"

# Switch to Flux subscription for flux identity
az account set --subscription "$FLUX_MANAGEDIDENTITY_SUBSCRIPTION" --output none

echo "Flux Managed Identity: $(az identity show --name ${FLUX_MANAGEDIDENTITY} --resource-group ${FLUX_MANAGEDIDENTITY_RG} --query "clientId" -o tsv)"
echo "[INFO] Exported Flux Managed Identity Client ID as FluxWorkloadIdentity=$FluxWorkloadIdentity"

# Switch back to AKS cluster subscription for any subsequent operations
az account set --subscription "$SUBSCRIPTION" --output none

echo "[INFO] Setup completed successfully with flexible federated credentials for cattle-style cluster management"
