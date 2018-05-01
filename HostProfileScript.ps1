#Enter the name of the vCenter to connect to
Write-Host "Enter the FQDN of the " -NoNewline
Write-Host "[vCenter Server]" -ForegroundColor Red -NoNewline
Write-Host " to connect to: " -NoNewline
$vCenterFqdn = Read-Host
Start-Sleep 5
Connect-viserver $vCenterFqdn

#List all the hosts sorted by Maintenance Mode
$global:i=0
Get-VMHost | Sort Parent | Select @{Name="Number";Expression={$global:i++;$global:i}},Name, Parent, State -OutVariable menu | format-table -AutoSize
$hostNum = Read-Host "Select the number of the host for configuration:"
$hostName = $menu | where {$_.Number -eq $hostNum}

#Get the name of the ESXi host to be configured
#$VMhost = Read-Host -Prompt "Enter the ESXi host name (ex: labesx03)"
$hostState = Get-VMHost $hostName.Name
IF ($hostState.State -eq "Connected"){
$mmode = Read-Host -Prompt "Enter Maintenace Mode before configuring? (Yes or No)"}
ELSE {
Read-Host "$($hostName.Name) is already Maintenance Mode. Press Enter to continue"}

$ESXiHost = $hostName.Name

#Get XML File configurations
Write-Host "Gathering XML file configurations..." -foreground "Yellow"
$filePortgroups = "C:\Users\joshd\Desktop\SwitchScripts\XML\Portgroups.xml"
$fileHostParams = "C:\Users\joshd\Desktop\SwitchScripts\XML\HostConfig.xml"
#$fileDatastores = "C:\Users\joshd\Desktop\SwitchScripts\XML\Datastores.xml"
[XML]$xmlPortGroups = Get-Content $filePortgroups
[XML]$xmlHostParams = Get-Content $fileHostParams
#[XML]$xmlDatastores = Get-Content $fileDatastores
$xmlHostConfig = $xmlHostParams.hostConfig.hosts.host | Where name -contains $ESXiHost

#Combine the entered ESXi Hostname with the configured domain name
Write-Host "Creating ESXi Fully Qualified Domain Name" -foreground "Yellow"
#$ESXiHost = $VMhost + "." + $xmlHostParams.hostConfig.commonParams.domainName

#Enter Maintenance Mode
IF ($mmode -like "yes"){Get-VMHost -Name $ESXiHost | Set-VMHost -State Maintenance; Write-Host "Placing $($VMhost) into Maintenance Mode" -foreground "Yellow"}ELSE{Write-Host ""}

#Configure DNS
Write-Host "Configuring DNS..." -foreground "Yellow"
Get-VMHostNetwork -VMHost $ESXiHost | Set-VMHostNetwork -SearchDomain $xmlHostParams.hostconfig.commonParams.domainName -Domain $xmlHostParams.hostconfig.commonParams.domainName -DNSAddress @($xmlHostParams.hostconfig.commonParams.dnsServer1,$xmlHostParams.hostconfig.commonParams.dnsServer2)

#Configure NTP
Write-Host "Configuring NTP..." -foreground "Yellow"
if(Get-VMHostNTPServer -vmhost $ESXiHost){Remove-VMHostNTPServer -host $ESXiHost -NTPServer (Get-VMHostNTPServer -vmhost $ESXiHost) -Confirm:$False}
Add-VMHostNTPServer -VMhost $ESXiHost -NTPServer $xmlHostParams.hostconfig.commonparams.ntpServer1
Add-VMHostNTPServer -VMhost $ESXiHost -NTPServer $xmlHostParams.hostconfig.commonparams.ntpServer2
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
$vSwitchActiveNics = $vSwitchConfig | Select ActiveNic
$vSwitchActiveNicsSplit = $vSwitchActiveNics.activenic -split ', '
$hostConfig = Get-VMHost $ESXiHost | Get-VirtualSwitch -name "vSwitch0"
$vSwitchConfig = ($xmlPortGroups.vSwitchConfig.vSwitches.vSwitch|Where {$_.name -eq "vSwitch0"}).ActiveNic
$advHost = Get-VMHost $ESXiHost
$hostConfig = Get-VMHost $ESXiHost | Get-VirtualSwitch -name "vSwitch0"
foreach ($a in $vSwitchConfig) {
$hostConfig | Add-VirtualSwitchPhysicalNetworkAdapter -VMHostPhysicalNic ($advHost | Get-VMHostNetworkAdapter -Physical -Name $a) -confirm:$false}

#Configure vSwitch0
Write-Host "Configuring vSwitch0..." -foreground "Yellow"
$vSwitch0Config = $xmlPortGroups.vSwitchConfig.vSwitches.vSwitch|Where {$_.name -eq "vSwitch0"}
#$hostconfig | Set-VirtualSwitch -Nic $vSwitchActiveNicsSplit -MTU $vSwitch0Config.MTU.ToString() -confirm:$false
$hostconfig | Set-VirtualSwitch -MTU $vSwitch0Config.MTU.ToString() -confirm:$false
$hostConfig | Get-NicTeamingPolicy | Set-NicTeamingPolicy -LoadBalancingPolicy $vSwitch0Config.LoadBalancingPolicy -NetworkFailoverDetectionPolicy $vSwitch0Config.NetworkFailoverDetectionPolicy -NotifySwitches ([System.Convert]::ToBoolean($vSwitch0Config.NotifySwitches)) -FailbackEnabled ([System.Convert]::ToBoolean($vSwitch0Config.FailbackEnabled))
$hostConfig | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits ([System.Convert]::ToBoolean($vSwitch0Config.forgedTransmits)) -AllowPromiscuous ([System.Convert]::ToBoolean($vSwitch0Config.allowPromiscuous)) -MacChanges ([System.Convert]::ToBoolean($vSwitch0Config.macChanges))

#Configure Management Network
Write-Host "Configuring Management Network..." -foreground "Yellow"
$mgmtPG = $hostConfig | Get-VirtualPortgroup -Name "Management Network" 
$mgmtPG | Get-NicTeamingPolicy | Set-NicTeamingPolicy -InheritFailback $true -InheritFailoverOrder $true -InheritLoadBalancingPolicy $true -InheritNetworkFailoverDetectionPolicy $true -InheritNotifySwitches $true -Confirm:$false
$mgmtPG | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmitsInherited $true -AllowPromiscuousInherited $true -MacChangesInherited $true

#Remove "VM Network" from vSwitch0
Write-Host "Removing "VM Network" from vSwitch0" -foreground "Yellow"
Get-VirtualSwitch -VMHost $ESXiHost | Get-VirtualPortgroup -name "VM Network" | Remove-VirtualPortgroup -confirm:$false

#$xmlNetwork.vSwitchConfig.Portgroups.Portgroup|Where {$_.name -eq $pgName.Name}

#Create additional vSwitches
Write-Host "Creating additional vSwitches..." -foreground "Yellow"
$getvSwitches = $xmlPortGroups.vSwitchConfig.vSwitches.vSwitch|Where {$_.name -ne "vSwitch0"}
foreach ($a in $getvSwitches)
{
$vSwitchConfig = $xmlPortGroups.vSwitchConfig.vSwitches.vSwitch|Where {$_.name -eq $a.name}
$vSwitchActiveNics = $vSwitchConfig | Select ActiveNic
$vSwitchActiveNicsSplit = $vSwitchActiveNics.activenic -split ', '
New-VirtualSwitch -VMhost $ESXiHost -Name $a.name -MTU $vSwitchConfig.MTU.ToString() -Nic $vSwitchActiveNicsSplit
$hostConfig = Get-VMHost $ESXiHost | Get-VirtualSwitch -name $a.name
$hostConfig | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive $vSwitchActiveNicsSplit -LoadBalancingPolicy $vSwitchConfig.LoadBalancingPolicy -NetworkFailoverDetectionPolicy $vSwitchConfig.NetworkFailoverDetectionPolicy -NotifySwitches ([System.Convert]::ToBoolean($vSwitchConfig.NotifySwitches)) -FailbackEnabled ([System.Convert]::ToBoolean($vSwitchConfig.FailbackEnabled))
$hostConfig | Get-SecurityPolicy | Set-SecurityPolicy -ForgedTransmits ([System.Convert]::ToBoolean($vSwitchConfig.forgedTransmits)) -AllowPromiscuous ([System.Convert]::ToBoolean($vSwitchConfig.allowPromiscuous)) -MacChanges ([System.Convert]::ToBoolean($vSwitchConfig.macChanges))
}

#Add Portgroups to Virtual Switches
Write-Host "Adding additional Portgroups to vSwitches..." -foreground "Yellow"
$PortGroups = $xmlPortGroups.vSwitchConfig.Portgroups.portgroup|Where {$_.cluster -eq $xmlHostConfig.cluster}
foreach ($a in $PortGroups)
{
$vPGs = $PortGroups | Where name -eq $a.name
IF (($vPGs.name -eq "vmotion") -OR ($vPGs.name -eq "nfs") -OR ($vPGs.name -like "*iscsi*") -OR ($vPGS.name -like "*Management Network*")){Write-Host "VMKernel Portgroup. Skipping..." -foreground "Yellow"; CONTINUE}
ELSE {
Get-VMHost $ESXiHost | Get-VirtualSwitch -name $vPGs.VirtualSwitch | New-VirtualPortgroup -name $vPGs.name -VlanID $vPGs.VlanId}
}

#Creating additional VMKernel Adapters
Write-Host "Adding additional VMKernel Adapters..." -foreground "Yellow"
$hostConfig = $xmlHostParams.hostConfig.hosts.host | Where Name -eq $ESXiHost
$vmkAdapters = $hostConfig.vmkernels.vmkernel|Where {$_.name -ne "vmk0"}
foreach ($a in $vmkAdapters) {
$vmk = $vmkAdapters | where name -contains $a.name
IF ($vmk.portgroup -like "*vmotion*"){
New-VMHostNetworkAdapter -VMHost $ESXiHost -Portgroup $vmk.portgroup -virtualSwitch $vmk.virtualSwitch -IP $vmk.IP -SubnetMask $vmk.subnetMask -MTU $vmk.MTU.ToString() -VMotionEnabled $true;
$vmkernelPG = Get-VirtualPortgroup -Name $vmk.portgroup;
Set-VirtualPortgroup -VirtualPortgroup $vmkernelPG -VlanID $vmk.vlanId}
ELSE {
New-VMHostNetworkAdapter -VMHost $ESXiHost -Portgroup $vmk.portgroup -virtualSwitch $vmk.virtualSwitch -IP $vmk.IP -SubnetMask $vmk.subnetMask -MTU $vmk.MTU.ToString();
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
#Write-Host "Adding NFS datastores to host..." -foreground "Yellow"
#$hostConfig = $xmlHostParams.hostConfig.host | Where Name -eq $VMhost
#$datastores = $xmlDatastores.datastores.datastore | Where cluster -like $hostConfig.cluster
#foreach ($a in $datastores) {
#New-Datastore -NFS -VMHost $ESXiHost -Name $a.name -Path $a.path -NfsHost $a.NfsHost
#}

#Move Host into Cluster and disable maintenance mode
Write-Host "Checking if Host is in correct cluster..." -foreground "Yellow"
$hostState = Get-VMhost $ESXiHost
IF ($hostState.Parent.Name -ne $xmlHostConfig.cluster) {
Write-Host "Placing host into the correct cluster and exiting Maintenance Mode" -foreground "Yellow"
Move-VMhost $ESXiHost -Destination $xmlHostConfig.cluster
IF ($hostState.ConnectionState -eq "Maintenance"){$hostState | Set-VMHost -State Connected}ELSE{CONTINUE}}
ELSE {
IF ($hostState.ConnectionState -eq "Maintenance"){$hostState | Set-VMHost -State Connected}ELSE{CONTINUE}}
Write-Host "Host Configuration Complete" -foreground "Green"