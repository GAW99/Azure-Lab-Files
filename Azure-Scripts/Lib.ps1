﻿function Request-LECertificate
{
Param(
    [PARAMETER(Mandatory = $false)][switch]$Informative,
    [PARAMETER(Mandatory = $false)][switch]$Detailed,
    [PARAMETER(Mandatory = $false)][string]$DNSServerName,
    [PARAMETER(Mandatory = $false)][PSCredential]$DNSServerCred,
    [PARAMETER(Mandatory = $false)][string[]]$CertNames,
    [PARAMETER(Mandatory = $false)][System.Security.SecureString]$CertPassword, #Default password is 'poshacme'
    [PARAMETER(Mandatory = $false)][string]$ContactEmail,
    [PARAMETER(Mandatory = $false)][string]$CertFriendlyName,
    [PARAMETER(Mandatory = $false)][switch]$Testing
    )

    if ($Testing) 
    { 
        Set-PAServer LE_STAGE
        if($Informative -or $Detailed) {Write-Host "Using Staging Server" -ForegroundColor Green}
    } #To use staging server 
    else 
    {
        Set-PAServer LE_PROD 
        if($Informative -or $Detailed) {Write-Host "Using Production Server" -ForegroundColor Red}
    }

    if ($DNSServerName)
    {
        if($Informative -or $Detailed) {Write-Host "Conducting automated Windows DNS challenge" -ForegroundColor Yellow}
        $Cert = New-PACertificate $CertNames -AcceptTOS -Contact $ContactEmail -FriendlyName $CertFriendlyName -PfxPassSecure $CertPassword -Plugin Windows -PluginArgs @{WinServer=$DNSServerName; WinCred=$DNSServerCred} -Force
        #$Cert = New-PACertificate $CertNames -AcceptTOS -Contact $ContactEmail -FriendlyName $CertFriendlyName -PfxPass $CertPassword -Plugin Windows -PluginArgs @{WinServer=$DNSServerName; WinCred=$DNSServerCred; WinUseSSL=$true} -Force
        #$Cert = New-PACertificate $CertNames -AcceptTOS -Contact $ContactEmail -FriendlyName "Mail" -PfxPass $CertPassword -Plugin Windows -PluginArgs @{WinServer=$DNSServerName; WinCred=$DNSServerCred} -Force
    }
    else
    {
        if($Informative -or $Detailed) {Write-Host "Conducting MANUAL DNS challenge" -ForegroundColor Yellow}
        $Cert = New-PACertificate $CertNames -AcceptTOS -Contact $ContactEmail -FriendlyName $CertFriendlyName -PfxPass $CertPassword -Force
    }
    return $cert
}

function Copy-LECertificate
{
Param(
    [PARAMETER(Mandatory = $false)][switch]$Informative,
    [PARAMETER(Mandatory = $false)][switch]$Detailed,
    [PARAMETER(Mandatory = $true)][string]$RootSharePath,
    [PARAMETER(Mandatory = $true)][PSCredential]$Creds,
    [PARAMETER(Mandatory = $true)][String]$PFXLocalFileName, 
    [PARAMETER(Mandatory = $true)][System.Security.SecureString]$CertPassword, #Default password is 'poshacme'
    [PARAMETER(Mandatory = $true)][String]$PasswordFileName 
    )
    
    if (!(Get-PSDrive -Name X -ErrorAction SilentlyContinue)) {New-PSDrive -Name X -PSProvider FileSystem -Root $RootSharePath -Credential $Creds -Persist| Out-Null}
    
    $PFXLocalDirectory = (Get-Item -Path $PFXLocalFileName).DirectoryName
    $PFXLocalName = (Get-Item -Path $PFXLocalFileName).Name
    
    Get-ChildItem -Path $PFXLocalDirectory | Copy-Item -Destination X:\ -Force # only child items
    
    $CertPassword | ConvertFrom-SecureString -Key (1..16) | Out-File ("X:\"+$PasswordFileName) -Force
}

function Install-LECertificate
{
Param(
    [PARAMETER(Mandatory = $false)][switch]$Informative,
    [PARAMETER(Mandatory = $false)][switch]$Detailed,
    [PARAMETER(Mandatory = $true)][string]$RootSharePath,
    [PARAMETER(Mandatory = $true)][PSCredential]$Creds,
    [PARAMETER(Mandatory = $true)][String]$PFXFileName, 
    [PARAMETER(Mandatory = $true)][String]$PasswordFileName,
    [PARAMETER(Mandatory = $true)][String]$ComputerFQDN
    )
    
    if($Informative -or $Detailed) { Write-Host "Installing the certificate to the Personal storage of the computer:" $ComputerFQDN -ForegroundColor Yellow}
    
    $Script =
    {
        param ($RootSharePath,$PFXFileName,$Informative,$Detailed,$PasswordFileName)
        $PFXDomainFullFileName = $RootSharePath+"\"+$PFXFileName
        if($Informative -or $Detailed) { Write-Host "Current PFX file is:" $PFXDomainFullFileName -ForegroundColor Yellow}
        $SecurePasswordEncrypted = Get-Content -Path ($RootSharePath+"\"+$PasswordFileName)
        if($Informative -or $Detailed) { Write-Host "Getting password from the file:"$RootSharePath"\"$PasswordFileName -ForegroundColor Yellow}
        $SecurePassword = ($SecurePasswordEncrypted | ConvertTo-SecureString -Key (1..16))
        Import-PfxCertificate -FilePath $PFXDomainFullFileName -CertStoreLocation Cert:\LocalMachine\my -Password $SecurePassword -Confirm:$false
    }

    Invoke-Command -ComputerName $ComputerFQDN -Credential $Creds -Authentication Credssp -ScriptBlock $Script -ArgumentList $RootSharePath,$PFXFileName,$Informative,$Detailed,$PasswordFileName
}

function CleanUP-LECertificate
{
Param(
    [PARAMETER(Mandatory = $false)][switch]$Informative,
    [PARAMETER(Mandatory = $false)][switch]$Detailed,
    [PARAMETER(Mandatory = $true)][PSCredential]$Creds,
    [PARAMETER(Mandatory = $true)][string]$RootSharePath
    )
        if($Informative -or $Detailed) { Write-Host "Connecting drive X to the path:" $RootSharePath -ForegroundColor Cyan}
        if (!(Get-PSDrive -Name X -ErrorAction SilentlyContinue)) 
        {
            New-PSDrive -Name X -PSProvider FileSystem -Root $RootSharePath -Credential $Creds | Out-Null
        }
        
        if($Informative -or $Detailed) { Write-Host "Removing all date from the common certificate storage!" -ForegroundColor Cyan}
        Get-ChildItem -Path X:\ -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Get-PSDrive -Name X -ErrorAction SilentlyContinue | Remove-PSDrive -Force 
}

function Enable-ExchMBXCertificate
{
Param(
    [PARAMETER(Mandatory = $false)][switch]$Informative = $false,
    [PARAMETER(Mandatory = $false)][switch]$Detailed = $false,
    [PARAMETER(Mandatory = $true)][PSCredential]$Creds,
    [PARAMETER(Mandatory = $true)][string]$CertThumbprint,
    [PARAMETER(Mandatory = $true)][string]$MBXServerName
    )

        if($Informative -or $Detailed) {Write-Host "The session to the server $MBXServerName is being established..." -ForegroundColor Cyan }
        $CurrentConnectionURL = ("http://"+$MBXServerName+"/powershell/") 
        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri ("http://"+$MBXServerName+"/powershell/") -Credential $Creds -Authentication Kerberos
        Import-PSSession $Session -DisableNameChecking -AllowClobber
        if($Informative -or $Detailed) {Write-Host "Enabling the certificate on the server $MBXServerName" -ForegroundColor Cyan }
        Get-ExchangeCertificate -Server $MBXServerName -Thumbprint $CertThumbprint | Enable-ExchangeCertificate -Services IIS -Server $MBXServerName 
        Invoke-Command -ComputerName $MBXServerName -Credential $Creds -Authentication Kerberos -ScriptBlock {iisreset } 
        $Session | Remove-PSSession 
}

function Enable-ExchEdgeCertificate
{
Param(
    [PARAMETER(Mandatory = $false)][switch]$Informative = $true,
    [PARAMETER(Mandatory = $false)][switch]$Detailed = $true,
    [PARAMETER(Mandatory = $true)][PSCredential]$Creds,
    [PARAMETER(Mandatory = $true)][string]$CertThumbprint,
    [PARAMETER(Mandatory = $true)][string]$EdgeServerName
     )
    $Script = {
    param ($Informative,$Detailed,$CertThumbprint,$EdgeServerName)
    Import-Module ActiveDirectory
    Add-PSSnapin *exchange*
    $Server = Get-ExchangeServer $EdgeServerName
    $TransportCert = (Get-ADObject -Identity $Server.DistinguishedName -Properties * -Server ($EdgeServerName+":50389")).msExchServerInternalTLSCert
    $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $CertBlob = [System.Convert]::ToBase64String($TransportCert)
    $Cert.Import([Convert]::FromBase64String($CertBlob))
                            
    if($Informative -or $Detailed) { Write-Host "The current default SMTP certificate has subject" $Cert.Subject ", frindly name:" $Cert.FriendlyName ", ThumbPrint:" $Cert.Thumbprint "and expires after:" $Cert.NotAfter -ForegroundColor Yellow}
    $OriginalCertThumbprint = $Cert.Thumbprint

    Enable-ExchangeCertificate -Thumbprint $CertThumbprint -Services SMTP -Force 
    Enable-ExchangeCertificate -Thumbprint $OriginalCertThumbprint -Services SMTP -Force 

    Get-Service -Name MSExch* -ComputerName $EdgeServerName | Restart-Service -Force 
    Get-Service -Name MSExch* -ComputerName $EdgeServerName | Where-Object {$_.Status -ne "Running"} | Start-Service 

    $Cert =$null
    $TransportCert = (Get-ADObject -Identity $Server.DistinguishedName -Properties * -Server ($EdgeServerName+":50389")).msExchServerInternalTLSCert
    $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
    $CertBlob = [System.Convert]::ToBase64String($TransportCert)
    $Cert.Import([Convert]::FromBase64String($CertBlob))
    if($Informative -or $Detailed) { Write-Host "The current default SMTP certificate has subject" $Cert.Subject ", frindly name:" $Cert.FriendlyName ", ThumbPrint:" $Cert.Thumbprint "and expires after:" $Cert.NotAfter -ForegroundColor Yellow}
    }
    Invoke-Command -ComputerName $EdgeServerName -Credential $Creds -Authentication Credssp -ScriptBlock $Script -ArgumentList $Informative,$Detailed,$CertThumbprint,$EdgeServerName
}