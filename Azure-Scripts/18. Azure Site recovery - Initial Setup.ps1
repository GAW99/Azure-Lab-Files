Import-Module Az

if (!$AzureCred) { $AzureCred = Get-Credential -Message "Please enter credentials for Azure"}
if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) { Connect-AzAccount -Credential $AzureCred }

# Declare variables
#Resource Group for a Recovery Services vault
$DRSubsNum = 3 
$DRRGName = "DRRG-NorthEU"
$DRLocation = "northeurope" 
$DRTags= @{Environment="Lab";Project="Azure Disaster Recovery"}
$DRServiceVaultName = "DRVMwareToAzure6"
$DRFilePath = "C:\distr"
$StraightReplPolicyName = "InfrastructureReplicationPolicy"
$ReverseReplPolicyName = "InfrastructureFailbackReplicationPolicy"
$DRLogStorageAccountName = "oosdisasterecoverylogs"

#Resource Group for VMs
$TargSubsNum = 1
$TargRGName = "VMsRG02-NorthEU"
$TargLocation = "northeurope" 
$TargTags= @{Environment="Lab";Project="Azure Disaster Recovery"}

#List of Targ to migrate
$VMName= "OOS-1"
$TargVNetName = "ProdVNet1" 
$TargSubnetName = "ProdSubnet1"

#Migration Project
$DRProjectName = "OOSDRProject"

#Create resources for target VMs
$TargSubs = (Get-AzSubscription  | Where-Object {$_.Name -like "$TargSubsNum*"})
Set-AzContext -Subscription $TargSubs.Id

#Get the target resource group to be used
#$TargRG = New-AzResourceGroup -Name $TargRGName -Location $TargLocation -Tag $DRTags 
$TargRG = Get-AzResourceGroup -Name $TargRGName -Location $TargLocation 

# Retrieve the Azure virtual network and subnet that you want to migrate to
$TargVNet = Get-AzVirtualNetwork -Name $TargVNetName

#Switch to the correct Subscription
$DRSubs = (Get-AzSubscription  | Where-Object {$_.Name -like "$DRSubsNum*"})
Set-AzContext -Subscription $DRSubs.Id

# Create a resource group a Recovery Services vault
#$DRRG = New-AzResourceGroup -Name $DRRGName -Location $DRLocation -Tag $DRTags 
$DRRG = Get-AzResourceGroup -Name $DRRGName -Location $DRLocation 

#Create a Recovery services vault.
#$DRServiceVault = New-AzRecoveryServicesVault -Name $DRServiceVaultName -Location $DRLocation -ResourceGroupName $DRRG.ResourceGroupName -Tag $DRTags
$DRServiceVault = Get-AzRecoveryServicesVault -Name $DRServiceVaultName -ResourceGroupName $DRRG.ResourceGroupName 
Set-AzRecoveryServicesAsrVaultContext -Vault $DRServiceVault

# Verify that the Configuration server is successfully registered to the vault
$ASRFabrics = Get-AzRecoveryServicesAsrFabric 
#-Debug -DefaultProfile $C
$ASRFabrics.count

#Create a replication policy
$Job_PolicyCreate = New-AzRecoveryServicesAsrPolicy -VMwareToAzure `
                    -Name $StraightReplPolicyName `
                    -RecoveryPointRetentionInHours 24 `
                    -ApplicationConsistentSnapshotFrequencyInHours 4 `
                    -RPOWarningThresholdInMinutes 60

# Track Job status to check for completion
while (($Job_PolicyCreate.State -eq "InProgress") -or ($Job_PolicyCreate.State -eq "NotStarted")){
        sleep 60;
        $Job_PolicyCreate = Get-ASRJob -Job $Job_PolicyCreate
        #Display job status
        write-host "Current state of the job is: $($Job_PolicyCreate.State)"
}

#Create a failback replication policy
$Job_ReversePolicyCreate = New-AzRecoveryServicesAsrPolicy -AzureToVMware `
                    -Name $ReverseReplPolicyName  `
                    -RecoveryPointRetentionInHours 24 `
                    -ApplicationConsistentSnapshotFrequencyInHours 4 `
                    -RPOWarningThresholdInMinutes 60

# Track Job status to check for completion
while (($Job_ReversePolicyCreate.State -eq "InProgress") -or ($Job_ReversePolicyCreate.State -eq "NotStarted")){
    sleep 60;
    $Job_ReversePolicyCreate = Get-ASRJob -Job $Job_ReversePolicyCreate
    #Display job status
    write-host "Current state of the job is: $($Job_ReversePolicyCreate.State)"
}

#Get the protection container corresponding to the Configuration Server
$ProtectionContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $ASRFabrics[0]

#Get the replication policies to map by name.
$StraightReplPolicy = Get-AzRecoveryServicesAsrPolicy -Name $StraightReplPolicyName
$ReverseReplPolicy = Get-AzRecoveryServicesAsrPolicy -Name $ReverseReplPolicyName 

# Associate the replication policies to the protection container corresponding to the Configuration Server.
$Job_AssociatePolicy = New-AzRecoveryServicesAsrProtectionContainerMapping `
            -Name "PolicyAssociation" `
            -PrimaryProtectionContainer $ProtectionContainer `
            -Policy $StraightReplPolicy

# Check the job status
while (($Job_AssociatePolicy.State -eq "InProgress") -or ($Job_AssociatePolicy.State -eq "NotStarted")){
        sleep 60;
        $Job_AssociatePolicy = Get-ASRJob -Job $Job_AssociatePolicy
        #Display job status
        write-host "Current state of the job is: $($Job_AssociatePolicy.State)"
}

<# In the protection container mapping used for failback (replicating failed over virtual machines
   running in Azure, to the primary VMware site.) the protection container corresponding to the
   Configuration server acts as both the Primary protection container and the recovery protection
   container
#>
 $Job_AssociateFailbackPolicy = New-AzRecoveryServicesAsrProtectionContainerMapping `
            -Name "FailbackPolicyAssociation" `
            -PrimaryProtectionContainer $ProtectionContainer `
            -RecoveryProtectionContainer $ProtectionContainer `
            -Policy $ReverseReplPolicy

# Check the job status
while (($Job_AssociateFailbackPolicy.State -eq "InProgress") -or ($Job_AssociateFailbackPolicy.State -eq "NotStarted")){
    sleep 60;
    $Job_AssociateFailbackPolicy = Get-ASRJob -Job $Job_AssociateFailbackPolicy
    #Display job status
    write-host "Current state of the job is: $($Job_AssociateFailbackPolicy.State)"
}

#Add a vCenter server and discover VMs !!!!!!!!!!!!!
$Job_AddvCenterServer = New-AzRecoveryServicesAsrvCenter `
                    -Fabric $ASRFabrics[0] `
                    -Name "Vcenter-01" `
                    -IpOrHostName "172.16.1.90" `
                    -Account $ASRFabrics[0].FabricSpecificDetails.RunAsAccounts[0] `
                    -Port 443

#Wait for the job to complete and ensure it completed successfully
while (($Job_AddvCenterServer.State -eq "InProgress") -or ($Job_AddvCenterServer.State -eq "NotStarted")) {
    sleep 60;
    $Job_AddvCenterServer = Get-ASRJob -Job $Job_AddvCenterServer
    #Display job status
    write-host "Current state of the job is: $($Job_AddvCenterServer.State)"
}

#Create a storage account My plan to replicate to a managed disk, therefore I will need only Log account
#Ensure that the storage account is created in the same Azure region as the vault.

$DRLogStorageAccount = New-AzStorageAccount -ResourceGroupName $DRRG.ResourceGroupName -Name $DRLogStorageAccountName -Location $DRLocation -SkuName Standard_LRS -Tag $DRTags

#Get the protection container mapping for replication policy named ReplicationPolicy
$PolicyMap  = Get-AzRecoveryServicesAsrProtectionContainerMapping -ProtectionContainer $ProtectionContainer | where PolicyFriendlyName -eq "ReplicationPolicy"

#Get the protectable item corresponding to the virtual machine CentOSVM1
$VM1 = Get-AzRecoveryServicesAsrProtectableItem -ProtectionContainer $ProtectionContainer -FriendlyName $VMName

# Enable replication for virtual machine using the Az.RecoveryServices module 2.0.0 onwards to replicate to managed disks
# The name specified for the replicated item needs to be unique within the protection container. Using a random GUID to ensure uniqueness
$Job_EnableReplication1 = New-AzRecoveryServicesAsrReplicationProtectedItem `
                        -VMwareToAzure `
                        -ProtectableItem $VM1 `
                        -Name $VM1.DisplayName ` #(New-Guid).Guid 
                        -ProtectionContainerMapping $PolicyMap `
                        -ProcessServer $ASRFabrics.FabricSpecificDetails.ProcessServers[0] ` 
                        -Account $ASRFabrics.FabricSpecificDetails.RunAsAccounts[0] `       
                        -RecoveryResourceGroupId $TargRG.ResourceId `
                        -logStorageAccountId $DRLogStorageAccount.Id `
                        -RecoveryAzureNetworkId $TargVNet.Id `
                        -RecoveryAzureSubnetName $TargSubnetName `
                        -Size "Standard_B2s" `
                        -UseManagedDisk True `
                        -RecoveryVmTag $TargTags

# View discovered server details
#Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
#Register-AzResourceProvider -ProviderNamespace Microsoft.ServiceBus
