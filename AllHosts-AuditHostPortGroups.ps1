#Enter the name of the vCenter to connect to
Write-Host "Enter the FQDN of the " -NoNewline
Write-Host "[vCenter Server]" -ForegroundColor Red -NoNewline
Write-Host " to connect to: " -NoNewline
$vCenterFqdn = Read-Host
Start-Sleep 2
Connect-viserver $vCenterFqdn
Start-Sleep 3

#Get the current XML configuration
$xmlPortgroups = "C:\Users\joshd\Desktop\SwitchScripts\XML\Portgroups.xml"
[XML]$xmlconfig = Get-Content $xmlPortgroups

#List the Clusters for validation
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Cluster for validation:"
$clusterName = $menu | where {$_.Number -eq $clusterNum}


$checkHosts = Get-Cluster $clusterName.Name | get-vmhost
foreach ($vmhost in $checkHosts) {
	$checkPortgroup = $xmlconfig.vSwitchConfig.Portgroups.portgroup | Where {$_.cluster -eq $clusterName.Name} 
	foreach ($a in $checkPortgroup) {
		$pgName = $a.name
		$configPG = $xmlconfig.vSwitchConfig.Portgroups.portgroup | Where Name -eq $a.name
		$pgVlan = $configPG.vlanid
		$hostPG = Get-VMHost $VMhost | Get-VirtualPortgroup -Name $a.name -erroraction 'silentlycontinue'
		Write-Host "Checking Portgroup $($pgName) on ESXi Host $($vmhost)" -foreground "Yellow"
		If ($configPG.name -cmatch $hostPG.name){Write-Host "Name is correct, now we'll check VLAN" -foreground "Green"} ELSE {Write-Host "$($pgName) is missing/misspelled on $($vmhost)" -foreground "Red";CONTINUE}
		If ($configPG.VlanID -eq $hostPG.VlanID){Write-Host "VLAN is correct, now we'll check Virtual Switch" -foreground "Green"} ELSE {Write-Host "$($pgName) is not set to VLAN ID $($pgVlan) on $($vmhost)" -foreground "Red";CONTINUE}
		If ($configPG.VirtualSwitch -eq $hostPG.VirtualSwitch.name){Write-Host "$($pgName) is configured correctly on $($vmhost)" -foreground "Green"} ELSE {Write-Host "$($pgName) is on the wrong Virtual Switch" -foreground "Red"}
		}
}
