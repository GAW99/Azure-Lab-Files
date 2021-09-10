$ScriptRootDir = Split-Path $MyInvocation.MyCommand.Definition -Parent
Import-Module Az

if (!$AzureCred) { $AzureCred = Get-Credential -Message "Please enter credentials for Azure"}

try { $var = Get-AzureADTenantDetail } 
catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {    Connect-AzureAD -Credential $AzureCred   }

$MGName = "AzureMigrationLab"
$MG = Get-AzManagementGroup -GroupName $MGName

$Decision = $null
Write-Host "Create policy definitions?"
$Decision = Read-Host -Prompt " Continue? [y/n]" 
if ($Decision -match "[yY]" ) 
{    
    if($Detailed -or $Informative) { Write-Host (get-date) "Confirmed" -ForegroundColor Green }

    #deployment of policy definition for resource groups to management group
    $PolicyDefinitionName = "Enforce resource group tag v1"
    $PolicyDefinitionDescription = "Forces a tag if does not exist during creation, if not provided ads with a default value. Implements only to resource groups." 
    $DefinitionFileName = "RG_All_Force_tag_custom_or_default.json"

    $DefinitionFileFullName = $ScriptRootDir +'\'+$DefinitionFileName

    $definition = New-AzPolicyDefinition `
        -Name ($PolicyDefinitionName.replace(' ','')) `
        -DisplayName $PolicyDefinitionName `
        -description $PolicyDefinitionDescription `
        -Policy $DefinitionFileFullName `
        -Mode All `
        -ManagementGroupName $MGName

    #deployment of policy definition for indexed resources to management group
    $PolicyDefinitionName = "Enforce resource tag v1"
    $PolicyDefinitionDescription = "Forces a tag if does not exist during creation, if not provided ads with a default value. Implements only to indexed resources." 
    $DefinitionFileName = "Res_Ind_Force_tag_custom_or_default.json"

    $DefinitionFileFullName = $ScriptRootDir +'\'+$DefinitionFileName

    $definition = New-AzPolicyDefinition `
        -Name ($PolicyDefinitionName.replace(' ','')) `
        -DisplayName $PolicyDefinitionName `
        -description $PolicyDefinitionDescription `
        -Policy $DefinitionFileFullName `
        -Mode Indexed `
        -ManagementGroupName $MGName

    #deployment of policy definition for indexed resources to management group
    $PolicyDefinitionName = "Enforce resouce location equal to RG v1"
    $PolicyDefinitionDescription = "Forces a location of resource equal to location of the resource group. Implements only to indexed resources." 
    $DefinitionFileName = "Res_Ind_force_resource_location_equal_to_RG.json"

    $DefinitionFileFullName = $ScriptRootDir +'\'+$DefinitionFileName

    $definition = New-AzPolicyDefinition `
        -Name ($PolicyDefinitionName.replace(' ','')) `
        -DisplayName $PolicyDefinitionName `
        -description $PolicyDefinitionDescription `
        -Policy $DefinitionFileFullName `
        -Mode Indexed `
        -ManagementGroupName $MGName

    #deployment of policy definition for resource groups to management group
    $PolicyDefinitionName = "Enforce location of RG v1"
    $PolicyDefinitionDescription = "Forces a location of resource groups to particular regions. Implements only to resource groups." 
    $DefinitionFileName = "RG_All_Allowed_Locations.json"

    $DefinitionFileFullName = $ScriptRootDir +'\'+$DefinitionFileName

    $definition = New-AzPolicyDefinition `
        -Name ($PolicyDefinitionName.replace(' ','')) `
        -DisplayName $PolicyDefinitionName `
        -description $PolicyDefinitionDescription `
        -Policy $DefinitionFileFullName `
        -Mode All `
        -ManagementGroupName $MGName

} 

$Decision = $null
Write-Host "Create Initiative?"
$Decision = Read-Host -Prompt " Continue? [y/n]" 
if ($Decision -match "[yY]" ) 
{    
    if($Detailed -or $Informative) { Write-Host (get-date) "Confirmed" -ForegroundColor Green }
    #deployment of initiative definition to management group
    $PolicyDefinitionSetName = "Lab environment v1"
    $PolicyDefinitionSetNameShort =  ($PolicyDefinitionSetName.replace(' ',''))
    $PolicyDefinitionSetDescription = "Forces some tag and location requirements for resources." 
    $SetDefinitionFileName = "Initiative.definitions.json"
    $SetParametrsFileName = "Initiative.parametrs.json"

    $SetDefinitionFileFullName = $ScriptRootDir +'\'+$SetDefinitionFileName
    $SetParametrsFileFullName = $ScriptRootDir +'\'+$SetParametrsFileName

    $SetParametrsFileFullName
    $DefinitionSetFileFullName 

    $DefinitionSet = New-AzPolicySetDefinition `
        -Name $PolicyDefinitionSetNameShort `
        -DisplayName $PolicyDefinitionSetName `
        -description $PolicyDefinitionSetDescription `
        -PolicyDefinition $SetDefinitionFileFullName `
        -Parameter $SetParametrsFileFullName `
        -ManagementGroupName $MGName `
        -Metadata '{"category":"Lab","version":"1.0"}'
} 

$Decision = $null
Write-Host "Create Initiative assignment?"
$Decision = Read-Host -Prompt " Continue? [y/n]" 
if ($Decision -match "[yY]" ) 
{    
    if($Detailed -or $Informative) { Write-Host (get-date) "Confirmed" -ForegroundColor Green }
    
    $InitiativeAssignmentName = "Lab environment v1"
    $InitiativeAssignmentDescription = "Forces some tag and location requirements for resources." 
    $InitiativeParametrsValuesFileName = "Initiative.parametrs.values.json"

    $SetParametrsValuesFileFullName = $ScriptRootDir +'\'+$InitiativeParametrsValuesFileName

    $DefinitionSet =  (Get-AzPolicySetDefinition -Custom| Where-Object {$_.Name -eq $PolicyDefinitionSetNameShort})
    #---$DefinitionSet =  (Get-AzPolicySetDefinition -Custom| Where-Object {$_.Name -eq ($PolicyDefinitionSetName.replace(' ',''))})
    #New-AzureRmPolicyAssignment -PolicySetDefinition $policySetDefinition -Name "$rgName - Billing Tags" -Scope $resourceGroup.ResourceId -costCenterValue $costCenter -ownerEmailValue $ownerEmail -Sku @{"Name" = "A1"; "Tier" = "Standard"}

    $DefinitionSetAssignment = New-AzPolicyAssignment -DisplayName $InitiativeAssignmentName -Name ($InitiativeAssignmentName.replace(' ','')) -PolicySetDefinition $DefinitionSet -Scope $($MG).Id -PolicyParameter $SetParametrsValuesFileFullName -AssignIdentity:$true -Location northeurope

} 

$Decision = $null
Write-Host "Create groups and permissions?"
$Decision = Read-Host -Prompt " Continue? [y/n]" 
if ($Decision -match "[yY]" ) 
{    
    if($Detailed -or $Informative) { Write-Host (get-date) "Confirmed" -ForegroundColor Green }
    $ContributorGroupName = "Contributors to the $($MG.DisplayName) management group."
    $ContributorGroupDescription = "Members of the group have contributors premissions on the $($MG.DisplayName) management group"
    
    $ADGroup = New-AzureADGroup -SecurityEnabled $true -DisplayName $ContributorGroupName -Description $ContributorGroupDescription -MailEnabled $false -MailNickName "AzureMigrationContributors"
    New-AzRoleAssignment -ObjectId $ADGroup.ObjectId -RoleDefinitionName "Contributor" -Scope $MG.Id
    
    $ManagedIdentity = Get-AzADServicePrincipal -ObjectId $DefinitionSetAssignment.Identity.principalId
    Add-AzureADGroupMember -ObjectId $ADGroup.ObjectId -RefObjectId $ManagedIdentity.Id
} 