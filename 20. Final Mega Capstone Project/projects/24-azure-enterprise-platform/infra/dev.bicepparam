using './main.bicep'
param prefix = 'masterclass'
param environment = 'dev'
param location = 'centralindia'
param kubernetesVersion = '1.36'
param privateCluster = true
param tags = { Environment: 'dev', ManagedBy: 'Bicep', Owner: 'replace-with-owner', CostCenter: 'replace-with-cost-center', DataClass: 'internal' }
