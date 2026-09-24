targetScope = 'subscription'

@minLength(3)
param prefix string = 'masterclass'
@minLength(2)
param environment string = 'dev'
param location string = 'centralindia'
param kubernetesVersion string = '1.36'
param privateCluster bool = true
param tags object = { Environment: environment, ManagedBy: 'Bicep', Owner: 'replace-with-owner', CostCenter: 'replace-with-cost-center' }

var resourceGroupName = '${prefix}-${environment}-platform-rg'
resource platformResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = { name: resourceGroupName, location: location, tags: tags }

module network 'modules/network.bicep' = {
 name: 'network-${environment}'
 scope: platformResourceGroup
 params: { prefix: prefix, environment: environment, location: location, tags: tags }
}
module platform 'modules/platform.bicep' = {
 name: 'platform-${environment}'
 scope: platformResourceGroup
 params: {
  prefix: prefix
  environment: environment
  location: location
  kubernetesVersion: kubernetesVersion
  privateCluster: privateCluster
  aksSubnetId: network.outputs.aksSubnetId
  tags: tags
 }
}
output resourceGroupName string = platformResourceGroup.name
output clusterName string = platform.outputs.clusterName
output oidcIssuer string = platform.outputs.oidcIssuer
output workloadIdentityClientId string = platform.outputs.workloadIdentityClientId
output keyVaultName string = platform.outputs.keyVaultName
