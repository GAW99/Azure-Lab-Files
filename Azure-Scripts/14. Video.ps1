Import-Module Az

if (!$AzureCred) { $AzureCred = Get-Credential -Message "Please enter credentials for Azure"}
if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) { Connect-AzAccount -Credential $AzureCred }

# Declare variables
#Resource Group
$SubscriptionNum = 1
$RGName = "NetworkRG-NorthEU"
$Location = "northeurope" 
$Tags= @{Environment="Lab";Project="Azure Migration"}

#Vnet1
$VNet1Name  = "HUBVNet"
$GWSubnetName = "GatewaySubnet"
$VNet1Prefix = "10.255.0.0/16"
$GWSubnetPrefix = "10.255.255.0/24"

#Vnet2
$VNet2Name  = "ProdVNet1"
$Vnet2SubnetName = "ProdSubnet1"
$VNet2Prefix = "10.1.0.0/16"
$Vnet2SubnetNamePrefix = "10.1.1.0/24"

#VPN
$GWName = "HUBVNetGW"
$GWIPName = "HUBVNetGWIP"
$GWIPconfName = "HUBVNetGWIPConf"
$LocalGWName = "MainOffice"
$LocalGWIP = "95.31.43.64"
$LocalNetworkAddressPool = @("172.16.0.0/16")
$VPNConnectionName = ($VNet1Name+"to"+$LocalGWName)
if (!$NotSecureVPNSharedKey) {$SecureVPNSharedKey = Read-Host -AsSecureString -Prompt "Please, enter the VPN shared key !"}
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureVPNSharedKey)
$NotSecureVPNSharedKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

#Switch to the correct subscription
$Subscription = (Get-AzSubscription  | Where-Object {$_.Name -like "$SubscriptionNum*"})
Set-azcontext -Subscription $Subscription.Id

# Create a resource group
$RG = New-AzResourceGroup -Name $RGName -Location $Location -Tag $Tags 

# Create a subnet configuration
$GWSubnet = New-AzVirtualNetworkSubnetConfig -Name $GWSubnetName -AddressPrefix $GWSubnetPrefix 

# Create a virtual network                          !!!! Name !!!!!
$VNet1 = New-AzVirtualNetwork -ResourceGroupName $RG.ResourceGroupName -Location $Location -Name $VNet1Name -AddressPrefix $VNet1Prefix -Tag $Tags -Subnet $GWSubnet 

# Request a public IP address
$GWIP= New-AzPublicIpAddress -Name $GWIPName -ResourceGroupName $RG.ResourceGroupName -Location $Location -AllocationMethod Dynamic -Sku Basic -Tag $Tags

# Create the gateway IP address configuration
$GWSubnet = Get-AzVirtualNetworkSubnetConfig -Name $GWSubnetName -VirtualNetwork $VNet1
$GWIPconf = New-AzVirtualNetworkGatewayIpConfig -Name $GWIPconfName -SubnetId $GWSubnet.Id -PublicIpAddressId $GWIP.Id 

# Create the VPN gateway
$GW = New-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RG.ResourceGroupName `
        -Location $Location -IpConfigurations $GWIPconf `
        -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1 -Tag $Tags

# Create the Local network gateway
$LocalGW = New-AzLocalNetworkGateway -Name $LocalGWName -ResourceGroupName $RG.ResourceGroupName `
            -Location $Location -GatewayIpAddress $LocalGWIP -AddressPrefix $LocalNetworkAddressPool -Tag $Tags 

# Create the VPN connection
$VPNConnection = New-AzVirtualNetworkGatewayConnection -Name $VPNConnectionName -ResourceGroupName $RG.ResourceGroupName `
-Location $Location -VirtualNetworkGateway1 $GW -LocalNetworkGateway2 $LocalGW `
-ConnectionType IPsec -ConnectionProtocol IKEv2 -RoutingWeight 10 -SharedKey $NotSecureVPNSharedKey

# Create the producrion subnet configuration
$Vnet2Subnet = New-AzVirtualNetworkSubnetConfig -Name $Vnet2SubnetName -AddressPrefix $Vnet2SubnetNamePrefix 

# Create a virtual network                          !!!! Name !!!!!
$VNet2 = New-AzVirtualNetwork -ResourceGroupName $RG.ResourceGroupName -Location $Location -Name $VNet2Name -AddressPrefix $VNet2Prefix -Tag $Tags -Subnet $Vnet2Subnet

#Create Peering
$PeeringNameD  =($VNet1Name+"to"+$VNet2Name+"Peering")      #  Object....                        ID!!!!
Add-AzVirtualNetworkPeering -Name $PeeringNameD -VirtualNetwork $VNet1 -RemoteVirtualNetworkId $VNet2.Id -AllowGatewayTransit:$true -AllowForwardedTraffic:$true 
$PeeringNameR  =($VNet2Name+"to"+$VNet1Name+"Peering")
Add-AzVirtualNetworkPeering -Name $PeeringNameR -VirtualNetwork $VNet2 -RemoteVirtualNetworkId $VNet1.Id -UseRemoteGateways:$true -AllowForwardedTraffic:$true

#Create a route
$Route1 = New-AzRouteConfig -NextHopType VirtualNetworkGateway -Name "To_172.16.1.0" -AddressPrefix "172.16.1.0/24"
$Route2 = New-AzRouteConfig -NextHopType VirtualNetworkGateway -Name "To_172.16.201.0" -AddressPrefix "172.16.201.0/24"

#Creating a route table
$VNet1RoutingTable = New-AzRouteTable -Name $($VNet1Name+"RouingTable") -Tag $Tags -ResourceGroupName $RG.ResourceGroupName -Location $Location -Route $Route1,$Route2
$VNet2RoutingTable = New-AzRouteTable -Name $($VNet2Name+"RouingTable") -Tag $Tags -ResourceGroupName $RG.ResourceGroupName -Location $Location -Route $Route1,$Route2

#Change a route table
#Set-AzRouteTable

#Associate a route table
#Set-AzVirtualNetworkSubnetConfig -RouteTable $VNet2RoutingTable -VirtualNetwork $VNet2 -Name $Vnet2SubnetName -AddressPrefix $Vnet2SubnetNamePrefix
#$VNet2| Set-AzVirtualNetwork

#View effective routes (only for a network interface)
#Get-AzEffectiveRouteTable

#Validate routing between two endpoints
#Get-AzNetworkWatcherNextHop

#Change DNS Server for a Virtual network
$VNet2.DhcpOptions.DnsServers = "172.16.201.65"
$VNet2 | Set-AzVirtualNetwork