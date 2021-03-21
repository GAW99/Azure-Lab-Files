$ScriptRootDir = Split-Path $MyInvocation.MyCommand.Definition -Parent
. ($ScriptRootDir+'\Lib.ps1')

if(!$DNSServerCred) { $DNSServerCred = Get-Credential -Message "Please enter credentials for the DNS Server"}
if(!$UserCredential) { $UserCredential = Get-Credential -Message "Please enter administrative credentials in the domain"}
if(!$CertPassword) {  $CertPassword = Read-Host -AsSecureString -Prompt "Please enter a PFX password"}

[switch]$Informative = $true
[switch]$Detailed = $true
[switch]$Testing = $false

$DNSServerName = 'svc-01'
$CertNames = '*.gaw00.tk'
$ContactEmail = 'admin1@gaw00.tk'
$CertFriendlyName = (Get-Date -Format FileDate)+"_Common_Certificate" 
$DomainFQDN = "gaw00.local"    
$DomainCertificateVault =  '\\fs-c1.gaw00.local\certs$\Certificates' 
$Servers = "DC-1","EXCH-1","EXCH-2","EXED-1","ADFS-1","ADFS-2","OOS-1","RP-1","RP-2","UCED-P1","UCFE-1","UCFE-2"
$PasswordFileName = "Password.txt"

If ($Informative -or $Detailed) {Write-Host "Script is starting" -ForegroundColor Yellow}
    
#Set-PAServer LE_STAGE #To use staging server:
#Set-PAServer LE_PROD #To use production server:

$CertificateData = Request-LECertificate -Informative:$Informative -Detailed:$Detailed -DNSServerName $DNSServerName -DNSServerCred $DNSServerCred -CertNames $CertNames -CertPassword $CertPassword -ContactEmail $ContactEmail -CertFriendlyName $CertFriendlyName -Testing:$Testing
if($Informative -or $Detailed) { Write-host "We have got a certificate:"; $CertificateData |fl }

Copy-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXLocalFileName $CertificateData.PfxFile -CertPassword $CertificateData.PfxPass -PasswordFileName $PasswordFileName

foreach($Server in $Servers)
{
    $CurrentServerFQDN = $Server+"."+$DomainFQDN
    Install-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXFileName ((Get-Item $CertificateData.PfxFile).Name) -PasswordFileName $PasswordFileName -ComputerFQDN $CurrentServerFQDN
}

CleanUP-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential

# Submit-Renewal -AllOrders -Force