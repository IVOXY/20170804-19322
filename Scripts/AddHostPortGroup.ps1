#Input the name, VLAN, Virtual Switch, and cluster of the new Portgroup
$name = Read-Host -Prompt "Enter the name of the new Portgroup (ex: Management Network)"
$vlanId = Read-Host -Prompt "Enter the VLAN Id number for the Portgroup $name (ex: 13)"
$virtualSwitch = Read-Host -Prompt "Enter the name of the Virtual Switch for Portgroup $name (ex: vSwitch1)"
$cluster = Read-Host -Prompt "Enter the name of the cluster for this Portgroup (ex: Cluster1)"

#Get the current XML configuration
$xmlPortgroups = "C:\Users\joshd\Documents\Ivoxy\Lighthouse\cdb\XML\xml-portgroups.xml"
$xmlUpdate = [System.Xml.XmlDocument](Get-Content $xmlPortgroups)

#Add the name, VLAN, and Virtual Switch values to the XML file
Write-Host "Adding Portgroup $name with VLAN Id $vlanId on $virtualSwitch in cluster $cluster to the Config File" -foreground "Yellow"

$newPortgroup = $xmlUpdate.vSwitchConfig.Portgroups.AppendChild($xmlUpdate.CreateElement("Portgroup"));
$newPortgroup.SetAttribute("Name",$name);
$newvlanIdAttribute = $newPortgroup.AppendChild($xmlUpdate.CreateElement("vlanId"));
$newvlanIdValue = $newvlanIdAttribute.AppendChild($xmlUpdate.CreateTextNode($vlanId));
$newvirtualSwitchAttribute = $newPortgroup.AppendChild($xmlUpdate.CreateElement("virtualSwitch"));
$newvirtualSwitchValue = $newvirtualSwitchAttribute.AppendChild($xmlUpdate.CreateTextNode($virtualSwitch));
$xmlUpdate.Save($xmlPortgroups)

#Add the new portgroup to the host
Write-Host "Adding Portgroup $name to hosts..." -foreground "Yellow"
$getHosts = Get-Cluster $cluster | Get-VMHost
foreach ($VMHost in $getHosts) {
Get-VMHost $VMHost | Get-VirtualSwitch -name $virtualSwitch | New-VirtualPortgroup -name $name -VlanId $vlanId}

#List the hosts with the Portgroup added
Write-Host "New portgroup has been added to the following hosts:" -foreground "Yellow"
$getHosts = Get-Cluster $cluster | Get-VMHost
foreach ($VMHost in $getHosts) {
$hostDetails = Get-VMHost $VMHost
$hostPG = $hostDetails | Get-Virtualportgroup | Where {$_.name -eq $name}
$Report = "" | Select-Object Hostname,Cluster,Portgroup
$Report.Hostname = $hostDetails.name
$Report.Cluster = $hostDetails.parent.name
$Report.Portgroup = $hostPG.name
$Report
}

