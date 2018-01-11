#Get the current XML configuration
$xmlPortgroups = "C:\Users\joshd\Documents\Ivoxy\Lighthouse\cdb\XML\xml-portgroups.xml"
$xmlconfig = [System.Xml.XmlDocument](Get-Content $xmlPortgroups)

#Input the cluster name to validate Portgroups
$cluster = Read-Host -Prompt "Enter the name of the cluster to check its Portgroup configuration"

#Connect to the vCenter Instance
$vcenter = "vcenter01.domain.com"
connect-viserver $vcenter


$checkHosts = Get-Cluster $cluster | get-vmhost
foreach ($vmhost in $checkHosts)
	{
	$checkPortgroup = $xmlconfig.vSwitchConfig.Portgroups.portgroup | Where {$_.cluster -eq $cluster} | 
	foreach ($a in $checkPortgroup)
		{
		$pgName = $a.name
		$configPG = $xmlconfig.vSwitchConfig.Portgroups.portgroup | Where Name -eq $a.name
		$pgVlan = $configPG.vlanid
		$hostPG = Get-VMHost $VMhost | Get-VirtualPortgroup -Name $a.name -erroraction 'silentlycontinue'
		Write-Host "Checking Portgroup $pgName on ESXi Host $vmhost" -foreground "Yellow"
		If ($configPG.name -cmatch $hostPG.name){Write-Host "Name is correct, now we'll check VLAN" -foreground "Green"} ELSE {Write-Host "$pgName is missing/misspelled on $vmhost" -foreground "Red";break}
		If ($configPG.VlanID -eq $hostPG.VlanID){Write-Host "VLAN is correct, now we'll check Virtual Switch" -foreground "Green"} ELSE {Write-Host "$pgName is not set to VLAN ID $pgVlan on $vmhost" -foreground "Red";break}
		If ($configPG.VirtualSwitch -eq $hostPG.VirtualSwitch.name){Write-Host "$pgName is configured correctly on $vmhost" -foreground "Green"} ELSE {Write-Host "$pgName is on the wrong Virtual Switch" -foreground "Red"}
		}
	}
