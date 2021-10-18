$ReverseZoneName = "43.31.95.in-addr.arpa" 
$ForwardZoneName = "gaw00.tk"
$PTRRecords = @()
$MXRecords = @()
$TXTRecords= @()
$SRVRecords = @()
$CNAMERecords= @()
$ARecords= @()

$DNSZones = Get-DnsServerZone 
$DNSZones| Export-Csv -Delimiter ";" -Force -Encoding Default -NoClobber -NoTypeInformation -Path C:\Zones.csv -Confirm:$false

$ReverseRecords = Get-DnsServerResourceRecord -ZoneName $ReverseZoneName

$ReverseRecords | Where-Object {$_.RecordType -eq "PTR"} | foreach `
{
    Add-Member -InputObject $_ -name PtrDomainName -Value $_.RecordData.PtrDomainName -MemberType NoteProperty
    $PTRRecords += $_
} 
$PTRRecords | Export-Csv -Delimiter ";" -Force -Encoding Default -NoClobber -NoTypeInformation -Path C:\PTRRecords.csv -Confirm:$false

$ForwardRecords = Get-DnsServerResourceRecord -ZoneName $ForwardZoneName

$ForwardRecords | Where-Object {$_.RecordType -eq "MX"} | foreach `
{
    Add-Member -InputObject $_ -name MailExchange -Value $_.RecordData.MailExchange -MemberType NoteProperty
    Add-Member -InputObject $_ -name Preference -Value $_.RecordData.Preference -MemberType NoteProperty
    $MXRecords += $_
} 
$MXRecords | Export-Csv -Delimiter ";" -Force -Encoding Default -NoClobber -NoTypeInformation -Path C:\MXRecords.csv -Confirm:$false

$ForwardRecords | Where-Object {$_.RecordType -eq "TXT"} | foreach `
{
    Add-Member -InputObject $_ -name DescriptiveText -Value $_.RecordData.DescriptiveText -MemberType NoteProperty
    $TXTRecords += $_
} 
$TXTRecords | Export-Csv -Delimiter ";" -Force -Encoding Default -NoClobber -NoTypeInformation -Path C:\TXTRecords.csv -Confirm:$false

$ForwardRecords | Where-Object {$_.RecordType -eq "SRV"} | foreach `
{
    Add-Member -InputObject $_ -name DomainName -Value $_.RecordData.DomainName -MemberType NoteProperty
    Add-Member -InputObject $_ -name Port -Value $_.RecordData.Port -MemberType NoteProperty
    Add-Member -InputObject $_ -name Priority -Value $_.RecordData.Priority -MemberType NoteProperty
    Add-Member -InputObject $_ -name Weight -Value $_.RecordData.Weight -MemberType NoteProperty
    $SRVRecords += $_
} 
$SRVRecords | Export-Csv -Delimiter ";" -Force -Encoding Default -NoClobber -NoTypeInformation -Path C:\SRVRecords.csv -Confirm:$false

$ForwardRecords | Where-Object {$_.RecordType -eq "CNAME"} | foreach `
{
    Add-Member -InputObject $_ -name HostNameAlias -Value $_.RecordData.HostNameAlias -MemberType NoteProperty
    $CNAMERecords += $_
} 
$CNAMERecords | Export-Csv -Delimiter ";" -Force -Encoding Default -NoClobber -NoTypeInformation -Path C:\CNAMERecords.csv -Confirm:$false

$ForwardRecords | Where-Object {$_.RecordType -eq "A"} | foreach `
{
    Add-Member -InputObject $_ -name IPv4Address -Value $_.RecordData.IPv4Address -MemberType NoteProperty
    $ARecords += $_
} 
$ARecords | Export-Csv -Delimiter ";" -Force -Encoding Default -NoClobber -NoTypeInformation -Path C:\ARecords.csv -Confirm:$false