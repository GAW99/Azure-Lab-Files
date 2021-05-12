class SSlBinding
{
    [string]$IPAddress #'IPAddress'
    [string]$Port # 'Port' 
    [string]$CertificateHash #'Certificate Hash'
    [string]$ApplicationId #'Application ID'        
    [string]$CertificateStoreName #'Certificate Store Name'
    [string]$VerifyClientCertificateRevocation # 'Verify Client Certificate Revocation'
    [string]$VerifyRevocationUsingCachedClientCertificateOnly # 'Verify Revocation Using Cached Client Certificate Only'
    [string]$UsageCheck # 'Usage Check'
    [string]$RevocationFreshnessTime # 'Revocation Freshness Time'
    [string]$URLRetrievalTimeout # 'URL Retrieval Timeout' 
    [string]$CtlIdentifier # 'Ctl Identifier'
    [string]$CtlStoreName # 'Ctl Store Name' 
    [string]$DSMapperUsage # 'DS Mapper Usage'
    [string]$NegotiateClientCertificate # 'Negotiate Client Certificate'
    [string]$RejectConnections # 'Reject Connections'
    [string]$DisableHTTP2 # 'Disable HTTP2'
    [string]$DisableQUIC # 'Disable QUIC' 
    [string]$DisableTLS1_2 # 'Disable TLS1.2'
    [string]$DisableTLS1_3 # 'Disable TLS1.3' 
    [string]$DisableOCSPStapling # 'Disable OCSP Stapling'
    [string]$DisableLegacyTLSVersions # 'Disable Legacy TLS Versions'
}

function Get-SSLBindingNetsh 
{
    param(
            [PARAMETER(Mandatory = $false)][switch]$Informative,
            [PARAMETER(Mandatory = $false)][switch]$Detailed,
            [PARAMETER(Mandatory = $false)][string]$ComputerName,
            [PARAMETER(Mandatory = $true)][PSCredential]$Creds
        )
 
    [SSLBinding[]]$Result=@()

    $NetshOutput = Invoke-Command -ComputerName $ComputerName -ScriptBlock { netsh http show sslcert } -Credential $Creds -Authentication Kerberos

    [int32[]]$StartStrings=@()
    
    foreach($OutputLine in $NetshOutput)
    {
        if (($OutputLine.Trim().StartsWith("IP:port")) -or ($OutputLine.Trim().StartsWith("Hostname:port")))
        {
            $StartStrings += ($NetshOutput.IndexOf($OutputLine) )
            if($Informative -or $Detailed) { Write-Host "Cought the first line of the binding and it's index is:" $($NetshOutput.IndexOf($OutputLine)) -ForegroundColor Yellow    }
        }
    }

    if ($StartStrings -gt 1) {$BunchSize = $StartStrings[1] - $StartStrings[0] }
    elseif ($StartStrings -eq 1) {$BunchSize = $NetshOutput.Count - $StartStrings[0] }
    else { throw "No SSL Bindings has been found. Terminating!"}
    if($Detailed) { Write-Host "Currenttly calulated size of the SSL object is $BunchSize lines." -ForegroundColor Cyan    }

    for($i=0;$i -lt $StartStrings.Count ;$i++)
    {
        $SSLBindingCurrent=New-Object -TypeName SSLBinding

        if($Informative -or $Detailed) { Write-Host "Working with the object :" $($NetshOutput[$StartStrings[$i]]) -ForegroundColor Yellow    }
        for($t = $StartStrings[$i]; $t -lt ($StartStrings[$i]+$BunchSize);$t++)
        {
         
            if($Detailed) { Write-Host "Parsing the line:" $NetshOutput[$t] -ForegroundColor Cyan    }           
            if ($NetshOutput[$t].Trim().StartsWith("IP:port") -or $NetshOutput[$t].trim().StartsWith("Hostname:port") ) 
            {
                $TmpString=$null         
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.IPAddress = $TmpString[2].Trim()
                $SSLBindingCurrent.Port = $TmpString[3].Trim()
                if($Detailed) { Write-Host "Parsed result is Hostname = $($SSLBindingCurrent.Address), and IPPort = $($SSLBindingCurrent.Port)." -ForegroundColor Cyan    }  
            }
             
            if ($NetshOutput[$t].Trim().StartsWith("Certificate Hash")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.CertificateHash = $TmpString[1].Trim()
                if($Detailed) { Write-Host "Parsed result of the certificate Thumbrint = $($SSLBindingCurrent.CertificateHas)." -ForegroundColor Cyan    }           
            }

            if ($NetshOutput[$t].Trim().StartsWith("Application ID")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.ApplicationId = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Certificate Store Name")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.CertificateStoreName = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Verify Client Certificate Revocation")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.VerifyClientCertificateRevocation = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Verify Revocation Using Cached Client Certificate Only")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.VerifyRevocationUsingCachedClientCertificateOnly = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Usage Check")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.UsageCheck = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Revocation Freshness Time")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.RevocationFreshnessTime = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("URL Retrieval Timeout")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.URLRetrievalTimeout = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Ctl Identifier")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.CtlIdentifier = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Ctl Store Name")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.CtlStoreName = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("DS Mapper Usage")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.DSMapperUsage = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Negotiate Client Certificate")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.NegotiateClientCertificate = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Reject Connections")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.RejectConnections = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Disable HTTP2")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.DisableHTTP2 = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Disable QUIC")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.DisableQUIC = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Disable TLS1.2")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.DisableTLS1_2 = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Disable TLS1.3")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.DisableTLS1_3 = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Disable OCSP Stapling")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.DisableOCSPStapling = $TmpString[1].Trim()
            }

            if ($NetshOutput[$t].Trim().StartsWith("Disable Legacy TLS Versions")) 
            {
                $TmpString=$null
                $TmpString = ($NetshOutput[$t].trim()).Split(':')
                $SSLBindingCurrent.DisableLegacyTLSVersions = $TmpString[1].Trim()
            }
        }
        $Result+=$SSLBindingCurrent
        Remove-Variable SSLBindingCurrent -Force
    }
    return $Result
}

function New-SSLBindingNetsh 
{
    param(
            [PARAMETER(Mandatory = $false)][switch]$Informative,
            [PARAMETER(Mandatory = $false)][switch]$Detailed,
            [PARAMETER(Mandatory = $true)][SSlBinding]$SSLBindingObject,
            [PARAMETER(Mandatory = $true)][string]$ComputerName,
            [PARAMETER(Mandatory = $true)][PSCredential]$Creds,
            [PARAMETER(Mandatory = $true)][string]$NewSertThumbprint
        )

    if($Informative -or $Detailed) { Write-Host "Creating an SSL binding for the $($SSLBindingObject.IPAddress):$($SSLBindingObject.Port) and the certificate: $($SSLBindingObject.CertificateHash)" -ForegroundColor Yellow    }
    if($Detailed) { Write-Host "Current SSL Binding object is:" -ForegroundColor Cyan; $SSLBindingObject | Format-List  }
    $ScriptString = "netsh http add sslcert hostnameport="+ $SSLBindingObject.IPAddress+':'+$SSLBindingObject.Port + " certhash="+ $NewSertThumbprint + " appid='"+$SSLBindingObject.ApplicationId+ "' certstorename="+ $SSLBindingObject.CertificateStoreName+" sslctlstorename="+ $SSLBindingObject.CtlStoreName
    if($Detailed) { Write-Host "We are going to run the command: $ScriptString" -ForegroundColor Cyan  }
    $ScriptBlock = [Scriptblock]::Create($ScriptString) 
    Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -Credential $Creds -Authentication Kerberos
}

function Remove-SSLBindingNetsh 
{
    param(
            [PARAMETER(Mandatory = $false)][switch]$Informative,
            [PARAMETER(Mandatory = $false)][switch]$Detailed,
            [PARAMETER(Mandatory = $true)][SSlBinding]$SSLBindingObject,
            [PARAMETER(Mandatory = $true)][string]$ComputerName,
            [PARAMETER(Mandatory = $true)][PSCredential]$Creds
        )

    if($Informative -or $Detailed) { Write-Host "We are going to delete an SSL binding for the $($SSLBindingObject.IPAddress):$($SSLBindingObject.Port) and the certificate: $($SSLBindingObject.CertificateHash)" -ForegroundColor Yellow    }
    if($Detailed) { Write-Host "Current SSL Binding object is:" -ForegroundColor Cyan; $SSLBindingObject | Format-List  }
    $ScriptString = "netsh http delete sslcert hostnameport="+ $SSLBindingObject.IPAddress+':'+$SSLBindingObject.Port
    if($Detailed) { Write-Host "We are going to run the command: $ScriptString" -ForegroundColor Cyan  }
    $ScriptBlock = [Scriptblock]::Create($ScriptString) 
    Invoke-Command -ComputerName $ComputerName -ScriptBlock $ScriptBlock -Credential $Creds -Authentication Kerberos
}