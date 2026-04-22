@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

param vnetName string
param nsgName string
param pipName string
param nicName string
param dnsLabel string

@description('Presenter public IP (CIDR, e.g., 1.2.3.4/32) allowed for RDP + SQL.')
param presenterIp string

var subnetName = 'snet-sql'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-Presenter'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: presenterIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
          description: 'RDP from presenter IP only'
        }
      }
      {
        name: 'Allow-SQL-Presenter'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: presenterIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '1433'
          description: 'SQL Server from presenter IP only'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.20.0.0/16' ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabel
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

output nicId string = nic.id
output publicIp string = pip.properties.ipAddress
output publicFqdn string = pip.properties.dnsSettings.fqdn
