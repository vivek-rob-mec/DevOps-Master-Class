@minLength(3)
param prefix string
@minLength(2)
param environment string
param location string
param kubernetesVersion string
param privateCluster bool
param aksSubnetId string
param tags object
resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = { name: '${prefix}-${environment}-logs', location: location, tags: tags, properties: { retentionInDays: 30, features: { enableLogAccessUsingOnlyResourcePermissions: true } } }
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = { name: 'acr${uniqueString(resourceGroup().id)}', location: location, tags: tags, sku: { name: 'Premium' }, properties: { adminUserEnabled: false, publicNetworkAccess: 'Disabled', policies: { retentionPolicy: { days: 14, status: 'enabled' }, exportPolicy: { status: 'disabled' }, quarantinePolicy: { status: 'enabled' }, trustPolicy: { type: 'Notary', status: 'disabled' } } } }
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = { name: '${prefix}-${environment}-workload-id', location: location, tags: tags }
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
 name: 'kv${uniqueString(resourceGroup().id)}'
 location: location
 tags: tags
 properties: {
  tenantId: subscription().tenantId
  sku: { family: 'A', name: 'standard' }
  enableRbacAuthorization: true
  enablePurgeProtection: true
  enableSoftDelete: true
  softDeleteRetentionInDays: 90
  publicNetworkAccess: 'Disabled'
 }
}
resource aks 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
 name: '${prefix}-${environment}-aks'
 location: location
 tags: tags
 identity: { type: 'SystemAssigned' }
 sku: { name: 'Base', tier: 'Standard' }
 properties: {
  kubernetesVersion: kubernetesVersion
  dnsPrefix: '${prefix}-${environment}'
  enableRBAC: true
  disableLocalAccounts: true
  oidcIssuerProfile: { enabled: true }
  securityProfile: { workloadIdentity: { enabled: true }, defender: { logAnalyticsWorkspaceResourceId: logs.id, securityMonitoring: { enabled: true } } }
  aadProfile: { managed: true, enableAzureRBAC: true, tenantID: subscription().tenantId }
  apiServerAccessProfile: { enablePrivateCluster: privateCluster, privateDNSZone: privateCluster ? 'system' : 'none' }
  networkProfile: { networkPlugin: 'azure', networkPluginMode: 'overlay', networkDataplane: 'cilium', loadBalancerSku: 'standard', outboundType: 'loadBalancer', serviceCidr: '10.70.0.0/16', dnsServiceIP: '10.70.0.10' }
  agentPoolProfiles: [{ name: 'system', mode: 'System', count: 3, vmSize: 'Standard_D4ds_v5', osType: 'Linux', type: 'VirtualMachineScaleSets', vnetSubnetID: aksSubnetId, enableAutoScaling: true, minCount: 3, maxCount: 6, availabilityZones: ['1','2','3'], osDiskType: 'Managed', osDiskSizeGB: 128, maxPods: 50 }]
  addonProfiles: { azurepolicy: { enabled: true }, omsagent: { enabled: true, config: { logAnalyticsWorkspaceResourceID: logs.id, useAADAuth: 'true' } } }
 }
}
resource federation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
 parent: identity
 name: 'sample-workload'
 properties: { issuer: aks.properties.oidcIssuerProfile.issuerURL, subject: 'system:serviceaccount:sample:sample-api', audiences: ['api://AzureADTokenExchange'] }
}
resource keyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
 scope: vault
 name: guid(vault.id,identity.id,'Key Vault Secrets User')
 properties: { roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions','4633458b-17de-408a-b874-0445c86b69e6'), principalId: identity.properties.principalId, principalType: 'ServicePrincipal' }
}
output clusterName string = aks.name
output oidcIssuer string = aks.properties.oidcIssuerProfile.issuerURL
output workloadIdentityClientId string = identity.properties.clientId
output keyVaultName string = vault.name
