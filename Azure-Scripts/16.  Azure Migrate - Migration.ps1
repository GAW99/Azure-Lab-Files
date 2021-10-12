Import-Module Az

if (!$AzureCred) { $AzureCred = Get-Credential -Message "Please enter credentials for Azure"}
if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) { Connect-AzAccount -Credential $AzureCred }

# Declare variables
#Resource Group for Migration Project
$MigSubsNum = 2
$MigRGName = "MigrationRG-NorthEU"
$MigLocation = "northeurope" 
$MigTags= @{Environment="Lab";Project="Azure Migration"}

#Resource Group for VMs
$TargSubsNum = 1
$TargRGName = "VMsRG01-NorthEU"
$TargLocation = "northeurope" 
$TargTags= @{Environment="Lab";Project="Azure Migration"}

#List of Targ to migrate
$MigrationTarg= @("DC-2")
$TargVNetName = "ProdVNet1" 
$TargSubnetName = "ProdSubnet1"

#Migration Project
$MigrationProjectName = "DCMigrationProject"

#Switch to the Network Subscription 
$TargNetSubs = (Get-AzSubscription  | Where-Object {$_.Name -like "1*"})
Set-AzContext -Subscription $TargNetSubs.Id

# Retrieve the Azure virtual network and subnet that you want to migrate to
$TargVNet = Get-AzVirtualNetwork -Name $TargVNetName

#region collecting data from assessment
#Switch to the correct Subscription
$MigSubs = (Get-AzSubscription  | Where-Object {$_.Name -like "$MigSubsNum*"})
Set-AzContext -Subscription $MigSubs.Id

# Create a resource group
$MigRG = Get-AzResourceGroup -Name $MigRGName -Location $MigLocation 

#Create migration project
$MigrationProject = Get-AzMigrateProject -SubscriptionId $MigSubs.Id -ResourceGroupName $MigRG.ResourceGroupName -Name $MigrationProjectName

# Get a specific VMware VM in an Azure Migrate project
$DiscoveredServers = @(Get-AzMigrateDiscoveredServer -ProjectName $MigrationProject.Name -ResourceGroupName $MigRG.ResourceGroupName | Where-Object {$_.DisplayName -in $MigrationTarg})

# View discovered server details
$DiscoveredServers | Format-Table DisplayName, Name, Type
Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
Register-AzResourceProvider -ProviderNamespace Microsoft.ServiceBus

# Initialize replication infrastructure for the current Migrate project - Once per project
Initialize-AzMigrateReplicationInfrastructure -ResourceGroupName $MigRG.ResourceGroupName -ProjectName $MigrationProject.Name -Scenario agentlessVMware -TargetRegion $MigLocation
#endregion

#region preparing RG and collecting other info for Targ
#Switch to the correct subscription
$TargSubs = (Get-AzSubscription  | Where-Object {$_.Name -like "$TargSubsNum*"})
Set-AzContext -Subscription $TargSubs.Id

# Create a resource group
#$TargRG = New-AzResourceGroup -Name $TargRGName -Location $TargLocation -Tag $TargTags 
$TargRG = Get-AzResourceGroup -Name $TargRGName -Location $TargLocation   

# Start replication for a discovered VMs in an Azure Migrate project
$MigSubs = (Get-AzSubscription  | Where-Object {$_.Name -like "$MigSubsNum*"})
Set-AzContext -Subscription $MigSubs.Id

foreach ($DiscoveredServer in $DiscoveredServers)
{
    Write-host "Starting replication of $($DiscoveredServer.DisplayName)"
    $MigrateJob =  New-AzMigrateServerReplication -InputObject $DiscoveredServer `
                    -TargetResourceGroupId $TargRG.ResourceId `
                    -TargetNetworkId $TargVNet.Id `
                    -LicenseType WindowsServer `
                    -OSDiskID $DiscoveredServers.Disk[0].Uuid `
                    -TargetSubnetName $TargSubnetName `
                    -DiskType Standard_LRS `
                    -TargetVMName $DiscoveredServer.DisplayName `
                    -TargetVMSize Standard_B2s `

    # Track job status to check for completion
    while (($MigrateJob.State -eq 'InProgress') -or ($MigrateJob.State -eq 'NotStarted'))
    {
        #If the job hasn't completed, sleep for 60 seconds before checking the job status again
        sleep 60;
        $MigrateJob = Get-AzMigrateJob -InputObject $MigrateJob
        Write-Output "Current replication status for VM $($DiscoveredServer.DisplayName) is $($MigrateJob.State)"
    }
    #Check if the Job completed successfully. The updated job state of a successfully completed job should be "Succeeded".
    Write-Output "Current replication status for VM $($DiscoveredServer.DisplayName) is $($MigrateJob.State)"
}
#endregion

# List replicating VMs.
$ReplicatingServers = Get-AzMigrateServerReplication -ProjectName $MigrationProject.Name -ResourceGroupName $MigRG.ResourceGroupName -machineName "DC-2"

# Start migration for a replicating server and turn off source server as part of migration
foreach ($ReplicatingServer in $ReplicatingServers)
{
    Write-host "Starting migration of $($ReplicatingServer.MachineName)"
    $MigrateJob = Start-AzMigrateServerMigration -InputObject $ReplicatingServer -TurnOffSourceServer
    # Track job status to check for completion
    while (($MigrateJob.State -eq 'InProgress') -or ($MigrateJob.State -eq 'NotStarted'))
    {
        #If the job hasn't completed, sleep for 60 seconds before checking the job status again
        sleep 60;
        $MigrateJob = Get-AzMigrateJob -InputObject $MigrateJob
        Write-Output "Current migration status for VM $($ReplicatingServer.MachineName) is $($MigrateJob.State)"
    }
    #Check if the Job completed successfully. The updated job state of a successfully completed job should be "Succeeded".
    Write-Output "Current migration status for VM $($ReplicatingServer.MachineName) is $($MigrateJob.State)"
}

    # Stop replication for a migrated server
foreach ($ReplicatingServer in $ReplicatingServers)
{
    Write-host "Stopping replication of $($ReplicatingServer.MachineName)"
    $StopReplicationJob = Remove-AzMigrateServerReplication -InputObject $ReplicatingServer
    # Track job status to check for completion
    while (($StopReplicationJob.State -eq 'InProgress') -or ($StopReplicationJob.State -eq 'NotStarted'))
    {
        #If the job hasn't completed, sleep for 60 seconds before checking the job status again
        sleep 60;
        $StopReplicationJob = Get-AzMigrateJob -InputObject $StopReplicationJob
        Write-Output "Current stop replication task status for VM $($ReplicatingServer.MachineName) is $($StopReplicationJob.State)"
    }
    #Check if the Job completed successfully. The updated job state of a successfully completed job should be "Succeeded".
    Write-Output "Current stop replication task status for VM $($ReplicatingServer.MachineName) is $($StopReplicationJob.State)"
}
