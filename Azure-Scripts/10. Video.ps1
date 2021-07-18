Param(
    [PARAMETER(Mandatory = $false)][switch]$Informative=$true,
    [PARAMETER(Mandatory = $false)][switch]$Detailed= $true,
    [PARAMETER(Mandatory = $false)][switch]$Loging = $true
    )

if(!$password) {$password = Read-Host -Message "Please enter default user password" -AsSecureString}
if(!$UserCredential) { $UserCredential = Get-Credential -Message "Please enter administrative credentials in the domain"}
Import-Module activedirectory
Import-Module Az

$StartNum = 50
$LastNum = 59
$DC = (Get-ADDomainController -NextClosestSite -Discover -DomainName gaw00.local ).Hostname.Value
$ScriptRootDir = Split-Path $MyInvocation.MyCommand.Definition -Parent

[string]$FullLogPath = $ScriptRootDir + "\Log " + (Get-Date -Format FileDate )+".txt" #Name of the file with results 
if($Loging) { Write-host (get-date)""  -ForegroundColor Cyan -NoNewline:$true; Start-Transcript -Path $FullLogPath -Append }

#Create AD Users
$OUDN = "OU=Cloud Users,OU=Users,OU=Organization,DC=GAW00,DC=LOCAL"
for ($i = $StartNum; $i -le $LastNum; $i++)
{
    $Login = "User"+$i.ToString()
    $Name = "User"+$i.ToString()
    $OfficePhone = "12345678#"+$i.ToString()
    $Description = "Synchronized and migrated user # "+$i.ToString()
    $Title ="Employee #"+$i.ToString()
    $UserPrincipalName = "User"+$i.ToString()+"@gaw00.tk"
    $Path = $OUDN
    Write-Host $Login

    New-ADUser -SAMAccountName $Login -Name $Name -Department "IT" -Office "main" -OfficePhone $OfficePhone `
                -Company "GAW" -PasswordNeverExpires $true -State "Moscow" -City "Moscow" -Description $Description `
                -Title $Title -UserPrincipalName $UserPrincipalName -AccountPassword  $password -Path $Path -Enabled $true -Server $DC

}

#Connect to a on-premises Exchange Server
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://exch-1.gaw00.local/PowerShell/ -Authentication Kerberos -Credential $UserCredential
Import-PSSession $Session -DisableNameChecking

#Enable mailboxes for on-premises users
for ($i = $StartNum; $i -le $LastNum; $i++)
{
    $Login = "User"+$i.ToString()
    $Name = "User"+$i.ToString()
    $UserPrincipalName = "User"+$i.ToString()+"@gaw00.tk"
    $Path = $OUDN

    $CurrentADUser = Get-ADUser -SearchBase $Path -Server $DC -SearchScope Subtree -Filter * | Where-Object {$_.UserPrincipalName -eq $UserPrincipalName}
    Enable-MailUser -Identity $CurrentADUser.SamAccountName  -Alias $Login  -PrimarySmtpAddress $UserPrincipalName -ExternalEmailAddress $UserPrincipalName

}

#Connetc to Azure Active Directory
Connect-AzureAD

#Create Password Profile
$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = Read-Host -AsSecureString  
$PasswordProfile.EnforceChangePasswordPolicy =$false
$PasswordProfile.ForceChangePasswordNextLogin =$false

#Attemt to create Cloud only users
#Does not work witj a federated domain name
for ($i = $StartNum; $i -le $LastNum; $i++)
{
    $Login = "User"+$i.ToString()
    $Name = "User"+$i.ToString()
    $OfficePhone = "12345678#"+$i.ToString()
    $Description = "Synchronized and migrated user # "+$i.ToString()
    $Title ="Employee #"+$i.ToString()
    $UserPrincipalName = "User"+$i.ToString()+"@gaw00.tk"
    Write-Host $Login

    New-AzureADUser -AccountEnabled $true -DisplayName $Name -Company "GAW" -State "Moscow" -City "Moscow" -Department "IT" -PhysicalDeliveryOfficeName "main" `
                    -MailNickName $Loging -PasswordProfile $PasswordProfile -JobTitle $Title -UserPrincipalName $UserPrincipalName -TelephoneNumber $OfficePhone -UsageLocation "US"

}

$AzureUserList = (Get-AzADUser -StartsWith "User" ).UserPrincipalName #get list of Azure users
$planName= (Get-AzureADSubscribedSku)[0].SkuPartNumber # get name of licensing plan
$License = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
$License.SkuId = (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value $planName -EQ).SkuID # get ID of licensing plan
$LicensesToAssign = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
$LicensesToAssign.AddLicenses = $License
# for each user set region and License
$AzureUserList| foreach {Set-AzureADUser -ObjectId $_ -UsageLocation "US"; Set-AzureADUserLicense -ObjectId $_ -AssignedLicenses $LicensesToAssign}

if($Loging) { Write-host (get-date)"" -ForegroundColor Cyan -NoNewline:$true; Stop-Transcript}