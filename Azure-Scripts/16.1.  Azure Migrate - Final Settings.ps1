Import-Module Az

if (!$AzureCred) { $AzureCred = Get-Credential -Message "Please enter credentials for Azure"}
if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) { Connect-AzAccount -Credential $AzureCred }

# Declare variables
#VNet Resource Group
$VNet2SubsNum = 1
$VNet2RGName = "NetworkRG-NorthEU"
$VNet2Name  = "ProdVNet1"
$VNet2Location = "northeurope" 

#Switch to the VNet subscription
$VNet2Subs = (Get-AzSubscription  | Where-Object {$_.Name -like "$VNet2SubsNum*"})
Set-azcontext -Subscription $VNet2Subs.Id

#Get Network resource group
$VNet2RG = Get-AzResourceGroup -Name $VNet2RGName -Location $VNet2Location

#Get VNetNet
$VNet2 = Get-AzVirtualNetwork -Name $VNet2Name -ResourceGroupName $VNet2RG.ResourceGroupName 
$VNet2

# Declare variables
#VM Resource Group

#Resource Group for VMs
$TargSubsNum = 1
$TargRGName = "VMsRG01-NorthEU"
$TargLocation = "northeurope" 
$TargTags= @{Environment="Lab";Project="Azure Migration"}

#List of Targ to migrate
$VMName = "DC-2"

#Switch to the VM subscription
$TargSubs = (Get-AzSubscription  | Where-Object {$_.Name -like "$TargSubsNum*"})
Set-azcontext -Subscription $TargSubs.Id

#Get Network resource group
$TargRG = Get-AzResourceGroup -Name $TargRGName -Location $TargLocation

#Get VM config 
$TargVM = Get-AzVM -Name $VMName -ResourceGroupName $TargRG.ResourceGroupName 
$TargVM

$NIC = Get-AzNetworkInterface -ResourceId $TargVM.NetworkProfile.NetworkInterfaces.id

$NIC.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
$NIC | Set-AzNetworkInterface 

#Change DNS Server for a Virtual network
$VNet2.DhcpOptions.DnsServers += $NIC.IpConfigurations[0].PrivateIpAddress
$VNet2 | Set-AzVirtualNetwork

Update-azVM -VM $TargVM -Tag $TargTags -ResourceGroupName $TargRG.ResourceGroupName 
