$ScriptRootDir = Split-Path $MyInvocation.MyCommand.Definition -Parent
. ($ScriptRootDir+'\Lib.ps1')
. ($ScriptRootDir+'\NetshLib.ps1')            

if(!$DNSServerCred) { $DNSServerCred = Get-Credential -Message "Please enter credentials for the DNS Server"}
if(!$UserCredential) { $UserCredential = Get-Credential -Message "Please enter administrative credentials in the domain"}
if(!$CertPassword) {  $CertPassword = Read-Host -AsSecureString -Prompt "Please enter a PFX password"}

[switch]$Informative = $true
[switch]$Detailed = $true
[switch]$Testing = $false

$DNSServerName = 'svc-01'
$DomainNetBIOS = "gaw00"
$CertNames = '*.gaw00.tk'
$ContactEmail = 'admin1@gaw00.tk'
$CertFriendlyName = (Get-Date -Format FileDate)+"_Common_Certificate" 
$DomainFQDN = "gaw00.local"    
$DomainCertificateVault =  '\\fs-c1.gaw00.local\certs$\Certificates' 
$CAServers = @("DC-1")
$ADFSServers = "ADFS-1","ADFS-2"
$WAPServers = "RP-1","RP-2"
$OOSServers = @("OOS-1")
$UCEdgeServers = @("UCED-P1")
$UCFEServers = "UCFE-1","UCFE-2"
$MBXServers = "EXCH-1","EXCH-2"
$EdgeServers = @("EXED-1")
$Servers =  @()
$Servers += $CAServers+$ADFSServers+$WAPServers+$OOSServers+$UCEdgeServers+$UCFEServers+$MBXServers+$EdgeServers

$PasswordFileName = "Password.txt"
$ADFSServiceAccountSAM = "SVC_ADFS-01$"

$ADFSServiceAccount= New-Object System.Security.Principal.NTAccount($DomainNetBIOS,$ADFSServiceAccountSAM)

If ($Informative -or $Detailed) {Write-Host "Script is starting" -ForegroundColor Yellow}
    
#$CertificateData = Request-LECertificate -Informative:$Informative -Detailed:$Detailed -DNSServerName $DNSServerName -DNSServerCred $DNSServerCred -CertNames $CertNames -CertPassword $CertPassword -ContactEmail $ContactEmail -CertFriendlyName $CertFriendlyName -Testing:$Testing
if($Informative -or $Detailed) { Write-host "We have got a certificate:"; $CertificateData |fl }

#Copy-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXLocalFileName $CertificateData.PfxFile -CertPassword $CertificateData.PfxPass -PasswordFileName $PasswordFileName

foreach($Server in $Servers)
{
    $CurrentServerFQDN = $Server+"."+$DomainFQDN
 #   Install-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXFileName ((Get-Item $CertificateData.PfxFile).Name) -PasswordFileName $PasswordFileName -ComputerFQDN $CurrentServerFQDN
}

#CleanUP-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential

foreach($MBXServer in $MBXServers)
{
    $CurrentServerFQDN = $MBXServer+"."+$DomainFQDN
   # Enable-ExchMBXCertificate -Informative:$Informative -Detailed:$Detailed -Creds $UserCredential -CertThumbprint $CertificateData.Thumbprint -MBXServerName $CurrentServerFQDN
}

foreach($EdgeServer in $EdgeServers)
{
    $CurrentServerFQDN = $EdgeServer+"."+$DomainFQDN
    #Enable-ExchEdgeCertificate -Informative:$Informative -Detailed:$Detailed -Creds $UserCredential -CertThumbprint $CertificateData.Thumbprint -EdgeServerName $CurrentServerFQDN
    #Enable-ExchEdgeCertificate -Informative:$Informative -Detailed:$Detailed -Creds $UserCredential -CertThumbprint "ED3B33EE80912FB0F8DDF5236D0A042613F864AC" -EdgeServerName $CurrentServerFQDN
}

$MainServerFlag=$true
foreach($ADFSServer in $ADFSServers)
{
    $CurrentServerFQDN = $ADFSServer+"."+$DomainFQDN     
    #Enable-ADFSCertificate -CertThumbprint "A16B8345C4760A774BC5AC2DACDAA3DF5B00DD37" -MainServer:$MainServerFlag -ADFSServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed    #test
    Enable-ADFSCertificate -CertThumbprint "ED3B33EE80912FB0F8DDF5236D0A042613F864AC" -MainServer:$MainServerFlag -ADFSServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed #PROD
    #Enable-ADFSCertificate -CertThumbprint $CertificateData.Thumbprint -MainServer:$MainServerFlag -ADFSServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed 
    $MainServerFlag=$false
}

$MainServerFlag=$true
foreach($WAPServer in $WAPServers)
{
    $CurrentServerFQDN = $WAPServer+"."+$DomainFQDN     
    #Replace-WAPCertificate -CertThumbprint "A16B8345C4760A774BC5AC2DACDAA3DF5B00DD37" -MainServer:$MainServerFlag -WAPServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed    #test
    Replace-WAPCertificate -CertThumbprint "ED3B33EE80912FB0F8DDF5236D0A042613F864AC" -MainServer:$MainServerFlag -WAPServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed #PROD
    #Replace-WAPCertificate -CertThumbprint $CertificateData.Thumbprint -MainServer:$MainServerFlag -WAPServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed 
    $MainServerFlag=$false
}

# Submit-Renewal -AllOrders -Force