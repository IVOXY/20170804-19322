#Enter the name of the vCenter to connect to
Write-Host "Enter the FQDN of the " -NoNewline
Write-Host "[vCenter Server]" -ForegroundColor Red -NoNewline
Write-Host " to connect to: " -NoNewline
$vCenterFqdn = Read-Host
Start-Sleep 5
Connect-viserver $vCenterFqdn

#List the Clusters
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Cluster containing the portgroups to migrate"
$clusterName = $menu | where {$_.Number -eq $clusterNum}

#List the VDPortGroups
$hostSelect = Get-Cluster $clusterName.Name | Get-VMHost | Where {$_.State -eq "Connected"} | Get-Random
$global:i=0
$hostSelect | Get-VDSwitch | Get-VDPortGroup | Where {$_.IsUplink -like "False"} | Sort name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$vdPortNum = Read-Host "Select the number of the VDPortGroup to migrate"
$vdPortName = $menu | where {$_.Number -eq $vdPortNum}

#List the vSwitch PortGroups
#$hostSelect = Get-Cluster $clusterName | Get-VMHost | Where {$_.State -eq "Connected"} | Get-Random
$global:i=0
$hostSelect | Get-VirtualSwitch | Get-VirtualPortGroup | Where {$_.Key -notlike "*dvportgroup*"} | Sort name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$vPortNum = Read-Host "Select the number of the Virtual PortGroup destination"
$vPortName = $menu | where {$_.Number -eq $vPortNum}

#Get all the VMs on the source dvPortgroup
Write-Host "Getting all the VMs on the source port $($vdPortname.name) in $($clusterName.name)" -foreground "Yellow"
$vmNameList = Get-Cluster $clusterName.Name | Get-VM | Get-NetworkAdapter | Where {$_.Networkname -eq $vdPortName.Name} 

$vmNameList | Sort Parent | Select Parent, Name, Type, NetworkName | format-table -Autosize

Read-Host "Press Enter to Continue with migration of the VMs listed above"

#Migrate VMs to destination Portgroup
Write-Host "Migrating all VMs from source dvPorgroup to destination Portgroup" -foreground "Yellow"
foreach ($a in $vmNameList) {
$a.parent | Get-NetworkAdapter | Where  {$_.NetworkName -eq $vdPortname.Name} | Set-NetworkAdapter -NetworkName $vPortName.name -Confirm:$false
}
