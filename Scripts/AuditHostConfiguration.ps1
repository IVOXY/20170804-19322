#Get the name of the ESXi host to be configured
$VMhost = Read-Host -Prompt "Enter the ESXi host name (ex: labesx03)"

#Get XML File configurations
Write-Host "Gathering XML file configurations..." -foreground "Yellow"
$filePortgroups = "C:\Users\joshd\Documents\Ivoxy\Lighthouse\cdb\XML\xml-portgroups.xml"
$fileHostParams = "C:\Users\joshd\Documents\Ivoxy\Lighthouse\cdb\XML\xml-hostconfig.xml"
$fileDatastores = "C:\Users\joshd\Documents\Ivoxy\Lighthouse\cdb\XML\xml-datastores.xml"
$xmlPortGroups = [System.Xml.XmlDocument](Get-Content $filePortgroups)
$xmlHostParams = [System.Xml.XmlDocument](Get-Content $fileHostParams)
$xmlDatastores = [System.Xml.XmlDocument](Get-Content $fileDatastores)
$xmlHostConfig = $xmlHostParams.hostConfig.host | Where name -contains $VMhost

#Combine the entered ESXi Hostname with the configured domain name
Write-Host "Creating ESXi Fully Qualified Domain Name" -foreground "Yellow"
$ESXiHost = $VMhost + "." + $xmlHostParams.hostConfig.commonParams.domainName

#Get host settings
$getHost = Get-VMHost $ESXiHost

#Check DNS
Write-Host "Checking DNS Servers..." -foreground "Yellow"
$dnsHost = $getHost | Get-VMHostNetwork
IF (($dnsHost.dnsaddress -notcontains $xmlHostParams.hostConfig.commonParams.dnsServer1) -OR ($dnsHost.dnsaddress -notcontains $xmlHostParams.hostConfig.commonParams.dnsServer2)){Write-Host "DNS Servers are not configured properly on $VMHost" -foreground "Red"}ELSE{Write-Host "DNS Servers are properly configured on $VMHost" -foreground "Green"}

Write-Host "Checking Search Domain..." -foreground "Yellow"
IF ($dnsHost.SearchDomain -ne $xmlHostParams.hostconfig.commonparams.domainname){Write-Host "Search domain not configured properly on $VMHost" -foreground "Red"}ELSE{Write-Host "Search domain configured properly on $VMHost" -foreground "Green"}

Write-Host "Checking Domain name..." -foreground "Yellow"
IF ($dnsHost.DomainName -ne $xmlHostParams.hostconfig.commonparams.domainname){Write-Host "Domain not configured properly on $VMHost" -foreground "Red"}ELSE{Write-Host "Domain configured properly on $VMHost" -foreground "Green"}

#Check Syslog
Write-Host "Checking Syslog server..." -foreground "Yellow"
$syslog = $getHost | Get-AdvancedSetting -name syslog.global.loghost
IF ($syslog.value -ne $xmlHostParams.hostconfig.commonparams.syslogServer){Write-Host "Syslog server not configured properly on $VMHost" -foreground "Red"}ELSE{Write-Host "Syslog configured properly on $VMHost" -foreground "Green"}

#Check NTP
Write-Host "Checking NTP Server..." -foreground "Yellow"
IF (($getHost | Get-VMHostNtpServer) -ne $xmlHostParams.hostconfig.commonparams.ntpServer){Write-Host "NTP Server not configured properly on $VMHost" -foreground "Red"}ELSE{Write-Host "NTP Server configured properly on $VMHost" -foreground "Green"}

#Check SSH
Write-Host "Checking SSH configuration..." -foreground "Yellow"
$sshHost = $getHost | Get-VMHostService | Where-Object {$_.key -eq "TSM-SSH"}
IF ($sshHost.Policy -ne $xmlHostConfig.enableSSH){Write-Host "SSH not configured properly on $VMHost" -foreground "Red"}ELSE{Write-Host "SSH properly configured on $VMHost" -foreground "Green"}

#Get Power Policy
Write-Host "Checking current Power Policy..." -foreground "Yellow"
IF ($getHost.ExtensionData.Config.PowerSystemInfo.CurrentPolicy.Key -ne "1"){Write-Host "Current Power Policy not configured properly on $VMHost" -foreground "Red"}ELSE{Write-Host "Current Power Policy properly configured on $VMHost" -foreground "Green"}

#Audit Datastores
Write-Host "Checking the existing and desired datastores..." -foreground "Yellow"
$hostds = $getHost | Get-Datastore | Sort Name
$datastores = $xmlDatastores.datastores.datastore | Where cluster -like $hostconfig.cluster | Sort Name
$hostNumber = $hostds.count
$configuredNumber = $datastores.count
Write-Host "Current Datastores: $hostNumber | Desired Datastores: $configuredNumber" -foreground "Yellow"
$Report = @()
$ReportRow = "" | Select-Object Current, Desired
$ReportRow.Current = $hostds.name
$ReportRow.Desired = $datastores.name
$Report += $ReportRow
