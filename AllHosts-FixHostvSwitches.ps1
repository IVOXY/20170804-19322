#Enter the name of the vCenter to connect to
Write-Host "Enter the FQDN of the " -NoNewline
Write-Host "[vCenter Server]" -ForegroundColor Red -NoNewline
Write-Host " to connect to: " -NoNewline
$vCenterFqdn = Read-Host
Start-Sleep 5
Connect-viserver $vCenterFqdn

#Get the current XML configuration
$xmlPortgroups = "C:\Users\joshd\Desktop\SwitchScripts\XML\Portgroups.xml"
[XML]$xmlconfig = Get-Content $xmlPortgroups

#Input the cluster name to fix host virtual switches
#$cluster = Read-Host -Prompt "Enter the name of the cluster to fix host Virtual Switchin"
#List the Clusters for repair
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Cluster for repair:"
$clusterName = $menu | where {$_.Number -eq $clusterNum}

$checkHosts = Get-Cluster $clusterName.Name | Get-VMHost
foreach ($vmhost in $checkHosts)
	{
	$checkNetwork = Get-VMhost $vmhost | get-virtualswitch | Where {$_.ID -notlike "*distributed*"}
		foreach ($vsw in $checkNetwork)
		{
		$hostConfig = Get-VMHost $vmhost | Get-VirtualSwitch -name $vsw | Get-NicTeamingPolicy
		$hostConfigvSwitch = Get-VMHost $vmhost | Get-VirtualSwitch -name $vsw 
		#Config File Configuration
		$configActiveNics = $xmlconfig.vSwitchConfig.vSwitch | Where {$_.VirtualSwitch -eq $vsw} | Select ActiveNic
		$configActiveNicsSplit = $configActiveNics.activenic -split ', '
		$configStandbyNics = $xmlconfig.vSwitchConfig.vSwitch | Where {$_.VirtualSwitch -eq $vsw} | Select StandbyNic
		$configStandbyNicsSplit = $configStandbyNics.standbynic -split ', '
		$configLBPolicy = $xmlconfig.vSwitchConfig.vSwitch | Where {$_.VirtualSwitch -eq $vsw} | Select LoadBalancingPolicy
		$configFailoverPolicy = $xmlconfig.vSwitchConfig.vSwitch | Where {$_.VirtualSwitch -eq $vsw} | Select NetworkFailoverDetectionPolicy
		$configNotifySwitches = $xmlconfig.vSwitchConfig.vSwitch | Where {$_.VirtualSwitch -eq $vsw} | Select NotifySwitches
		$configFailbackEnabled = $xmlconfig.vSwitchConfig.vSwitch | Where {$_.VirtualSwitch -eq $vsw} | Select FailbackEnabled

		#Current Host Configuration
		$hostActiveNics = $hostConfig | Select ActiveNic
		$hostStandbyNics = $hostConfig | Select StandbyNic
		$hostLBPolicy = $hostConfig | Select LoadBalancingPolicy
		$hostFailoverPolicy = $hostConfig | Select NetworkFailoverDetectionPolicy
		$hostNotifySwitches = $hostConfig | Select NotifySwitches
		$hostFailbackEnabled = $hostConfig | Select FailbackEnabled

		#Check and fix vSwitch Active NICs
		Write-Host "Current configuration of $($vmhost) and $($vsw)" -foreground "Yellow"
		If (($hostactivenics.activenic -join ", ") -ne $configactivenics.activenic){Write-Host "Active NICs not correctly configured on $($vmhost) and $($vsw)" -foreground "Red"; $hostConfig | Set-NicTeamingPolicy -MakeNicActive $configActiveNicsSplit} ELSE {Write-Host "Active NICs are corretly configured on $($vmhost) and $($vsw)" -foreground "Green"}

		#Check and fix vSwitch Standby NICs
		If (($hoststandbynics.standbynic -join ", ") -ne $configstandbynics.standbynic){Write-Host "Standby NICs not correctly configured on $($vmhost) and $($vsw)" -foreground "Red"; $hostConfig | Set-NicTeamingPolicy -MakeNicStandby $configStandbyNicsSplit} ELSE {Write-Host "Standby NICs are corretly configured on $($vmhost) and $($vsw)" -foreground "Green"}

		#Check and Fix vSwitch Load Balancing Policy
		If ($hostLBPolicy.loadbalancingpolicy -ne $configLBPolicy.loadbalancingpolicy){Write-Host "Load Balancing Policy not correct on $($vmhost) and $($vsw)" -foreground "Red"; $hostConfig | Set-NicTeamingPolicy -LoadBalancingPolicy $configLBPolicy.loadbalancingpolicy} ELSE {Write-Host "Load Balancing Policy configured correctly on $($vmhost) and $($vsw)" -foreground "Green"}

		#Check and Fix vSwitch Failover Policy
		If ($hostFailoverPolicy.NetworkFailoverDetectionPolicy -ne $configFailoverPolicy.NetworkFailoverDetectionPolicy){Write-Host "Switch Failover Policy not correct on $($vmhost) and $($vsw)" -foreground "Red"; $hostConfig | Set-NicTeamingPolicy -NetworkFailoverDetectionPolicy $configFailoverPolicy.NetworkFailoverDetectionPolicy} ELSE {Write-Host "Switch Failover Policy configured correctly on $($vmhost) and $($vsw)" -foreground "Green"}

		#Check and Fix vSwitch Switch Notification
		If ($hostNotifySwitches.NotifySwitches -ne $configNotifySwitches.NotifySwitches){Write-Host "Switch Notification policy not correct on $($vmhost) and $($vsw)" -foreground "Red"; $hostConfig | Set-NicTeamingPolicy -NotifySwitches ([System.Convert]::ToBoolean($configNotifySwitches.NotifySwitches))} ELSE {Write-Host "Switch Notification policy is correct on $($vmhost) and $($vsw)" -foreground "Green"}

		#Check and Fix vSwitch Failback Policy
		If ($hostFailbackEnabled.FailbackEnabled -ne $configFailbackEnabled.FailbackEnabled){Write-Host "Switch Failback policy not correct on $($vmhost) and $($vsw)" -foreground "Red"; $hostConfig | Set-NicTeamingPolicy -FailbackEnabled ([System.Convert]::ToBoolean($configFailbackEnabled.FailbackEnabled))} ELSE {Write-Host "Switch Failback policy is correct on $($vmhost) and $($vsw)" -foreground "Green"}
		}
	}

