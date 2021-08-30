Import-module  AzureAD
Connect-AzureAD 

$groupIDs = (Get-AzureADGroup | Where-Object {$_.DisplayName -like "*Secured Accounts"}).ObjectId
$groupIDs

$PolicyConditions = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessConditionSet
$PolicyConditions.Applications = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessApplicationCondition
$PolicyConditions.Applications.IncludeApplications = "All"

$PolicyConditions.Locations = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessLocationCondition
$Location = New-AzureADMSNamedLocationPolicy -OdataType "#microsoft.graph.ipNamedLocation" -DisplayName "Home" -IsTrusted $true -IpRanges "95.31.43.64/32"
$PolicyConditions.Locations.IncludeLocations = "All"
$PolicyConditions.Locations.ExcludeLocations = $Location.Id
#$ipRanges = New-Object -TypeName Microsoft.Open.MSGraph.Model.IpRange
#$ipRanges.cidrAddress = "95.31.43.65/32"

$PolicyConditions.Users = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessUserCondition
$PolicyConditions.Users.IncludeGroups = $groupIDs
#$PolicyConditions.Users.ExcludeGroups = "f753047e-de31-4c74-a6fb-c38589047723"
#$PolicyConditions.SignInRiskLevels = @('high', 'medium')
$PolicyReaction = New-Object -TypeName Microsoft.Open.MSGraph.Model.ConditionalAccessGrantControls
$PolicyReaction._Operator = "OR"
$PolicyReaction.BuiltInControls = "mfa"

New-AzureADMSConditionalAccessPolicy -DisplayName "Require MFA for Admin Accounts" -Conditions $PolicyConditions -GrantControls $PolicyReaction -State "Enabled"