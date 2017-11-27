#Get the name of the ESXi host to be configured
$VMhost = Read-Host -Prompt "Enter the ESXi host name (ex: labesx03)"
$mmode = Read-Host -Prompt "Enter Maintenace Mode before configuring? (Yes or No)"

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
$ESXiHost = $VMhost + "." + $xmlHostParams.hostConfig.commonParams.domainName1

#Enter Maintenance Mode
IF ($mmode -like "yes"){Get-VMHost -Name $ESXiHost | Set-VMHost -State Maintenance; Write-Host "Placing $VMhost into Maintenance Mode" -foreground "Yellow"}ELSE{Write-Host ""}

#Configure DNS
Write-Host "Configuring DNS..." -foreground "Yellow"
Get-VMHostNetwork -VMHost $ESXiHost | Set-VMHostNetwork -SearchDomain $xmlHostParams.hostconfig.commonparams.domainname1 -Domain $xmlHostParams.hostconfig.commonparams.domainname1 -DNSAddress @($xmlHostParams.hostconfig.commonparams.dnsServer1,$xmlHostParams.hostconfig.commonparams.dnsServer2)

#Configure NTP
Write-Host "Configuring NTP..." -foreground "Yellow"
if(Get-VMHostNTPServer -vmhost $ESXiHost){Remove-VMHostNTPServer -host $ESXiHost -NTPServer (Get-VMHostNTPServer -vmhost $ESXiHost) -Confirm:$False}
Add-VMHostNTPServer -VMhost $ESXiHost -NTPServer $xmlHostParams.hostconfig.commonparams.ntpServer
Get-VMHostFirewallException -name "NTP client" -VMHost $ESXiHost | Set-VMHostFirewallException -Enabled:$True
Get-VMHostService -VMHost $ESXiHost | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -Policy "On" -Confirm:$False
Get-VMHostService -VMHost $ESXiHost | Where-Object {$_.key -eq "ntpd"} | Restart-VMHostService -Confirm:$False

#Configure Syslog

Write-Host "Configuring Syslog..." -foreground "Yellow"
$advHost = Get-VMHost $ESXiHost
$advHost | Get-AdvancedSetting -name Syslog.global.logHost | Set-AdvancedSetting -Value $xmlHostParams.hostconfig.commonparams.syslogServer -Confirm:$False
Get-VMHostFirewallException -name 'syslog' -VMHost $ESXiHost | Set-VMHostFirewallException -Enabled:$True

#Configure SSH
Write-Host "Configuring SSH..." -foreground "Yellow"
IF ($xmlHostConfig.enableSSH -eq "True"){
Get-VMHostService -VMHost $ESXiHost | Where-Object {$_.key -eq "TSM-SSH"} | Set-VMHostService -Policy "On" -Confirm:$False
Get-VMHostService -VMHost $ESXiHost | Where-Object {$_.key -eq "TSM-SSH"} | Restart-VMHostService -Confirm:$False
Set-VMHostAdvancedConfiguration -VMHost $ESXiHost -Name "UserVars.SuppressShellWarning" -Value "1" -Confirm:$False}
ELSE {
Get-VMHostService -VMHost $ESXiHost | Where-Object {$_.key -eq "TSM-SSH"} | Set-VMHostService -Policy "Off" -Confirm:$False
Get-VMHostService -VMHost $ESXiHost | Where-Object {$_.key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$False
Set-VMHostAdvancedConfiguration -VMHost $ESXiHost -Name "UserVars.SuppressShellWarning" -Value "0" -Confirm:$False}

#Set High Performance Power Policy
Write-Host "Configuring Power Policy..." -foreground "Yellow"
$view = (Get-VMHost $ESXiHost | Get-View)
(Get-View $view.ConfigManager.PowerSystem).ConfigurePowerPolicy(1)

#Set vSwitch0 Networking
Write-Host "Gathering vSwitch0 configuration..." -foreground "Yellow"
$vSwitchConfig = $xmlPortGroups.vSwitchConfig.vSwitch | Where {$_.VirtualSwitch -eq "vSwitch0"}
$vSwitchActiveNics = $vSwitchConfig | Select ActiveNic
$vSwitchActiveNicsSplit = $vSwitchActiveNics.activenic -split ', '
$hostConfig = Get-VMHost $ESXiHost | Get-VirtualSwitch -name "vSwitch0"

#Configure vSwitch0
Write-Host "Configuring vSwitch0..." -foreground "Yellow"
$hostconfig | Set-VirtualSwitch -Nic $vSwitchActiveNicsSplit -MTU $vSwitchConfig.MTU -confirm:$false
$hostConfig | Get-NicTeamingPolicy | Set-NicTeamingPolicy -LoadBalancingPolicy $vSwitchConfig.LoadBalancingPolicy -NetworkFailoverDetectionPolicy $vSwitchConfig.NetworkFailoverDetectionPolicy -NotifySwitches ([System.Convert]::ToBoolean($vSwitchConfig.NotifySwitches)) -FailbackEnabled ([System.Convert]::ToBoolean($vSwitchConfig.FailbackEnabled))
$hostConfig | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits ([System.Convert]::ToBoolean($vSwitchConfig.forgedTransmits)) -AllowPromiscuous ([System.Convert]::ToBoolean($vSwitchConfig.allowPromiscuous)) -MacChanges ([System.Convert]::ToBoolean($vSwitchConfig.macChanges))

#Configure Management Network
Write-Host "Configuring Management Network..." -foreground "Yellow"
$mgmtPG = $hostConfig | Get-VirtualPortgroup -Name "Management Network" 
$mgmtPG | Get-NicTeamingPolicy | Set-NicTeamingPolicy -InheritFailback $true -InheritFailoverOrder $true -InheritLoadBalancingPolicy $true -InheritNetworkFailoverDetectionPolicy $true -InheritNotifySwitches $true -Confirm:$false
$mgmtPG | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmitsInherited $true -AllowPromiscuousInherited $true -MacChangesInherited $true

#Remove "VM Network" from vSwitch0
Write-Host "Removing "VM Network" from vSwitch0" -foreground "Yellow"
Get-VirtualSwitch -VMHost $ESXiHost | Get-VirtualPortgroup -name "VM Network" | Remove-VirtualPortgroup -confirm:$false

#Create additional vSwitches
Write-Host "Creating additional vSwitches..." -foreground "Yellow"
$getvSwitches = $xmlPortGroups.vSwitchConfig.vswitch | Select VirtualSwitch | Where VirtualSwitch -ne "vSwitch0"
foreach ($a in $getvSwitches)
{
$vSwitchConfig = $xmlPortGroups.vSwitchConfig.vSwitch | Where {$_.VirtualSwitch -eq $a.virtualswitch}
$vSwitchActiveNics = $vSwitchConfig | Select ActiveNic
$vSwitchActiveNicsSplit = $vSwitchActiveNics.activenic -split ', '
New-VirtualSwitch -VMhost $ESXiHost -Name $a.virtualswitch -MTU $vSwitchConfig.MTU -Nic $vSwitchActiveNicsSplit
$hostConfig = Get-VMHost $ESXiHost | Get-VirtualSwitch -name $a.virtualswitch
$hostConfig | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive $vSwitchActiveNicsSplit -LoadBalancingPolicy $vSwitchConfig.LoadBalancingPolicy -NetworkFailoverDetectionPolicy $vSwitchConfig.NetworkFailoverDetectionPolicy -NotifySwitches ([System.Convert]::ToBoolean($vSwitchConfig.NotifySwitches)) -FailbackEnabled ([System.Convert]::ToBoolean($vSwitchConfig.FailbackEnabled))
$hostConfig | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits ([System.Convert]::ToBoolean($vSwitchConfig.forgedTransmits)) -AllowPromiscuous ([System.Convert]::ToBoolean($vSwitchConfig.allowPromiscuous)) -MacChanges ([System.Convert]::ToBoolean($vSwitchConfig.macChanges))
}

#Add Portgroups to Virtual Switches
Write-Host "Adding additional Portgroups to vSwitches..." -foreground "Yellow"
$PortGroups = $xmlPortGroups.vSwitchConfig.Portgroups.portgroup
foreach ($a in $PortGroups)
{
$vPGs = $PortGroups | Where name -eq $a.name
IF (($vPGs.name -eq "vmotion") -OR ($vPGs.name -eq "nfs") -OR ($vPGs.name -like "*iscsi*") -OR ($vPGS.name -like "*Management Network*")){Write-Host "VMKernel Portgroup. Skipping..." -foreground "Yellow"; break}
ELSE {
Get-VMHost $ESXiHost | Get-VirtualSwitch -name $vPGs.VirtualSwitch | New-VirtualPortgroup -name $vPGs.name -VlanID $vPGs.VlanId}
}

#Creating additional VMKernel Adapters
Write-Host "Adding additional VMKernel Adapters..." -foreground "Yellow"
$hostConfig = $xmlHostParams.hostConfig.host | Where Name -eq $VMhost
$vmkAdapters = $hostConfig.vmkernels.vmkernel
foreach ($a in $vmkAdapters) {
$vmk = $vmkAdapters | where name -contains $a.name
IF ($vmk.name -like "*vmotion*"){
New-VMHostNetworkAdapter -VMHost $ESXiHost -Portgroup $vmk.portgroup -virtualSwitch $vmk.virtualSwitch -IP $vmk.ipAddress -SubnetMask $vmk.subnetMask -MTU $vmk.MTU -VMotionEnabled $true;
$vmkernelPG = Get-VirtualPortgroup -Name $vmk.portgroup;
Set-VirtualPortgroup -VirtualPortgroup $vmkernelPG -VlanID $vmk.vlanId}
ELSE {
New-VMHostNetworkAdapter -VMHost $ESXiHost -Portgroup $vmk.portgroup -virtualSwitch $vmk.virtualSwitch -IP $vmk.ipAddress -SubnetMask $vmk.subnetMask -MTU $vmk.MTU;
$vmkernelPG = Get-VirtualPortgroup -Name $vmk.portgroup;
Set-VirtualPortgroup -VirtualPortgroup $vmkernelPG -VlanID $vmk.vlanId}
}

#Add advanced settings configuration for NFS storage
Write-Host "Configuring advanced settings for NFS storage..." -foreground "Yellow"
$advHost | Get-AdvancedSetting -name Net.TcpipHeapSize | Set-AdvancedSetting -Value 32 -Confirm:$False
$advHost | Get-AdvancedSetting -name Net.TcpipHeapMax  | Set-AdvancedSetting -Value 512 -Confirm:$False
$advHost | Get-AdvancedSetting -name NFS.MaxVolumes  | Set-AdvancedSetting -Value 256 -Confirm:$False
$advHost | Get-AdvancedSetting -name NFS41.MaxVolumes  | Set-AdvancedSetting -Value 256 -Confirm:$False
$advHost | Get-AdvancedSetting -name NFS.HeartbeatMaxFailures  | Set-AdvancedSetting -Value 10 -Confirm:$False
$advHost | Get-AdvancedSetting -name NFS.HeartbeatFrequency  | Set-AdvancedSetting -Value 12 -Confirm:$False
$advHost | Get-AdvancedSetting -name NFS.HeartbeatTimeout  | Set-AdvancedSetting -Value 5 -Confirm:$False
$advHost | Get-AdvancedSetting -name NFS.MaxQueueDepth  | Set-AdvancedSetting -Value 64 -Confirm:$False

#Add NFS datastores to Host
Write-Host "Adding NFS datastores to host..." -foreground "Yellow"
$hostConfig = $xmlHostParams.hostConfig.host | Where Name -eq $VMhost
$datastores = $xmlDatastores.datastores.datastore | Where cluster -like $hostConfig.cluster
foreach ($a in $datastores) {
New-Datastore -NFS -VMHost $ESXiHost -Name $a.name -Path $a.path -NfsHost $a.NfsHost
}

#Move Host into Cluster and disable maintenance mode
Write-Host "Placing host into the correct cluster and exiting Maintenance Mode" -foreground "Yellow"
Move-VMhost $ESXiHost -Destination $xmlHostConfig.cluster
$hostState = Get-VMhost $ESXiHost
IF ($hostState.ConnectionState -eq "Maintenance"){Get-VMHost -name $ESXiHost | Set-VMHost -State Connected}ELSE{Break}
Write-Host "Host Configuration Complete" -foreground "Green"