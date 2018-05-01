#Get the current XML configuration
$xmlPortgroups = "C:\Users\joshd\Desktop\SwitchScripts\XML\Portgroups.xml"
[XML]$xmlUpdate = Get-Content $xmlPortgroups
$text = "#text"

#Enter the name of the vCenter to connect to
Write-Host "Enter the FQDN of the " -NoNewline
Write-Host "[vCenter Server]" -ForegroundColor Red -NoNewline
Write-Host " to connect to: " -NoNewline
$vCenterFqdn = Read-Host
Start-Sleep 2
Connect-viserver $vCenterFqdn

Start-Sleep 3

#List the Cluster for removing Portgroup
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Cluster containing the PortGroup:"
$clusterName = $menu | where {$_.Number -eq $clusterNum}

#List the Portgroups in the Cluster
$portgroups = Get-Cluster $clusterName.Name | Get-VMHost | Where {$_.State -eq "Connected"} | Get-Random
$global:i=0
$portgroups | Get-VirtualPortGroup | Where {$_.key -notlike "*dvportgroup*"} | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$pgNum = Read-Host "Select the number of the Portgroup:"
$pgName = $menu | where {$_.Number -eq $pgNum}

#Check if Portgroup is still in use
Write-Host "Checking to see if the Portgroup is still in use..." -foreground "Yellow"
$getPGVMs = Get-Cluster $clusterName.Name | Get-VM | where { ($_ | Get-NetworkAdapter | where {$_.networkname -match $pgName.Name})}
IF ($getPGVMs.count -gt 0){Write-Host "Portgroup is still in use. The below VMs are still connected to $($pgName.Name)" -foreground "Red";Write-Host "$($getPGVMs.name)" -foreground "Red";Write-Host "Script will exit in 60 seconds" -foreground "Red";Start-Sleep 60; EXIT}ELSE{Write-Host "Portgroup $($pgName.Name) is not in use. Continuing..." -foreground "Yellow"}

#Remove the named Portgroup from the hosts
Write-Host "Removing Portgroup $($pgName.Name) from all hosts" -foreground "Yellow"
$getHosts = Get-Cluster $clusterName.Name | Get-VMHost | where { ($_ | Get-VirtualPortgroup -Standard | Where {$_.name -eq $pgName.Name})}
foreach ($vmhost in $getHosts) {
Get-VirtualSwitch -VMHost $vmhost | Get-VirtualPortgroup -name $pgName.Name | Remove-VirtualPortgroup -confirm:$false}

#Remove the named Portgroup element from the XML file
Write-Host "Removing Portgroup $($pgName.Name) from the Config File" -foreground "Yellow"
$clusters = $xmlUpdate.vSwitchConfig.Portgroups.ChildNodes | ? {$pgName.Name -eq $_.name}
IF ($clusters.cluster.count -gt 1){
$clusterTag = $xmlUpdate.vSwitchConfig.Portgroups.portgroup | Where {$_.name -eq $pgName.Name}
$updateTag = $clusterTag.SelectNodes("cluster") | Where {$_.$text -eq $clusterName.Name}
$updateTag.ParentNode.RemoveChild($updateTag)
$xmlUpdate.Save($xmlPortgroups) } ELSE {
$xmlUpdate.vSwitchConfig.Portgroups.ChildNodes | ? {$pgName.Name -eq $_.name} | % {$xmlUpdate.vSwitchConfig.Portgroups.RemoveChild($_)} | Out-Null
$xmlUpdate.Save($xmlPortgroups) }

#Checking hosts to ensure Portgroup has been removed
$getHosts = Get-Cluster $clusterName.Name | Get-VMHost | where { ($_ | Get-VirtualPortgroup -Standard | Where {$_.name -eq $pgName.Name})}
IF ($getHosts.count -eq 0){Write-Host "Portgroup $($pgName.Name) has been removed from all hosts" -foreground "Green"}ELSE{Write-Host "Portgroup is still present on the following hosts and needs to be manually removed" -foreground "Red";Write-Host "$getHosts" -foreground "Red"}

