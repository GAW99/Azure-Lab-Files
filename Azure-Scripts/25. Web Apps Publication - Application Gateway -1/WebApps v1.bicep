@allowed([
          'northeurope'
          'westeurope'
          'ukwest'
          'uksouth'
        ])
param location string = 'northeurope'

@maxLength(10)
@minLength(3)
@description('Prefix will be used in names of resources')
param service string 

var appgw_id = resourceId('Microsoft.Network/applicationGateways', '${service}_AppGW')

resource sa 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: 'testbicepstatic'
  scope: resourceGroup('05c55d9c-2fdd-49ca-9011-4dc4a28d50a5','TestingStaticWeb')
}

output endpoint string = sa.properties.primaryEndpoints.web

resource virtualnetname 'Microsoft.Network/virtualNetworks@2021-05-01' existing  = {
  name: 'HUBVNet'  
  scope: resourceGroup('d8274949-d913-4075-9b9c-d3a839fb5a30','NetworkRG-NorthEU')
    resource Subnet 'subnets@2021-05-01' existing ={
      name: 'WebAppGatewaySubnet'
    }    
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: '${service}_PublicIP'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Dynamic'    
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: '${service}_AppGW'
  location: location
  properties: {    
    sku: {
      name: 'Standard_Small'
      tier: 'Standard'
      capacity: 1      
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {          
          subnet: {
            //id: resourceId('virtualnetname::Microsoft.Network/virtualNetworks/subnets', virtualnetname.id, 'WebAppGatewaySubnet')
            id: '/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/NetworkRG-NorthEU/providers/Microsoft.Network/virtualNetworks/HUBVNet/subnets/WebAppGatewaySubnet'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: '${service}_PublicFrontendIp'
        properties: {          
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', publicIPAddress.name)
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'HTTP80'
        properties: {
          port: 80
        }
      }
      {
        name: 'HTTPS443'
        properties:{
          port: 443          
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'SSLBackend2'
        properties: {          
          backendAddresses: [
            {              
              fqdn: replace(replace(sa.properties.primaryEndpoints.web,'https://',''),'/','')
              // 'https://testbicepstatic.z16.web.core.windows.net/'
            }
            {
              fqdn:'ca.gaw00.tk'
            }
          ]
        }
      }
      {
        name: 'SSLBackend1'
        properties:{
          backendAddresses:[
            {
              fqdn: 'ca.gaw00.tk'
            }
          ]
        }
      }
      {
        name: 'HTTPBackend'
        properties:{          
          backendAddresses:[
            {
              fqdn: 'DC-1.gaw00.local'
            }
          ]
        }
      }
    ]
    probes:[
      {
        name:'StaticSiteProbe1'        
        properties:{
          pickHostNameFromBackendHttpSettings: true
          path: '/iisstart.htm'
          protocol: 'Https'     
          timeout: 30
          interval:30
          unhealthyThreshold: 5          
        }
      }
    ]    
    backendHttpSettingsCollection: [
      {
        name: 'HTTPSetting'        
        properties: {          
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20                  
        }
      }
      {
        name: 'HTTPSSettings_ext'
        properties:{
          protocol: 'Https'
          port: 443
          pickHostNameFromBackendAddress: true           
          probe:{
            id: '${appgw_id}/probes/StaticSiteProbe1'
          }
          authenticationCertificates: [
            {
              id: '${appgw_id}/authenticationCertificates/StaticSiteCRT'                          
            }
            {
              id: '${appgw_id}/authenticationCertificates/WildName' 
            }
          ]
        }
      }  
      {
        name: 'HTTPSSettings_int'
        properties:{
          protocol: 'Https'
          port: 443
          pickHostNameFromBackendAddress: true                   
          probe:{
            id: '${appgw_id}/probes/StaticSiteProbe1'
          }
          authenticationCertificates: [
            {
              id: '${appgw_id}/authenticationCertificates/WildName'                          
            }
            {
              id: '${appgw_id}/authenticationCertificates/StaticSiteCRT'                          
            }
          ]
        }
      }      
    ]
    authenticationCertificates:[
      {
        name: 'StaticSiteCRT'
        properties:{
          data: 'MIITQzCCESugAwIBAgITfwAi3XpHoV3XiCMtGAAAACLdejANBgkqhkiG9w0BAQsFADBPMQswCQYDVQQGEwJVUzEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSAwHgYDVQQDExdNaWNyb3NvZnQgUlNBIFRMUyBDQSAwMjAeFw0yMjAyMDUwOTI4MTJaFw0yMzAyMDUwOTI4MTJaMCExHzAdBgNVBAMMFioud2ViLmNvcmUud2luZG93cy5uZXQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCo+qX3FZlK1jz4QquAYAyKW1zLU5rVcm5aMpmVAC4M+LCAogh9aUCviZi9x41sNm0phCRkGH/KpZTdMui61G0LG4LQW4ONPKWdi2RBfAzEDfBjyQtTFENratRG6AJ8NggJim2wv5qBmXsioNH+cFdR53SaaXqYKkizyz0/wHffH9rTrnxzk6BcL/73b3oDZMm1gorxln3LEzYlciI/wwVRAEipWrd7i892ihGQN7Cktp3lCUOqzMI6rLcYVcjck4+ziZ4KpSKLDL2KyJr2SafAOXk+ulhNGlMyZpcFGADWS7P7+LLFOdKKvW7nTfGaDmaV4ialGE9BlZ4ybtToHkXZAgMBAAGjgg9EMIIPQDCCAXwGCisGAQQB1nkCBAIEggFsBIIBaAFmAHYA6D7Q2j71BjUy51covIlryQPTy9ERa+zraeF3fW0GvW4AAAF+yT+g1QAABAMARzBFAiEAslrp+3PrUe455lpbxI0NL+WnH9q7I7p3R606N/1VZ3MCIDyb0Ll0vC38N7eEau8zB1EmkVo+PHGicEYGkBOc8V2ZAHUAs3N3B+GEUPhjhtYFqdwRCUp5LbFnDAuH3PADDnk2pZoAAAF+yT+gRwAABAMARjBEAiAa3/XlJyn+itjp2xeY4yG0NuuhzhVVLg7+zuFPWMm+swIgKYFrT961fhGxrLUpTfudM3bbmwh4RMz837vFV3PzSJgAdQBVgdTCFpA2AUrqC5tXPFPwwOQ4eHAlCBcvo6odBxPTDAAAAX7JP5/5AAAEAwBGMEQCIF6vbtdpkayWpRmB78rgL8XEv1AsLvz3vkUyhEGeCN3sAiBvtuUENtzgqcNi5O2G6fgmJ9j/016tAuMs3zawKkpxHTAnBgkrBgEEAYI3FQoEGjAYMAoGCCsGAQUFBwMBMAoGCCsGAQUFBwMCMD4GCSsGAQQBgjcVBwQxMC8GJysGAQQBgjcVCIfahnWD7tkBgsmFG4G1nmGF9OtggV2Fho5Bh8KYUAIBZAIBJzCBhwYIKwYBBQUHAQEEezB5MFMGCCsGAQUFBzAChkdodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL21zY29ycC9NaWNyb3NvZnQlMjBSU0ElMjBUTFMlMjBDQSUyMDAyLmNydDAiBggrBgEFBQcwAYYWaHR0cDovL29jc3AubXNvY3NwLmNvbTAdBgNVHQ4EFgQUR9O+zgsuTST3zn66zWEYIsu4KMgwDgYDVR0PAQH/BAQDAgSwMIILTgYDVR0RBIILRTCCC0GCFioud2ViLmNvcmUud2luZG93cy5uZXSCGSouejEud2ViLmNvcmUud2luZG93cy5uZXSCGSouejIud2ViLmNvcmUud2luZG93cy5uZXSCGSouejMud2ViLmNvcmUud2luZG93cy5uZXSCGSouejQud2ViLmNvcmUud2luZG93cy5uZXSCGSouejUud2ViLmNvcmUud2luZG93cy5uZXSCGSouejYud2ViLmNvcmUud2luZG93cy5uZXSCGSouejcud2ViLmNvcmUud2luZG93cy5uZXSCGSouejgud2ViLmNvcmUud2luZG93cy5uZXSCGSouejkud2ViLmNvcmUud2luZG93cy5uZXSCGiouejEwLndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnoxMS53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56MTIud2ViLmNvcmUud2luZG93cy5uZXSCGiouejEzLndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnoxNC53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56MTUud2ViLmNvcmUud2luZG93cy5uZXSCGiouejE2LndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnoxNy53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56MTgud2ViLmNvcmUud2luZG93cy5uZXSCGiouejE5LndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnoyMC53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56MjEud2ViLmNvcmUud2luZG93cy5uZXSCGiouejIyLndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnoyMy53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56MjQud2ViLmNvcmUud2luZG93cy5uZXSCGiouejI1LndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnoyNi53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56Mjcud2ViLmNvcmUud2luZG93cy5uZXSCGiouejI4LndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnoyOS53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56MzAud2ViLmNvcmUud2luZG93cy5uZXSCGiouejMxLndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnozMi53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56MzMud2ViLmNvcmUud2luZG93cy5uZXSCGiouejM0LndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnozNS53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56MzYud2ViLmNvcmUud2luZG93cy5uZXSCGiouejM3LndlYi5jb3JlLndpbmRvd3MubmV0ghoqLnozOC53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56Mzkud2ViLmNvcmUud2luZG93cy5uZXSCGiouejQwLndlYi5jb3JlLndpbmRvd3MubmV0ghoqLno0MS53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56NDIud2ViLmNvcmUud2luZG93cy5uZXSCGiouejQzLndlYi5jb3JlLndpbmRvd3MubmV0ghoqLno0NC53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56NDUud2ViLmNvcmUud2luZG93cy5uZXSCGiouejQ2LndlYi5jb3JlLndpbmRvd3MubmV0ghoqLno0Ny53ZWIuY29yZS53aW5kb3dzLm5ldIIaKi56NDgud2ViLmNvcmUud2luZG93cy5uZXSCGiouejQ5LndlYi5jb3JlLndpbmRvd3MubmV0ghoqLno1MC53ZWIuY29yZS53aW5kb3dzLm5ldIIXKi53ZWIuc3RvcmFnZS5henVyZS5uZXSCGiouejEud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghoqLnoyLndlYi5zdG9yYWdlLmF6dXJlLm5ldIIaKi56My53ZWIuc3RvcmFnZS5henVyZS5uZXSCGiouejQud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghoqLno1LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIaKi56Ni53ZWIuc3RvcmFnZS5henVyZS5uZXSCGiouejcud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghoqLno4LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIaKi56OS53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejEwLndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56MTEud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnoxMi53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejEzLndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56MTQud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnoxNS53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejE2LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56MTcud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnoxOC53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejE5LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56MjAud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnoyMS53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejIyLndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56MjMud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnoyNC53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejI1LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56MjYud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnoyNy53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejI4LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56Mjkud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnozMC53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejMxLndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56MzIud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnozMy53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejM0LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56MzUud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnozNi53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejM3LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56Mzgud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLnozOS53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejQwLndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56NDEud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLno0Mi53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejQzLndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56NDQud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLno0NS53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejQ2LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56NDcud2ViLnN0b3JhZ2UuYXp1cmUubmV0ghsqLno0OC53ZWIuc3RvcmFnZS5henVyZS5uZXSCGyouejQ5LndlYi5zdG9yYWdlLmF6dXJlLm5ldIIbKi56NTAud2ViLnN0b3JhZ2UuYXp1cmUubmV0MIGwBgNVHR8EgagwgaUwgaKggZ+ggZyGTWh0dHA6Ly9tc2NybC5taWNyb3NvZnQuY29tL3BraS9tc2NvcnAvY3JsL01pY3Jvc29mdCUyMFJTQSUyMFRMUyUyMENBJTIwMDIuY3JshktodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL21zY29ycC9jcmwvTWljcm9zb2Z0JTIwUlNBJTIwVExTJTIwQ0ElMjAwMi5jcmwwVwYDVR0gBFAwTjBCBgkrBgEEAYI3KgEwNTAzBggrBgEFBQcCARYnaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9tc2NvcnAvY3BzMAgGBmeBDAECATAfBgNVHSMEGDAWgBT/L3/hBvQ48y3tJY2Ywv4O9mz8+jAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDQYJKoZIhvcNAQELBQADggIBAFdZmxPX+uIUHKTYi1QboNBXYfv9MF7CU4XSXA/wC+YdLe3e/j48WG8w6JxLMHJ50kwo/fiecuTTwD4VQAKRWVN7Es3Rca9XRa7iWL2wNJXSXyAIx6GsGO29aRh3gzJw4GiCjGe31YPO1JZJm3GWfMT2wovs08T8xuUJY6jdLVQJ2K/3xiq3jFMhgzr08Q1++LUk6SCnts2jvc3ddiUMaR40LliGqyyfJqSHD3nZjPz117csagjkBxM9VUyT/WvzylaMC9pRFS+F9vC2ZpG6DNjU6nJ9Fg1cdcRfEk9vqg8t57wX4VCdS+E60dH9czUXl7CDhj6yhZInm5xcQ/8CIk7QvKpYjCGBba5i0v7xPieXPtoyc7OpOfeCwDX6tIimAVHavyw2qqD531Xo/3Di3iBU0N0Y69AIrIkc9tpt4OxWU61obJoBgl9F07/aP50RedOCbIytvs9LydFsblQ6G/AD7Hrg+FUjXKJ6V4p156vqUgnCtJTMof7L8o6p0l7rh3LySaTN5u0J3PUoR/GfzSP6Zc9/BK8ubHYpCtnfkiEjlPIysa4Y1pYI89U0/QX8zaY86D3tCsvEC9YGxbVFkG2RaZEReXk0OOAZCx0jisRO0fv73arKNnh89dnL1/tnKbYwlKK5b0El0iMjGYt26YGqOnrIaLyq67WaqGt1jyO7'
        }
      }
      {
        name: 'WildName'
        properties:{
          data: 'MIIFGjCCBAKgAwIBAgISA341bfvZO4crGotsFmc3NPRTMA0GCSqGSIb3DQEBCwUAMDIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQDEwJSMzAeFw0yMjAyMTQwOTA3MzRaFw0yMjA1MTUwOTA3MzNaMBUxEzARBgNVBAMMCiouZ2F3MDAudGswggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCODm20FY7AZmDJ9ywoTpbV0QKDlsF3rtaGMDuDlhtx5NWky/gxULqARvosJQ3Apc2FtHFxT0VzIkM2qlAR9/bZuY/FzeZ0Tf44kvXyupvfSMCUDbY2hvoEA5vsC5aMqpYnEEOQkG576EozEojZrARbGuhfrpgyGRAJwfmfIBdd+XJMvZ0PzNeD5jB3IsJ7ebOP5hXQv84U6cNC8c/seYf2v7d+aQhflt+ocBevyMT+WMNFL8tWnwgrh0mNvw86YW7O+9eHUT8bvO50SlxAlfxaGcg3M6NsRQZAJyxyccgEUtiPXPtNlZuRTzI+VprA7/iRt0+WxKktlxdzixQvDdsJAgMBAAGjggJFMIICQTAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFKJHZ64qCQJYP0/INOphCjtPtCjDMB8GA1UdIwQYMBaAFBQusxe3WFbLrlAJQOYfr52LFMLGMFUGCCsGAQUFBwEBBEkwRzAhBggrBgEFBQcwAYYVaHR0cDovL3IzLm8ubGVuY3Iub3JnMCIGCCsGAQUFBzAChhZodHRwOi8vcjMuaS5sZW5jci5vcmcvMBUGA1UdEQQOMAyCCiouZ2F3MDAudGswTAYDVR0gBEUwQzAIBgZngQwBAgEwNwYLKwYBBAGC3xMBAQEwKDAmBggrBgEFBQcCARYaaHR0cDovL2Nwcy5sZXRzZW5jcnlwdC5vcmcwggEEBgorBgEEAdZ5AgQCBIH1BIHyAPAAdgDfpV6raIJPH2yt7rhfTj5a6s2iEqRqXo47EsAgRFwqcwAAAX73s64pAAAEAwBHMEUCIQDgPk5ATzmq/cpOERCzQi80zEIVmxIqakJXvUgGVGMl5wIgNM7dr5jGvfimvFlUl9PuHzUxZFKRcXxQnTep1uT1MswAdgBGpVXrdfqRIDC1oolp9PN9ESxBdL79SbiFq/L8cP5tRwAAAX73s65RAAAEAwBHMEUCIQCIOdmnYlttLw5L99UIMP5ueO4Kb9CaoXwQ2R6/qFo/agIgEX36DizdKBbjhGA8ENW+tAQ66t7ly94tY4EsFzO6iG8wDQYJKoZIhvcNAQELBQADggEBAErDhvkrq5HyWuTsgbW9R1CcTr23+wCI96mw23iWzVwLM+aiB6uFMIH93upA31i8sGiFwsdqwXjXtZyEogwJMktA5hbmO9UXgSMuo+RGwoy8xmP+skySqguD4GIZJdWENM3xPCwjI2O7uE3tXoMrCLbSU3a/0RG6dhLiMBDiZJZhMkcKIVZjc0I/CibQSwELCD6kGrAALA2iPAOxbABym1ehd6X4gV/9Vc75JrogEw4lZIodvOQ5JDWOPctuXCuuR+azNdseDGAowSv94zhaYz78+KdUsiYzTSGjG3lNPf7G4pzZdgT4YrnSLAuPiRcARs2o85o5sy+GfkiRsiTYKDk='
        }
      }
    ]         
    sslCertificates:[
       {
         name: 'WildName'
         properties:{
           data: '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'
           password: '1'
          }
       }
    ]     
    httpListeners: [
      {
        name: 'Listener80'
        properties: {            
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', '${service}_AppGW', '${service}_PublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', '${service}_AppGW', 'HTTP80')
          }
          protocol: 'Http'
          requireServerNameIndication: false          
        }
      }
      {
        name: 'Listener443_int'  
        properties:{
          hostName: 'webappsgw_int.gaw00.tk'
          frontendIPConfiguration:{
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', '${service}_AppGW', '${service}_PublicFrontendIp')
          }
          frontendPort: {
            id:resourceId('Microsoft.Network/applicationGateways/frontendPorts', '${service}_AppGW', 'HTTPS443')            
          }
          protocol: 'Https'
          sslCertificate:{
            id: '${appgw_id}/sslCertificates/WildName'
          }
        }
      }
      {
        name: 'Listener443_ext'  
        properties:{
          hostName: 'webappsgw_ext.gaw00.tk'
          frontendIPConfiguration:{
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', '${service}_AppGW', '${service}_PublicFrontendIp')
          }
          frontendPort: {
            id:resourceId('Microsoft.Network/applicationGateways/frontendPorts', '${service}_AppGW', 'HTTPS443')            
          }
          protocol: 'Https'
          sslCertificate:{
            id: '${appgw_id}/sslCertificates/WildName'
          }
        }
      }
    ]    
    requestRoutingRules: [
      {
        name: 'HTTPRoutingRule'
        properties: {          
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', '${service}_AppGW', 'Listener80')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${service}_AppGW', 'HTTPBackend')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', '${service}_AppGW', 'HTTPSetting')
          }
        }
      }
      {        
        name: 'SSLRoutingRule_int'
        properties:{
          ruleType: 'Basic'                 
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${service}_AppGW', 'SSLBackend1')
          }
          backendHttpSettings: {                                                                                      
            id:resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', '${service}_AppGW', 'HTTPSSettings_int')
          }
          httpListener:{
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', '${service}_AppGW', 'Listener443_int')
          }
        }
      }
      {        
        name: 'SSLRoutingRule_ext'
        properties:{
          ruleType: 'Basic' 
           backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', '${service}_AppGW', 'SSLBackend2')
          }
          backendHttpSettings: {                                                                                      
            id:resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', '${service}_AppGW', 'HTTPSSettings_ext')
          }
          httpListener:{
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', '${service}_AppGW', 'Listener443_ext')
          }
        }
      }
    ]
    enableHttp2: false    
  }
  dependsOn: [
    virtualnetname
    //publicIPAddress
  ]
}

