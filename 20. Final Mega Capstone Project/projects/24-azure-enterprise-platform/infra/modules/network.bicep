@minLength(3)
param prefix string
@minLength(2)
param environment string
param location string
param tags object
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = { name: '${prefix}-${environment}-aks-nsg', location: location, tags: tags, properties: { securityRules: [] } }
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
 name: '${prefix}-${environment}-spoke-vnet'
 location: location
 tags: tags
 properties: {
  addressSpace: { addressPrefixes: ['10.60.0.0/16'] }
  subnets: [{
   name: 'aks'
   properties: {
    addressPrefix: '10.60.0.0/20'
    networkSecurityGroup: { id: networkSecurityGroup.id }
    privateEndpointNetworkPolicies: 'Disabled'
   }
  }]
 }
}
output aksSubnetId string = virtualNetwork.properties.subnets[0].id
