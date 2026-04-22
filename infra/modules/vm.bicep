@description('Azure region.')
param location string

@description('Resource tags.')
param tags object

param vmName string
param vmSize string
param adminUsername string

@secure()
param adminPassword string

param nicId string

param sqlAdminLogin string

@secure()
param sqlAdminPassword string

param entraAdminLoginName string

var imageReference = {
  publisher: 'MicrosoftSQLServer'
  offer: 'sql2022-ws2022'
  sku: 'sqldev-gen2'
  version: 'latest'
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          lun: 0
          name: '${vmName}-data'
          createOption: 'Empty'
          diskSizeGB: 128
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        {
          lun: 1
          name: '${vmName}-log'
          createOption: 'Empty'
          diskSizeGB: 64
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
        }
      ]
    }
  }
}

// SQL IaaS Agent registration (Full mode) — Azure manages SQL config, enables mixed-mode
// auth, configures storage pools, and publishes the SQL VM as an Azure resource.
resource sqlVm 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2023-10-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    virtualMachineResourceId: vm.id
    sqlManagement: 'Full'
    sqlImageSku: 'Developer'
    serverConfigurationsManagementSettings: {
      sqlConnectivityUpdateSettings: {
        connectivityType: 'PUBLIC'
        port: 1433
        sqlAuthUpdateUserName: sqlAdminLogin
        sqlAuthUpdatePassword: sqlAdminPassword
      }
      sqlWorkloadTypeUpdateSettings: {
        sqlWorkloadType: 'GENERAL'
      }
      additionalFeaturesServerConfigurations: {
        isRServicesEnabled: false
      }
    }
    storageConfigurationSettings: {
      diskConfigurationType: 'NEW'
      sqlDataSettings: {
        luns: [ 0 ]
        defaultFilePath: 'F:\\data'
      }
      sqlLogSettings: {
        luns: [ 1 ]
        defaultFilePath: 'G:\\log'
      }
    }
    autoPatchingSettings: {
      enable: true
      dayOfWeek: 'Sunday'
      maintenanceWindowStartingHour: 2
      maintenanceWindowDuration: 60
    }
  }
}

// Bootstrap via Run Command: restore AdventureWorksLT and grant Entra UPN sysadmin.
// The script is loaded at compile time from scripts/bootstrap-sql.ps1 so the PowerShell
// stays readable and Bicep doesn't have to escape a one-liner.
resource bootstrap 'Microsoft.Compute/virtualMachines/runCommands@2024-07-01' = {
  parent: vm
  name: 'bootstrap-sql'
  location: location
  properties: {
    source: {
      script: loadTextContent('../../scripts/bootstrap-sql.ps1')
    }
    parameters: [
      {
        name: 'EntraAdminUpn'
        value: entraAdminLoginName
      }
    ]
    timeoutInSeconds: 1800
    treatFailureAsDeploymentFailure: false
  }
  dependsOn: [
    sqlVm
  ]
}

output vmPrincipalId string = vm.identity.principalId
