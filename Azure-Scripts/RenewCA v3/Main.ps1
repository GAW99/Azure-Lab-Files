$ScriptRootDir = Split-Path $MyInvocation.MyCommand.Definition -Parent
. ($ScriptRootDir+'\Lib.ps1')
. ($ScriptRootDir+'\NetshLib.ps1') 
. ($ScriptRootDir+'\UpdateFederation.ps1')           

if(!$DNSServerCred) { $DNSServerCred = Get-Credential -Message "Please enter credentials for the DNS Server"}
if(!$UserCredential) { $UserCredential = Get-Credential -Message "Please enter administrative credentials in the domain"}
if(!$CertPassword) {  $CertPassword = Read-Host -AsSecureString -Prompt "Please enter a PFX password"}
if(!$AzCred) { $AzCred = Get-Credential -Message "Please enter credentials for Azure tenant"}

[switch]$Informative = $true
[switch]$Detailed = $true
[switch]$Testing = $false

$DNSServerName = 'svc-01'
$DomainNetBIOS = "gaw00"
$CertNames = "*.gaw00.tk"
$UCEdgeCertNames = "access.gaw00.tk","sip.gaw00.tk","gaw00.tk"
$ContactEmail = 'admin@gaw00.tk'
$DomainFQDN = "gaw00.local"    
$DomainCertificateVault =  '\\fs-c1.gaw00.local\certs$\Certificates' 
$CAServers = @("DC-1")
$ADFSServers = "ADFS-1","ADFS-2"
$WAPServers = "RP-1","RP-2"
$OOSServers = @("OOS-1")
$UCEdgeServers = @("UCED-P1")
$UCFEServers = "UCFE-1","UCFE-2"
$MBXServers = "EXCH-1","EXCH-2"
$MBXEdgeServers = @("EXED-1")
$Servers =  @()
$Servers += $CAServers+$ADFSServers+$WAPServers+$OOSServers+$UCFEServers+$MBXServers

$CertFriendlyName = (Get-Date -Format FileDate)+"_Common_Certificate" 
$PasswordFileName = "Password.txt"
$ADFSServiceAccountSAM = "SVC_ADFS-01$"

$DNSSubsID = "d8274949-d913-4075-9b9c-d3a839fb5a30"
if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) { Connect-AzAccount -Credential $AzCred -Subscription $DNSSubsID }

$ADFSServiceAccount= New-Object System.Security.Principal.NTAccount($DomainNetBIOS,$ADFSServiceAccountSAM)

If ($Informative -or $Detailed) {Write-Host "Script is starting" -ForegroundColor Yellow}

If ($Informative -or $Detailed) {Write-Host "Requesting the common certificate with SAN(s): $CertNames" -ForegroundColor Yellow}    
    #$CertificateData = Request-LECertificate -Informative:$Informative -Detailed:$Detailed -DNSServerName $DNSServerName -DNSServerCred $DNSServerCred -CertNames $CertNames -CertPassword $CertPassword -ContactEmail $ContactEmail -CertFriendlyName $CertFriendlyName -Testing:$Testing
    $CertificateData = Request-LECertificateAzure -Informative:$Informative -Detailed:$Detailed -CertNames $CertNames -CertPassword $CertPassword -ContactEmail $ContactEmail -CertFriendlyName $CertFriendlyName -Testing:$Testing
if($Informative -or $Detailed) { Write-host "We have got the certificate:"; $CertificateData |fl }

if($Informative -or $Detailed) { Write-host "Coppieng the certificate with friendly name: $CertFriendlyName to the shared folder..."  -ForegroundColor Yellow}
    Copy-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXLocalFileName $CertificateData.PfxFile -CertPassword $CertificateData.PfxPass -PasswordFileName $PasswordFileName

if($Informative -or $Detailed) { Write-host "Installing the certificate with friendly name: $CertFriendlyName to the Machine vault..." }
foreach($Server in $Servers)
{
    $CurrentServerFQDN = $Server+"."+$DomainFQDN
    Install-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXFileName ((Get-Item $CertificateData.PfxFile).Name) -PasswordFileName $PasswordFileName -ComputerFQDN $CurrentServerFQDN
}

if($Informative -or $Detailed) { Write-host "Installing the certificate with friendly name: $CertFriendlyName to the Exchange Edge Server Machine vault (using the legacy method)..." }
foreach($MBXEdgeServer in $MBXEdgeServers)
{
    $CurrentServerFQDN = $MBXEdgeServer+"."+$DomainFQDN
    Install-LECertificateLegacy -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXFileName ((Get-Item $CertificateData.PfxFile).Name) -CertPassword $CertPassword -ComputerFQDN $CurrentServerFQDN
}

if($Informative -or $Detailed) { Write-host "Cleaning Up the shared folder from the certificate with friendly name: $CertFriendlyName ..."  -ForegroundColor Yellow}
    CleanUP-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential

if($Informative -or $Detailed) { Write-host "Installing the certificate with friendly name: $CertFriendlyName on the Exchange Mailbox Servers..."  -ForegroundColor Yellow }
foreach($MBXServer in $MBXServers)
{
   $CurrentServerFQDN = $MBXServer+"."+$DomainFQDN
   Enable-ExchMBXCertificate -Informative:$Informative -Detailed:$Detailed -Creds $UserCredential -CertThumbprint $CertificateData.Thumbprint -MBXServerName $CurrentServerFQDN
   #Enable-ExchMBXCertificate -Informative:$Informative -Detailed:$Detailed -Creds $UserCredential -CertThumbprint "ED3B33EE80912FB0F8DDF5236D0A042613F864AC" -MBXServerName $CurrentServerFQDN
}

if($Informative -or $Detailed) { Write-host "Enabling the certificate with friendly name: $CertFriendlyName on the Exchange Edge Servers..."  -ForegroundColor Yellow}
foreach($MBXEdgeServer in $MBXEdgeServers)
{
    $CurrentServerFQDN = $MBXEdgeServer+"."+$DomainFQDN
    Enable-ExchEdgeCertificate -Informative:$Informative -Detailed:$Detailed -Creds $UserCredential -CertThumbprint $CertificateData.Thumbprint -EdgeServerName $CurrentServerFQDN
    #Enable-ExchEdgeCertificate -Informative:$Informative -Detailed:$Detailed -Creds $UserCredential -CertThumbprint "ED3B33EE80912FB0F8DDF5236D0A042613F864AC" -EdgeServerName $CurrentServerFQDN
}

if($Informative -or $Detailed) { Write-host "Installing the certificate with friendly name: $CertFriendlyName on the AD FS Servers..."  -ForegroundColor Yellow}
$MainServerFlag=$true
foreach($ADFSServer in $ADFSServers)
{
    $CurrentServerFQDN = $ADFSServer+"."+$DomainFQDN     
    #Enable-ADFSCertificate -CertThumbprint "A16B8345C4760A774BC5AC2DACDAA3DF5B00DD37" -MainServer:$MainServerFlag -ADFSServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed    #test
    #Enable-ADFSCertificate -CertThumbprint "ED3B33EE80912FB0F8DDF5236D0A042613F864AC" -MainServer:$MainServerFlag -ADFSServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed #PROD
    Enable-ADFSCertificate -CertThumbprint $CertificateData.Thumbprint -MainServer:$MainServerFlag -ADFSServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed 
    $MainServerFlag=$false
}

if($Informative -or $Detailed) { Write-host "Installing the certificate with friendly name: $CertFriendlyName on the WAP Servers..." -ForegroundColor Yellow }
$MainServerFlag=$true
foreach($WAPServer in $WAPServers)
{
    $CurrentServerFQDN = $WAPServer+"."+$DomainFQDN     
    #Replace-WAPCertificate -CertThumbprint "A16B8345C4760A774BC5AC2DACDAA3DF5B00DD37" -MainServer:$MainServerFlag -WAPServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed    #test
    #Replace-WAPCertificate -CertThumbprint "ED3B33EE80912FB0F8DDF5236D0A042613F864AC" -MainServer:$MainServerFlag -WAPServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed #PROD
    Replace-WAPCertificate -CertThumbprint $CertificateData.Thumbprint -MainServer:$MainServerFlag -WAPServerName $CurrentServerFQDN -Creds $UserCredential -Informative:$Informative -Detailed:$Detailed 
    $MainServerFlag=$false
}

#region Intall on UC Edge
$UCEdgeCertNames = "access.gaw00.tk","sip.gaw00.tk","gaw00.tk"
$UCEdgeCertFriendlyName = (Get-Date -Format FileDate)+"_UCEdge_Certificate"
$PasswordFileName = "Password.txt"

If ($Informative -or $Detailed) {Write-Host "Requesting the S4B Edge certificate with SAN(s): $UCEdgeCertNames" -ForegroundColor Yellow}    
    #$UCEdgeCertificateData = Request-LECertificate -Informative:$Informative -Detailed:$Detailed -DNSServerName $DNSServerName -DNSServerCred $DNSServerCred -CertNames $UCEdgeCertNames -CertPassword $CertPassword -ContactEmail $ContactEmail -CertFriendlyName $UCEdgeCertFriendlyName -Testing:$Testing
    $UCEdgeCertificateData = Request-LECertificateAzure -Informative:$Informative -Detailed:$Detailed -CertNames $UCEdgeCertNames -CertPassword $CertPassword -ContactEmail $ContactEmail -CertFriendlyName $UCEdgeCertFriendlyName -Testing:$Testing
if($Informative -or $Detailed) { Write-host "We have got the certificate:"; $UCEdgeCertificateData |fl }

if($Informative -or $Detailed) { Write-host "Coppieng the certificate with friendly name: $UCEdgeCertFriendlyName to the shared folder..."  -ForegroundColor Yellow}
Copy-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXLocalFileName $UCEdgeCertificateData.PfxFile -CertPassword $UCEdgeCertificateData.PfxPass -PasswordFileName $PasswordFileName

if($Informative -or $Detailed) { Write-host "Installing the certificate with friendly name: $UCEdgeCertFriendlyName to the Machine vault..." }
foreach($UCEdgeServer in $UCEdgeServers)
{
    $CurrentServerFQDN = $UCEdgeServer+"."+$DomainFQDN
    Install-LECertificateLegacy -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential -PFXFileName ((Get-Item $UCEdgeCertificateData.PfxFile).Name) -CertPassword $CertPassword -ComputerFQDN $CurrentServerFQDN
}

if($Informative -or $Detailed) { Write-host "Cleaning Up the shared folder from the certificate with friendly name: $UCEdgeCertFriendlyName ..."  -ForegroundColor Yellow}
    CleanUP-LECertificate -Informative:$Informative -Detailed:$Detailed -RootSharePath $DomainCertificateVault -Creds $UserCredential

if($Informative -or $Detailed) { Write-host "Installing the certificate with friendly name: $UCEdgeCertFriendlyName on the S4B Edge Servers..."  -ForegroundColor Yellow}
foreach($UCEdgeServer in $UCEdgeServers)
{
    $CurrentServerFQDN = $UCEdgeServer+"."+$DomainFQDN
    Enable-UCEdgeCertificate -Creds $UserCredential -EdgeServerName $CurrentServerFQDN -Informative:$Informative -Detailed:$Detailed -CertThumbprint $UCEdgeCertificateData.Thumbprint
}
#endregion

#Modify-ExchHybridCertificate -Creds $UserCredential -CertThumbprint $CertificateData.Thumbprint -EdgeServerName EXED-1.gaw00.local -MBXServerName EXCH-1.gaw00.local