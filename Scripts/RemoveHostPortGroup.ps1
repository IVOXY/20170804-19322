#Get the current XML configuration
$xmlPortgroups = "C:\Users\joshd\Documents\Ivoxy\Lighthouse\cdb\XML\xml-portgroups.xml"
$xmlUpdate = [System.Xml.XmlDocument](Get-Content $xmlPortgroups)
$text = "#text"

#Input the name of the new Portgroup to be removed
$portGroup = Read-Host -Prompt "Enter the name of the Portgroup to be remove (ex: Management Network)"
$cluster = Read-Host -Prompt "Enter the name of the cluster for this Portgroup (ex: Cluster1)"

#Check if Portgroup is still in use
Write-Host "Checking to see if the Portgroup is still in use..." -foreground "Yellow"
$getPGVMs = Get-Cluster $cluster | Get-VM | where { ($_ | Get-NetworkAdapter | where {$_.networkname -match $portGroup})}
IF ($getPGVMs.count -gt 0){Write-Host "Portgroup is still in use. The below VMs are still connected to $portGroup" -foreground "Red";Write-Host "$getPGVMs.name" -foreground "Red";Write-Host "Script will exit in 60 seconds" -foreground "Red";Start-Sleep 60; EXIT}ELSE{Write-Host "Portgroup $portGroup is not in use. Continuing..." -foreground "Yellow"}

#Remove the named Portgroup from the hosts
Write-Host "Removing Portgroup $portGroup from all hosts" -foreground "Yellow"
$getHosts = Get-Cluster $cluster | Get-VMHost | where { ($_ | Get-VirtualPortgroup -Standard | Where {$_.name -eq $portGroup})}
foreach ($vmhost in $getHosts) {
Get-VirtualSwitch -VMHost $vmhost | Get-VirtualPortgroup -name $portGroup | Remove-VirtualPortgroup -confirm:$false}

#Remove the named Portgroup element from the XML file
Write-Host "Removing Portgroup $portGroup from the Config File" -foreground "Yellow"
$clusters = $xmlUpdate.vSwitchConfig.Portgroups.ChildNodes | ? {$portGroup -eq $_.name}
IF ($clusters.cluster.count -gt 1){
$clusterTag = $xmlUpdate.vSwitchConfig.Portgroups.portgroup | Where {$_.name -eq $portGroup}
$updateTag = $clusterTag.SelectNodes("cluster") | Where {$_.$text -eq $cluster}
$updateTag.ParentNode.RemoveChild($updateTag)
$xmlUpdate.Save($xmlPortgroups) } ELSE {
$xmlUpdate.vSwitchConfig.Portgroups.ChildNodes | ? {$portGroup -eq $_.name} | % {$xmlUpdate.vSwitchConfig.Portgroups.RemoveChild($_)} | Out-Null
$xmlUpdate.Save($xmlPortgroups) }

#Checking hosts to ensure Portgroup has been removed
$getHosts = Get-Cluster $cluster | Get-VMHost | where { ($_ | Get-VirtualPortgroup -Standard | Where {$_.name -eq $portGroup})}
IF ($getHosts.count -eq 0){Write-Host "Portgroup $portGroup has been removed from all hosts" -foreground "Green"}ELSE{Write-Host "Portgroup is still present on the following hosts and needs to be manually removed" -foreground "Red";Write-Host "$getHosts" -foreground "Red"}


