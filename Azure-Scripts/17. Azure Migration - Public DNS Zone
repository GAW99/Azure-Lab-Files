$ScriptRootDir = Split-Path $MyInvocation.MyCommand.Definition -Parent
Import-Module Az

if (!$AzureCred) { $AzureCred = Get-Credential -Message "Please enter credentials for Azure"}
if ([string]::IsNullOrEmpty($(Get-AzContext).Account)) { Connect-AzAccount -Credential $AzureCred }

# Declare variables
$Culture = [Globalization.CultureInfo]::InvariantCulture

#Resource Group for Migration Project
$DNSSubsNum = 1
$DNSRGName = "DNSRG-NorthEU"
$DNSLocation = "northeurope" 
$DNSTags= @{Environment="Lab";Project="Azure Migration"}
$DNSForwardZoneName="gaw00.tk"
$DNSReverseZoneName="43.31.95.in-addr.arpa"

$PTRFileName = "PTRRecords.csv"
$MXFileName = "MXRecords.csv"
$TXTFileName= "TXTRecords.csv"
$SRVFileName = "SRVRecords.csv"
$CNAMEFileName= "CNAMERecords.csv"
$AFileName= "ARecords.csv"

#Importing Data
$PTRRecords = @( Import-Csv  -Delimiter ";" -Encoding Default -Path ($ScriptRootDir +'\'+$PTRFileName) )
$MXRecords = @( Import-Csv  -Delimiter ";" -Encoding Default -Path ($ScriptRootDir +'\'+$MXFileName) )
$TXTRecords= @( Import-Csv  -Delimiter ";" -Encoding Default -Path ($ScriptRootDir +'\'+$TXTFileName) )
$SRVRecords = @( Import-Csv  -Delimiter ";" -Encoding Default -Path ($ScriptRootDir +'\'+$SRVFileName) )
$CNAMERecords= @( Import-Csv  -Delimiter ";" -Encoding Default -Path ($ScriptRootDir +'\'+$CNAMEFileName) )
$ARecords= @( Import-Csv  -Delimiter ";" -Encoding Default -Path ($ScriptRootDir +'\'+$AFileName) )
<#
$PTRRecords | FT -AutoSize
$MXRecords | FT -AutoSize
$TXTRecords | FT -AutoSize
$SRVRecords | FT -AutoSize
$CNAMERecords | FT -AutoSize
$ARecords | FT -AutoSize
#>

#Switch to the Correct Subscription 
$DNSSubs = (Get-AzSubscription  | Where-Object {$_.Name -like "$DNSSubsNum*"})
Set-AzContext -Subscription $DNSSubs.Id

# Create a resource group
$DNSRG = New-AzResourceGroup -Name $DNSRGName -Location $DNSLocation -Tag $DNSTags 

#Create DNS zones
$DNSForwardZone = New-AzDnsZone -Name $DNSForwardZoneName -ResourceGroupName $DNSRG.ResourceGroupName -Tag $DNSTags -ZoneType "Public"
$DNSReverseZone = New-AzDnsZone -Name $DNSReverseZoneName -ResourceGroupName $DNSRG.ResourceGroupName -Tag $DNSTags -ZoneType "Public"

#Creating PTR records (sets)
foreach ($PTRRecord in $PTRRecords) 
{
    $RecordConfigs=@()
    if(!(get-azdnsrecordset -Name $PTRRecord.HostName -ZoneName $DNSReverseZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -RecordType PTR -ErrorAction SilentlyContinue)) 
    {
        Write-host "$($PTRRecord.HostName) does not exist, creating... " -ForegroundColor Green
        foreach ($PTRRecord2 in $PTRRecords) 
        {
            if ($PTRRecord2.HostName -eq $PTRRecord.HostName ) 
            {
                $RecordConfigs += New-AzDnsRecordConfig -Ptrdname $PTRRecord2.PtrDomainName
            }
        }
        $RecordConfigs
        $TempTTL = [DateTime]::ParseExact($PTRRecord.TimeToLive, 'HH:mm:ss', $Culture)
        $TTL = (New-TimeSpan -Seconds $TempTTL.Second -Minutes $TempTTL.Minute -Hours $TempTTL.Hour).TotalSeconds
        $TTL
        New-AzDnsRecordSet -Name $PTRRecord.HostName -RecordType PTR -ZoneName $DNSReverseZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -Ttl $TTL -DnsRecords $RecordConfigs
    }
    else 
    {
        Write-host "$($PTRRecord.HostName) does exist, skipping... " -ForegroundColor Red
    }  
}

#Creating MX records (sets)
foreach ($MXRecord in $MXRecords) 
{
    $RecordConfigs=@()
    if(!(get-azdnsrecordset -Name $MXRecord.HostName -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -RecordType MX -ErrorAction SilentlyContinue)) 
    {
        Write-host "$($MXRecord.HostName) does not exist, creating... " -ForegroundColor Green
        foreach ($MXRecord2 in $MXRecords) 
        {
            if ($MXRecord2.HostName -eq $MXRecord.HostName ) 
            {
                $RecordConfigs += New-AzDnsRecordConfig -Exchange $MXRecord2.MailExchange -Preference $MXRecord2.Preference
            }
        }
        $RecordConfigs
        $TempTTL = [DateTime]::ParseExact($MXRecord.TimeToLive, 'HH:mm:ss', $Culture)
        $TTL = (New-TimeSpan -Seconds $TempTTL.Second -Minutes $TempTTL.Minute -Hours $TempTTL.Hour).TotalSeconds
        $TTL
        New-AzDnsRecordSet -Name $MXRecord.HostName -RecordType MX -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -Ttl $TTL -DnsRecords $RecordConfigs
    }
    else 
    {
        Write-host "$($MXRecord.HostName) does exist, skipping... " -ForegroundColor Red
    }  
}

#Creating TXT records (sets)
foreach ($TXTRecord in $TXTRecords) 
{
    $RecordConfigs=@()
    if(!(get-azdnsrecordset -Name $TXTRecord.HostName -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -RecordType TXT -ErrorAction SilentlyContinue)) 
    {
        Write-host "$($TXTRecord.HostName) does not exist, creating... " -ForegroundColor Green
        foreach ($TXTRecord2 in $TXTRecords) 
        {
            if ($TXTRecord2.HostName -eq $TXTRecord.HostName ) 
            {
                $RecordConfigs += New-AzDnsRecordConfig -Value $TXTRecord2.DescriptiveText
            }
        }
        $RecordConfigs
        $TempTTL = [DateTime]::ParseExact($TXTRecord.TimeToLive, 'HH:mm:ss', $Culture)
        $TTL = (New-TimeSpan -Seconds $TempTTL.Second -Minutes $TempTTL.Minute -Hours $TempTTL.Hour).TotalSeconds
        $TTL
        New-AzDnsRecordSet -Name $TXTRecord.HostName -RecordType TXT -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -Ttl $TTL -DnsRecords $RecordConfigs
    }
    else 
    {
        Write-host "$($TXTRecord.HostName) does exist, skipping... " -ForegroundColor Red
    }  
}

#Creating SRV records (sets)
foreach ($SRVRecord in $SRVRecords) 
{
    $RecordConfigs=@()
    if(!(get-azdnsrecordset -Name $SRVRecord.HostName -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -RecordType SRV -ErrorAction SilentlyContinue)) 
    {
        Write-host "$($SRVRecord.HostName) does not exist, creating... " -ForegroundColor Green
        foreach ($SRVRecord2 in $SRVRecords) 
        {
            if ($SRVRecord2.HostName -eq $SRVRecord.HostName ) 
            {
                $RecordConfigs += New-AzDnsRecordConfig -Priority $SRVRecord2.Priority -Weight $SRVRecord2.Weight -Port $SRVRecord2.Port -Target $SRVRecord2.DomainName
            }
        }
        $RecordConfigs
        $TempTTL = [DateTime]::ParseExact($SRVRecord.TimeToLive, 'HH:mm:ss', $Culture)
        $TTL = (New-TimeSpan -Seconds $TempTTL.Second -Minutes $TempTTL.Minute -Hours $TempTTL.Hour).TotalSeconds
        $TTL
        New-AzDnsRecordSet -Name $SRVRecord.HostName -RecordType SRV -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -Ttl $TTL -DnsRecords $RecordConfigs
    }
    else 
    {
        Write-host "$($SRVRecord.HostName) does exist, skipping... " -ForegroundColor Red
    }  
}

#Creating CNAME records (sets)
foreach ($CNAMERecord in $CNAMERecords) 
{
    $RecordConfigs=@()
    if(!(get-azdnsrecordset -Name $CNAMERecord.HostName -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -RecordType CNAME -ErrorAction SilentlyContinue)) 
    {
        Write-host "$($CNAMERecord.HostName) does not exist, creating... " -ForegroundColor Green
        foreach ($CNAMERecord2 in $CNAMERecords) 
        {
            if ($CNAMERecord2.HostName -eq $CNAMERecord.HostName ) 
            {
                $RecordConfigs += New-AzDnsRecordConfig -Cname $CNAMERecord2.HostNameAlias
            }
        }
        $RecordConfigs
        $TempTTL = [DateTime]::ParseExact($CNAMERecord.TimeToLive, 'HH:mm:ss', $Culture)
        $TTL = (New-TimeSpan -Seconds $TempTTL.Second -Minutes $TempTTL.Minute -Hours $TempTTL.Hour).TotalSeconds
        $TTL
        New-AzDnsRecordSet -Name $CNAMERecord.HostName -RecordType CNAME -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -Ttl $TTL -DnsRecords $RecordConfigs
    }
    else 
    {
        Write-host "$($CNAMERecord.HostName) does exist, skipping... " -ForegroundColor Red
    }  
}

#Creating A records (sets)
foreach ($ARecord in $ARecords) 
{
    $RecordConfigs=@()
    if(!(get-azdnsrecordset -Name $ARecord.HostName -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -RecordType A -ErrorAction SilentlyContinue)) 
    {
        Write-host "$($ARecord.HostName) does not exist, creating... " -ForegroundColor Green
        foreach ($ARecord2 in $ARecords) 
        {
            if ($ARecord2.HostName -eq $ARecord.HostName ) 
            {
                $RecordConfigs += New-AzDnsRecordConfig -IPv4Address $ARecord2.IPv4Address
            }
        }
        $RecordConfigs
        $TempTTL = [DateTime]::ParseExact($ARecord.TimeToLive, 'HH:mm:ss', $Culture)
        $TTL = (New-TimeSpan -Seconds $TempTTL.Second -Minutes $TempTTL.Minute -Hours $TempTTL.Hour).TotalSeconds
        $TTL
        New-AzDnsRecordSet -Name $ARecord.HostName -RecordType A -ZoneName $DNSForwardZone.Name -ResourceGroupName $DNSRG.ResourceGroupName -Ttl $TTL -DnsRecords $RecordConfigs
    }
    else 
    {
        Write-host "$($ARecord.HostName) does exist, skipping... " -ForegroundColor Red
    }  
}
