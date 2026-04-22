targetScope = 'subscription'

@minLength(1)
@maxLength(24)
@description('azd environment name; used to derive resource group and resource names.')
param environmentName string

@description('Primary Azure region for all resources.')
param location string = 'eastus2'

@description('Presenter public IP in CIDR form (e.g., 1.2.3.4/32) allowed through the NSG for RDP/1433.')
param presenterIp string

@description('Entra ID user principal name (UPN) that becomes the Entra admin on the SQL instance.')
param entraAdminLoginName string

@description('Name of the SQL authentication login created for fallback demo access.')
param sqlAdminLogin string = 'demoadmin'

@secure()
@description('Password for the SQL authentication login.')
param sqlAdminPassword string

@description('Local Windows administrator username on the VM.')
param vmAdminUsername string = 'azureuser'

@secure()
@description('Local Windows administrator password on the VM.')
param vmAdminPassword string

@description('VM size.')
param vmSize string = 'Standard_D2s_v5'

var tags = {
  'azd-env-name': environmentName
  purpose: 'sql-copilot-demo'
}

var resourceGroupName = 'rg-${environmentName}'
var abbrvEnv = toLower(replace(environmentName, '-', ''))
var vmName = take('vm${abbrvEnv}', 15)
var nicName = 'nic-${abbrvEnv}'
var pipName = 'pip-${abbrvEnv}'
var nsgName = 'nsg-${abbrvEnv}'
var vnetName = 'vnet-${abbrvEnv}'
var dnsLabel = 'sqldemo-${uniqueString(subscription().subscriptionId, environmentName)}'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    location: location
    tags: tags
    vnetName: vnetName
    nsgName: nsgName
    pipName: pipName
    nicName: nicName
    dnsLabel: dnsLabel
    presenterIp: presenterIp
  }
}

module vm 'modules/vm.bicep' = {
  name: 'vm'
  scope: rg
  params: {
    location: location
    tags: tags
    vmName: vmName
    vmSize: vmSize
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    nicId: network.outputs.nicId
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    entraAdminLoginName: entraAdminLoginName
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_LOCATION string = location
output SQL_VM_NAME string = vmName
output SQL_VM_FQDN string = network.outputs.publicFqdn
output SQL_VM_PUBLIC_IP string = network.outputs.publicIp
output SQL_ADMIN_LOGIN string = sqlAdminLogin
output ENTRA_ADMIN_UPN string = entraAdminLoginName
