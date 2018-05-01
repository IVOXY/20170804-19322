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
[XML]$xmlUpdate = Get-Content $xmlPortgroups

#List the Cluster for provisioning
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Cluster for this Portgroup:"
$clusterName = $menu | where {$_.Number -eq $clusterNum}

#List the vSwitches for provisioning
$global:i=0
Get-Cluster $clusterName.Name | Get-VMHost | Where {$_.State -eq "Connected"} | Get-Random | Get-VirtualSwitch | Where {$_.ID -notlike "*distributed*"} | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$vSwitchNum = Read-Host "Select the number of the vSwitch for this Portgroup:"
$vSwitchName = $menu | where {$_.Number -eq $vSwitchNum}

#Input the name and VLAN of the new Portgroup
$name = Read-Host -Prompt "Enter the name of the new Portgroup (ex: Management Network)"
$checkPgName = $xmlUpdate.vSwitchConfig.Portgroups.Portgroup|Where {$_.name -eq $name}

IF ($checkPgName -eq $null) {
$vlanId = Read-Host -Prompt "Enter the VLAN ID number for the Portgroup $($name) (ex: 13)" }
ELSE {
Read-Host "A portgroup named $($name) already exists with VLAN ID $($checkPgName.vlanId). Press Enter to provision to $($clusterName.Name)";
$vlanId = $checkPgName.vlanId }

#Add the name, VLAN, and Virtual Switch values to the XML file
Write-Host "Adding Portgroup $($name) with VLAN Id $($vlanId) on $($vSwitchName.Name) in cluster $($clusterName.Name) to the Config File" -foreground "Yellow"

$checkPgName = $xmlUpdate.vSwitchConfig.Portgroups.Portgroup|Where {$_.name -eq $name}
IF ($checkPgName -eq $null) {
$newPortgroup = $xmlUpdate.vSwitchConfig.Portgroups.AppendChild($xmlUpdate.CreateElement("Portgroup"))
$newPortgroup.SetAttribute("Name",$name)
$newVlanIdElement = $newPortgroup.AppendChild($xmlUpdate.CreateElement("vlanId"))
$newVlanIdValue = $newVlanIdElement.AppendChild($xmlUpdate.CreateTextNode($vlanId))
$newVirtualSwitchElement = $newPortgroup.AppendChild($xmlUpdate.CreateElement("virtualSwitch"))
$newVirtualSwitchValue = $newVirtualSwitchElement.AppendChild($xmlUpdate.CreateTextNode($vSwitchName.Name))
$newClusterElement = $newPortgroup.AppendChild($xmlUpdate.CreateElement("cluster"))
$newClusterValue = $newClusterElement.AppendChild($xmlUpdate.CreateTextNode($clusterName.Name))
$xmlUpdate.Save($xmlPortgroups) }
ELSE {
Write-Host "Portgroup Name already exists. Adding additional cluster tag to $($name)" -foreground "Yellow"
$newClusterElement = $xmlUpdate.CreateElement("cluster")
$newClusterElement.InnerText = $clusterName.Name
$checkPgName.AppendChild($newClusterElement) | Out-Null
}
$xmlUpdate.Save($xmlPortgroups)

#Add the new portgroup to the host
Write-Host "Adding Portgroup $name to hosts..." -foreground "Yellow"
$getHosts = Get-Cluster $clusterName.Name | Get-VMHost
foreach ($VMHost in $getHosts) {
Get-VMHost $VMHost | Get-VirtualSwitch -name $vSwitchName.Name | New-VirtualPortgroup -name $name -VlanId $vlanId}

#List the hosts with the Portgroup added
Write-Host "New portgroup has been added to the following hosts:" -foreground "Yellow"
$getHosts = Get-Cluster $clusterName.name | Get-VMHost
foreach ($VMHost in $getHosts) {
$hostDetails = Get-VMHost $VMHost
$hostPG = $hostDetails | Get-Virtualportgroup | Where {$_.name -eq $name}
$Report = "" | Select-Object Hostname,Cluster,Portgroup
$Report.Hostname = $hostDetails.name
$Report.Cluster = $hostDetails.parent.name
$Report.Portgroup = $hostPG.name
$Report
}

