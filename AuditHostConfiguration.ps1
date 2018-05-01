#Enter the name of the vCenter to connect to
Write-Host "Enter the FQDN of the " -NoNewline
Write-Host "[vCenter Server]" -ForegroundColor Red -NoNewline
Write-Host " to connect to: " -NoNewline
$vCenterFqdn = Read-Host
Start-Sleep 5
Connect-viserver $vCenterFqdn

#Get XML File configurations
Write-Host "Gathering XML file configurations..." -foreground "Yellow"
$filePortgroups = "C:\Users\joshd\Desktop\SwitchScripts\XML\Portgroups.xml"
$fileHostParams = "C:\Users\joshd\Desktop\SwitchScripts\XML\HostConfig.xml"
#$fileDatastores = "C:\Users\joshd\Desktop\SwitchScripts\XML\Datastores.xml"
[XML]$xmlPortGroups = Get-Content $filePortgroups
[XML]$xmlHostParams = Get-Content $fileHostParams
#[XML]$xmlDatastores = Get-Content $fileDatastores
$xmlHostConfig = $xmlHostParams.hostConfig.host | Where name -contains $VMhost

#List the Clusters
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Cluster containing the host:"
$clusterName = $menu | where {$_.Number -eq $clusterNum}

#List the hosts in the Cluster
$global:i=0
Get-Cluster $clusterName.Name | Get-VMHost | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$hostNum = Read-Host "Select the number of the host for auditing:"
$hostName = $menu | where {$_.Number -eq $hostNum}

#Get host settings
$getHost = Get-VMHost $hostName.Name

#Check DNS
Write-Host "Checking DNS Servers on host $($hostName.Name)..." -foreground "Yellow"
$dnsHost = $getHost | Get-VMHostNetwork
IF (($dnsHost.dnsaddress -notcontains $xmlHostParams.hostConfig.commonParams.dnsServer1) -OR ($dnsHost.dnsaddress -notcontains $xmlHostParams.hostConfig.commonParams.dnsServer2)){Write-Host "DNS Servers are not configured properly on $VMHost" -foreground "Red"}ELSE{Write-Host "DNS Servers are properly configured on $($VMHost)" -foreground "Green"}

Write-Host "Checking Search Domain on host $($hostName.Name)..." -foreground "Yellow"
IF ($dnsHost.SearchDomain -ne $xmlHostParams.hostConfig.commonParams.domainName){Write-Host "Search domain not configured properly on $($hostName.Name)" -foreground "Red"}ELSE{Write-Host "Search domain configured properly on $($hostName.Name)" -foreground "Green"}

Write-Host "Checking Domain name on host $($hostName.Name)..." -foreground "Yellow"
IF ($dnsHost.DomainName -ne $xmlHostParams.hostConfig.commonParams.domainName){Write-Host "Domain not configured properly on $($hostName.Name)" -foreground "Red"}ELSE{Write-Host "Domain configured properly on $($hostName.Name)" -foreground "Green"}

#Check Syslog
Write-Host "Checking Syslog server on $($hostName.Name)..." -foreground "Yellow"
$syslog = $getHost | Get-AdvancedSetting -name syslog.global.loghost
IF ($syslog.value -ne $xmlHostParams.hostConfig.commonParams.syslogServer){Write-Host "Syslog server not configured properly on $($hostName.Name)" -foreground "Red"}ELSE{Write-Host "Syslog configured properly on $($hostName.Name)" -foreground "Green"}

#Check NTP
Write-Host "Checking NTP Server on host $($hostName.Name)..." -foreground "Yellow"
$ntpHosts = $getHost | Get-VMHostNtpServer
IF (($ntpHosts -notcontains $xmlHostParams.hostConfig.commonParams.ntpServer1) -OR ($ntpHosts -notcontains $xmlHostParams.hostConfig.commonParams.ntpServer2)){Write-Host "NTP Servers are not configured properly on $($hostName.Name)" -foreground "Red"}ELSE{Write-Host "NTP Server configured properly on $($hostName.Name)" -foreground "Green"}

#Check SSH
Write-Host "Checking SSH configuration on host $($hostName.Name)..." -foreground "Yellow"
$sshHost = $getHost | Get-VMHostService | Where-Object {$_.key -eq "TSM-SSH"}
IF ($sshHost.Policy -ne $xmlHostParams.hostConfig.commonParams.enableSSH){Write-Host "SSH not configured properly on $($hostName.Name)" -foreground "Red"}ELSE{Write-Host "SSH properly configured on $($hostName.Name)" -foreground "Green"}

#Get Power Policy
Write-Host "Checking current Power Policy on host $($hostName.Name)..." -foreground "Yellow"
IF ($getHost.ExtensionData.Config.PowerSystemInfo.CurrentPolicy.Key -ne "1"){Write-Host "Current Power Policy not configured properly on $($hostName.Name)" -foreground "Red"}ELSE{Write-Host "Current Power Policy properly configured on $($hostName.Name)" -foreground "Green"}

