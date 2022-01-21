Import-Module Az

#if (!$AzureCred) { $AzureCred = Get-Credential -Message "Please enter credentials for Azure"}
#if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) { Connect-AzAccount -Credential $AzureCred -Tenant '4d18e547-6b51-4c00-bf8a-a94237a983fb'}

# Declare variables
#Source Environment
#Common
$Subscription1 = (Get-AzSubscription  | Where-Object {$_.Name -like "1*"})
$Subscription2 = (Get-AzSubscription  | Where-Object {$_.Name -like "2*"})
$Subscription3 = (Get-AzSubscription  | Where-Object {$_.Name -like "3*"})

#Network 
$SourceVnetRGName = "NetworkRG-NorthEU"
#$Location = "northeurope" 
#$Tags= @{Environment="Lab";Project="Azure Migration"}
$SourceVNetName  = "ProdNetwork01-NorthEU"
#$VNet1Prefix = "10.255.0.0/16"
#$GWSubnetPrefix = "10.255.255.0/24"

#VM
$SourceVMRGName = "VMsRG01-NorthEU"
$SourceVMName ="DC-2"
#$SourceVMLocation = "northeurope" 
#$SourceVMTags= @{Environment="Lab";Project="Azure Migration"}

#Target Environment
#Common
$TargetLocation = "northeurope" 
$TargetTags= @{Environment="Lab";Project="Azure Migration"}

#Target Vnet
$TargetVnetRGName = $SourceVnetRGName
#$TargetVNetName  = "ProdVNet1"
#$TargetVnetSubnetName = "ProdSubnet1"
#$TargetVNetPrefix = "10.1.0.0/16"
#$TargetVnetSubnetPrefix = "10.1.1.0/24"

#Target VM
$TargetVMRGName = $SourceVMRGName

#Remove peering between HUB and Prod networks
$Decision = $null
Write-Host "Delete unused route tables?"
$Decision = Read-Host -Prompt " Continue? [y/n]" 
if ( $Decision -match "[yY]" ) 
{   
    Set-AzContext -Subscription $Subscription1.Id 
    Get-AzRouteTable | Remove-AzRouteTable -Force
} 

# Create target resource groups
Set-AzContext -Subscription $Subscription2
if (!($TargetVMRG=Get-AzResourceGroup -Name $TargetVMRGName -ErrorAction SilentlyContinue)) 
{
    $TargetVMRG = New-AzResourceGroup -Name $TargetVMRGName -Location $TargetLocation -Tag $TargetTags 
} 

if (!($TargetVnetRG = Get-AzResourceGroup -Name $TargetVnetRGName -ErrorAction SilentlyContinue)) 
{
    $TargetVnetRG = New-AzResourceGroup -Name $TargetVnetRGName -Location $TargetLocation -Tag $TargetTags 
} 

#Collect Source data
Set-AzContext -Subscription $Subscription1.Id
$SourceVMRG = Get-AzResourceGroup -Name $SourceVMRGName
$SourceVM = Get-AzVM -ResourceGroupName $SourceVMRG.ResourceGroupName -Name $SourceVMName

#Remove peering between HUB and Prod networks
$Decision = $null
Write-Host "Confirm unpeering action?"
$Decision = Read-Host -Prompt " Continue? [y/n]" 
if ( $Decision -match "[yY]" ) 
{    
    #Create Peering
    $VNet1Name  = "HUBVNet"
    $VNet2Name  = "ProdVNet1"
    $VNet1RGName = "NetworkRG-NorthEU"
    $VNet2RGName = "NetworkRG-NorthEU"
    Set-AzContext -Subscription $Subscription1.Id
    $VNet1 = Get-AzVirtualNetwork -ResourceGroupName $VNet1RGName -Name $VNet1Name
    $VNet2 = Get-AzVirtualNetwork -ResourceGroupName $VNet2RGName -Name $VNet2Name
    $VNet1Peering = Get-AzVirtualNetworkPeering -VirtualNetwork $VNet1.Name -ResourceGroupName $VNet1RGName
    $VNet2Peering = Get-AzVirtualNetworkPeering -VirtualNetwork $VNet2.Name -ResourceGroupName $VNet2RGName
    Remove-AzVirtualNetworkPeering -VirtualNetworkName $VNet1Peering.VirtualNetworkName -Name $VNet1Peering.Name -ResourceGroupName $VNet1Peering.ResourceGroupName
    Remove-AzVirtualNetworkPeering -VirtualNetworkName $VNet2Peering.VirtualNetworkName -Name $VNet2Peering.Name -ResourceGroupName $VNet2Peering.ResourceGroupName
} 

#Move ProdVnet to VM resource group in teh source subscription (1), all dependand resources have to migrate simultaneously
$Decision = $null
Write-Host "Move Prod virtual network to VM Resource Group?"
$Decision = Read-Host -Prompt "Continue? [y/n]" 
if ( $Decision -match "[yY]" ) 
{ 
    Set-AzContext -Subscription $Subscription1.Id
    $VNet2 = Get-AzVirtualNetwork -ResourceGroupName $SourceVnetRGName -Name $VNet2Name
    Move-AzResource -DestinationResourceGroupName $SourceVMRG.ResourceGroupName -ResourceId $VNet2.Id -Force
}

#Validate if move of VM and VNet to the target subscription is possible
$Decision = $null
Write-Host "Confirm validateMoveResources acton?"
$Decision = Read-Host -Prompt "Continue? [y/n]" 
if ( $Decision -match "[yY]" ) 
{  
    Set-AzContext -Subscription $Subscription1.Id
    $VNet2 = Get-AzVirtualNetwork -ResourceGroupName $SourceVMRG.ResourceGroupName -Name $VNet2Name
    Invoke-AzResourceAction -Action validateMoveResources `
            -ResourceId  $SourceVMRG.ResourceId `
            -Parameters @{resources=@("/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/VMSRG01-NORTHEU/providers/Microsoft.Compute/disks/DC-2-OSdisk-00",`
                            "/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/VMsRG01-NorthEU/providers/Microsoft.Compute/virtualMachines/DC-2",`
                            "/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/VMsRG01-NorthEU/providers/Microsoft.Network/networkInterfaces/nic-DC-2-00",`
                            "/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/VMsRG01-NorthEU/providers/Microsoft.Network/virtualNetworks/ProdVNet1"); `
                targetResourceGroup = $TargetVMRG.ResourceId } `
            -Force
}

#Register-AzResourceProvider -ProviderNamespace Microsoft.Network
#Register-AzResourceProvider -ProviderNamespace Microsoft.DevTestLab

#Move VM and VNet to the target subscription
$Decision = $null
Write-Host "Confirm MoveResources acton?"
$Decision = Read-Host -Prompt "Continue? [y/n]" 
if ( $Decision -match "[yY]" ) 
{ 
    Set-AzContext -Subscription $Subscription1.Id
    $VNet2 = Get-AzVirtualNetwork -ResourceGroupName $SourceVMRG.ResourceGroupName -Name $VNet2Name
    Move-AzResource -DestinationSubscriptionId $Subscription2.Id `
    -DestinationResourceGroupName $TargetVMRG.ResourceGroupName `
    -ResourceId "/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/VMSRG01-NORTHEU/providers/Microsoft.Compute/disks/DC-2-OSdisk-00",`
                "/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/VMsRG01-NorthEU/providers/Microsoft.Compute/virtualMachines/DC-2",`
                "/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/VMsRG01-NorthEU/providers/Microsoft.Network/networkInterfaces/nic-DC-2-00",`
                "/subscriptions/d8274949-d913-4075-9b9c-d3a839fb5a30/resourceGroups/VMsRG01-NorthEU/providers/Microsoft.Network/virtualNetworks/ProdVNet1" `
    -Force
}

#Move the VNet to its own resource group in the target subscription
$Decision = $null
Write-Host "Move Prod virtual network to its own Resource Group?"
$Decision = Read-Host -Prompt "Continue? [y/n]" 
if ( $Decision -match "[yY]" ) 
{ 
    Set-AzContext -Subscription $Subscription2.Id
    $VNet2 = Get-AzVirtualNetwork -ResourceGroupName $TargetVMRG.ResourceGroupName -Name $VNet2Name
    Move-AzResource ` #The same subscription (Subscription 2)
    -DestinationResourceGroupName $TargetVnetRG.ResourceGroupName ` 
    -ResourceId $VNet2.Id `
    -Force
}
   
#Create an WebAppGateway Subnet (10.254.253.0/24)
$Decision = $null
Write-Host "Create WebAppGateway Subnet with IP-range 10.254.253.0/24 in the HUB Vnet?"
$Decision = Read-Host -Prompt "Continue? [y/n]" 
if ( $Decision -match "[yY]" ) 
{ 
    $Vnet1Subnet2Name = "WebAppGatewaySubnet"
    $Vnet1SubnetName2Prefix = "10.255.254.0/24"
    Set-AzContext -Subscription $Subscription1.Id
    $VNet1 = Get-AzVirtualNetwork -ResourceGroupName $VNet1RGName -Name $VNet1Name    
    Add-AzVirtualNetworkSubnetConfig -Name $Vnet1Subnet2Name -AddressPrefix $Vnet1SubnetName2Prefix -VirtualNetwork $VNet1
    $VNet1|Set-AzVirtualNetwork
}

#Re-Create Peering
#$VNet1Peering = Get-AzVirtualNetworkPeering -VirtualNetwork $VNet1.Name -ResourceGroupName $VNet1RGName
#$VNet2Peering = Get-AzVirtualNetworkPeering -VirtualNetwork $VNet2.Name -ResourceGroupName $VNet2RGName
$Decision = $null
Write-Host "Re-Create Peering?"
$Decision = Read-Host -Prompt "Continue? [y/n]" 
if ( $Decision -match "[yY]" ) 
{ 
    Set-AzContext -Subscription $Subscription2.Id
    $VNet2 = Get-AzVirtualNetwork -ResourceGroupName $VNet2RGName -Name $VNet2Name
    Set-AzContext -Subscription $Subscription1.Id
    $VNet1 = Get-AzVirtualNetwork -ResourceGroupName $VNet1RGName -Name $VNet1Name 
    $PeeringNameD  =($VNet1Name+"to"+$VNet2Name+"Peering") 
    $PeeringNameR  =($VNet2Name+"to"+$VNet1Name+"Peering")
    Add-AzVirtualNetworkPeering -Name $PeeringNameD -VirtualNetwork $VNet1 -RemoteVirtualNetworkId $VNet2.Id -AllowGatewayTransit:$true -AllowForwardedTraffic:$true
    Set-AzContext -Subscription $Subscription2.Id
    Add-AzVirtualNetworkPeering -Name $PeeringNameR -VirtualNetwork $VNet2 -RemoteVirtualNetworkId $VNet1.Id -UseRemoteGateways:$true -AllowForwardedTraffic:$true
}