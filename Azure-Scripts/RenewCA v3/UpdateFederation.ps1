function Modify-ExchHybridCertificate
{
Param(
    [PARAMETER(Mandatory = $false)][switch]$Informative = $true,
    [PARAMETER(Mandatory = $false)][switch]$Detailed = $true,
    [PARAMETER(Mandatory = $true)][PSCredential]$Creds,
    [PARAMETER(Mandatory = $true)][string]$CertThumbprint,
    [PARAMETER(Mandatory = $true)][string]$EdgeServerName,
    [PARAMETER(Mandatory = $true)][string]$MBXServerName
     )
    
    if((Get-Module -ListAvailable -Name ExchangeOnlineManagement) -eq $null) 
    {
        if($Detailed) 
        { 
            Write-Host "ExchangeOnlineManagement module is not installed, fixing" -ForegroundColor Cyan
        } 
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name NuGet -Force
        Install-Module ExchangeOnlineManagement -Force:$true -Confirm:$false 
    }
    
    if($Detailed) { Write-Host "Importing ExchangeOnlineManagement module..." -ForegroundColor Cyan}
    
    Import-Module ExchangeOnlineManagement
        
    if($Informative -or $Detailed) {Write-Host "The session to the server $MBXServerName is being established..." -ForegroundColor Cyan }
    $CurrentConnectionURL = ("http://"+$MBXServerName+"/powershell/") 
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri ("http://"+$MBXServerName+"/powershell/") -Credential $Creds -Authentication Kerberos
    Import-PSSession $Session -DisableNameChecking -AllowClobber
    #if($Informative -or $Detailed) {Write-Host "Enabling the certificate on the server $MBXServerName" -ForegroundColor Cyan }
    
    if($Informative -or $Detailed) { Write-Host "Executing part of the script on the Mailbox Server:$MBXServerName" -ForegroundColor Yellow}
           
    # Check if there is a active EXO sessions
    if($Detailed) {Write-Host "Collecting oppened sessions..." -ForegroundColor Cyan}
    $psSessions = Get-PSSession | Select-Object -Property State, Name
    If (((@($psSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0) -ne $true) {if($Detailed) {Write-Host "Open a new session..." -ForegroundColor Cyan}; Connect-ExchangeOnline -ShowProgress $true }
             
    $Cert = Get-ExchangeCertificate -Thumbprint $CertThumbprint -Server $MBXServerName             
    if($Informative -or $Detailed) { Write-Host "The current default SMTP certificate has subject" $Cert.Subject ", frindly name:" $Cert.FriendlyName ", ThumbPrint:" $Cert.Thumbprint "and expires after:" $Cert.NotAfter -ForegroundColor Yellow}
    $TLSCertName = (‘<I>’+$Cert.issuer+'<S>’+$Cert.subject) 
    if($Detailed) { Write-Host "Name of the certificate will be:$TLSCertName" -ForegroundColor Cyan}
    
    Set-HybridConfiguration -TLSCertificateName $TLSCertName

    Get-SendConnector | Where-Object {$_.Identity -like "Outbound to Office 365*"} | Set-SendConnector -TLSCertificateName $TLSCertName


    #Enable-OrganizationCustomization

    #Get-Service -Name MSExch* -ComputerName $MBXServerName | Restart-Service -Force 
    #Get-Service -Name MSExch* -ComputerName $MBXServerName | Where-Object {$_.Status -ne "Running"} | Start-Service 

    Disconnect-ExchangeOnline -Confirm:$false
    $Session | Remove-PSSession 
    
    $EdgeScript = {
    param ($Informative,$Detailed,$CertThumbprint,$EdgeServerName)
    if($Informative -or $Detailed) { Write-Host "Executing part of the script on the Edge Server:$EdgeServerName" -ForegroundColor Yellow}
    Add-PSSnapin *exchange*
    
    $Cert = Get-ExchangeCertificate -Thumbprint $CertThumbprint               
    if($Informative -or $Detailed) { Write-Host "The current default SMTP certificate has subject" $Cert.Subject ", frindly name:" $Cert.FriendlyName ", ThumbPrint:" $Cert.Thumbprint "and expires after:" $Cert.NotAfter -ForegroundColor Yellow}
    $TLSCertName = (‘<I>’+$Cert.issuer+'<S>’+$Cert.subject) 
    if($Detailed) { Write-Host "Name of the certificate will be:$TLSCertName" -ForegroundColor Cyan}
    
    #Get-SendConnector | Where-Object {$_.Identity -like "Outbound to Office 365*"} | Set-SendConnector -TLSCertificateName $TLSCertName

    Get-ReceiveConnector | Where-Object {$_.Identity -like "*\Default internal receive connector*"}  | Set-ReceiveConnector -TLSCertificateName $TLSCertName

    Get-Service -Name MSExch* -ComputerName $EdgeServerName | Restart-Service -Force 
    Get-Service -Name MSExch* -ComputerName $EdgeServerName | Where-Object {$_.Status -ne "Running"} | Start-Service
    }
    
    Invoke-Command -ComputerName $EdgeServerName -Credential $Creds -Authentication Credssp -ScriptBlock $EdgeScript -ArgumentList $Informative,$Detailed,$CertThumbprint,$EdgeServerName
}