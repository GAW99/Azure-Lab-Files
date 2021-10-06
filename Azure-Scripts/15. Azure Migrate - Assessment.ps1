Import-Module Az

if (!$AzureCred) { $AzureCred = Get-Credential -Message "Please enter credentials for Azure"}
if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) { Connect-AzAccount -Credential $AzureCred }

# Declare variables
#Resource Group
$SubscriptionNum = 2
$RGName = "MigrationRG-NorthEU"
$Location = "northeurope" 
$Tags= @{Environment="Lab";Project="Azure Migration"}

#Migration Project
$MigrationProjectName = "DCMigrationProject"

#Switch to the correct subscription
$Subscription = (Get-AzSubscription  | Where-Object {$_.Name -like "$SubscriptionNum*"})
Set-azcontext -Subscription $Subscription.Id

# Create a resource group
$RG = New-AzResourceGroup -Name $RGName -Location $Location -Tag $Tags 

#Create migration project
$MigrationProject = New-AzMigrateProject -SubscriptionId $Subscription.Id -ResourceGroupName $RG.ResourceGroupName -Name $MigrationProjectName -Location $Location

#Register resource provider in the case of error
Register-AzResourceProvider -ProviderNamespace Microsoft.Migrate

#Register project tools
Register-AzMigrateProjectTool -SubscriptionId $Subscription.Id -ResourceGroupName $RG.ResourceGroupName -MigrateProjectName $MigrationProjectName -Tool "ServerDiscovery"
