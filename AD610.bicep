// Paramenter
// Username for the Virtual Machine.
param ADAdminUsername string = 'ad-adm'
param LocalUserName string = 'local-adm'
// Location for all resources.
param location string = resourceGroup().location
// The name of your Virtual Machine.
param VMDcName string = 'tstew1sapad'
param VMDbName string = 'tstew1sapdb'
param VMAppName string = 'tstew1sapapp'
// Name of the VNET.
param virtualNetworkName string = 'saplab-vnet'
// Name of the subnet in the virtual network.
param Frontend string = 'frontend'
param Backend string = 'backend'

//Variables
var extensionName = 'GuestAttestation'
var extensionPublisher = 'Microsoft.Azure.Security.WindowsAttestation'
var extensionVersion = '1.0'
var maaTenantName = 'GuestAttestation'
var maaEndpoint = substring('emptyString', 0, 0)

//Resources

resource PublicIp 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: '${VMDcName}PublicIP'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
      }
}

resource NSGFrontend 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'NSG-Frontend'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDPFromInet'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          protocol: 'Tcp'
          destinationPortRange: '3389'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource NSGBackend 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'NSG-Backend'
  location: location
}

resource saplabvnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'saplab-vnet'
  location: location
  properties: {
    addressSpace: {
       addressPrefixes: [
        '10.0.0.0/16'
       ]
    }
    subnets: [
      {
        name: 'frontend'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: NSGFrontend.id
          }
        }
      }
      {
        name: 'backend'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: NSGBackend.id
          }
        }
      }
    ]
  }
}

resource VMDcNIC 'Microsoft.Network/networkInterfaces@2022-09-01' = {
  name: '${VMDcName}NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Static'
            privateIPAddress: '10.0.0.4'
            publicIPAddress: {
              id: PublicIp.id
            }
            subnet: {
              id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, Frontend  )
            }
          }
      }
    ]
  }
  dependsOn: [
    saplabvnet
  ]
}

resource VMAppNIC 'Microsoft.Network/networkInterfaces@2022-09-01' = {
  name: '${VMAppName}NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Static'
            privateIPAddress: '10.0.1.4'
            subnet: {
              id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, Backend  )
            }
          }
      }
    ]
  }
  dependsOn: [
    saplabvnet
  ]
}

resource VMDbNIC 'Microsoft.Network/networkInterfaces@2022-09-01' = {
  name: '${VMDbName}NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Static'
            privateIPAddress: '10.0.1.5'
            subnet: {
              id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, Backend  )
            }
          }
      }
    ]
  }
  dependsOn: [
    saplabvnet
  ]
}

resource DCVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: VMDcName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2ds_v5'
    }
    osProfile: {
      computerName: VMDcName
      adminUsername: ADAdminUsername
      adminPassword: 'AD661!Pa55w.rd'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: VMDcNIC.id
        }
      ]
    }
  }
}

resource AppVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: VMAppName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2ds_v5'
    }
    osProfile: {
      computerName: VMDcName
      adminUsername: LocalUserName
      adminPassword: 'AD661!Pa55w.rd'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 128
          lun: 0
          createOption: 'Empty'
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: VMAppNIC.id
        }
      ]
    }
  }
}

resource DbVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: VMDbName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_E8-4ads_v5'
    }
    osProfile: {
      computerName: VMDcName
      adminUsername: LocalUserName
      adminPassword: 'AD661!Pa55w.rd'
    }
    storageProfile: {
      imageReference: {
        publisher: 'suse'
        offer: 'sles-15-sp4'
        sku: 'gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 50
          lun: 0
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        {
          diskSizeGB: 50
          lun: 1
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        {
          diskSizeGB: 50
          lun: 2
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
        {
          diskSizeGB: 50
          lun: 3
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: VMDbNIC.id
        }
      ]
    }
  }
}

resource DcExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: DCVm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: maaEndpoint
          maaTenantName: maaTenantName
        }
      }
    }
  }
}

resource AppExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: AppVm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: maaEndpoint
          maaTenantName: maaTenantName
        }
      }
    }
  }
}
