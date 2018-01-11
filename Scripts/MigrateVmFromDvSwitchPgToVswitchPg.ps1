#Get the name of the source dvPortgroup
$sourcedvPort = Read-Host -Prompt "Enter the name of the source dvPortgroup"
$destPort = Read-Host -Prompt "Enter the name of the destination Portgroup"

#Connect to the vCenter Instance
$vcenter = "vcenter01.domain.com"
connect-viserver $vcenter


#Get all the VMs on the source dvPortgroup
Write-Host "Getting all the VMs on the source dvPortgroup" -foreground "Yellow"
$getVMs = get-vdswitch "dvs-name" | get-vdportgroup $sourcedvPort | Get-VM

#Migrate VMs to destination Portgroup
Write-Host "Migrating all VMs from source dvPorgroup to destination Portgroup" -foreground "Yellow"
foreach ($a in $getVMs) {
$a | Get-NetworkAdapter | Where  {$_.NetworkName -eq $sourcedvPort} | Set-NetworkAdapter -NetworkName $destPort -Confirm:$false
}

