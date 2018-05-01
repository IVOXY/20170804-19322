#Ignore invalid certifates at login
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

#Enter the name of the vCenter to connect to
Write-Host "Enter the FQDN of the " -NoNewline
Write-Host "[vCenter Server]" -ForegroundColor Red -NoNewline
Write-Host " to connect to: " -NoNewline
$vCenterFqdn = Read-Host
Start-Sleep 3

Connect-viserver $vCenterFqdn

Write-Host "Creating XML file for Portgroup Configuration..." -foreground "Yellow"

$xmlNetworkPath="C:\Users\joshd\Desktop\SwitchScripts\XML\Portgroups.xml"
$xmlNetwork=[xml]@'
<vSwitchConfig>
  <templates>
	<vSwitch>
	  <ActiveNic></ActiveNic>
	  <StandbyNic></StandbyNic>
	  <allowPromiscuous></allowPromiscuous>
      <forgedTransmits></forgedTransmits>
      <macChanges></macChanges>
      <LoadBalancingPolicy></LoadBalancingPolicy>
      <MTU></MTU>
      <FailbackEnabled></FailbackEnabled>
      <NotifySwitches></NotifySwitches>
      <NetworkFailoverDetectionPolicy></NetworkFailoverDetectionPolicy>
	</vSwitch>
	<Portgroup>
	  <vlanId></vlanId>
	  <virtualSwitch></virtualSwitch>
	  <cluster></cluster>
	</Portgroup>
  </templates>
  <vSwitches>
    <vSwitch Name="vSwitch0">
      <ActiveNic>vmnic0, vmnic1</ActiveNic>
      <StandbyNic></StandbyNic>
      <allowPromiscuous>False</allowPromiscuous>
      <forgedTransmits>False</forgedTransmits>
      <macChanges>False</macChanges>
      <LoadBalancingPolicy>LoadBalanceSrcId</LoadBalancingPolicy>
      <MTU>1500</MTU>
      <FailbackEnabled>True</FailbackEnabled>
      <NotifySwitches>True</NotifySwitches>
      <NetworkFailoverDetectionPolicy>LinkStatus</NetworkFailoverDetectionPolicy>
    </vSwitch>
    <vSwitch Name="vSwitch0">
      <ActiveNic>vmnic0, vmnic1</ActiveNic>
      <StandbyNic></StandbyNic>
      <allowPromiscuous>False</allowPromiscuous>
      <forgedTransmits>False</forgedTransmits>
      <macChanges>False</macChanges>
      <LoadBalancingPolicy>LoadBalanceSrcId</LoadBalancingPolicy>
      <MTU>1500</MTU>
      <FailbackEnabled>True</FailbackEnabled>
      <NotifySwitches>True</NotifySwitches>
      <NetworkFailoverDetectionPolicy>LinkStatus</NetworkFailoverDetectionPolicy>
    </vSwitch>
  </vSwitches>
  <Portgroups>
    <test />
  </Portgroups>
</vSwitchConfig>
'@
$xmlNetwork.Save($xmlNetworkPath)

$networkCheck = Test-Path $xmlNetworkPath
IF ($networkCheck -eq $True){Write-Host "Portgroup file created successfully. Continuing..." -foreground "Green"}
ELSE
{Write-Host "Portgroup file not created. Exiting..." -foreground "Red";Exit}

Write-Host "Creating XML file for Host Configuration..." -foreground "Yellow"

$xmlHostPath="C:\Users\joshd\Desktop\SwitchScripts\XML\HostConfig.xml"
$xmlHost=[xml]@'
<hostConfig>
  <commonParams>
    <test />
  </commonParams>
  <templates>
    <host>
      <cluster>
      </cluster>
      <vmkernels>
        <test />
      </vmkernels>
    </host>
    <vmkernels>
      <vmkernel name="test">
        <IP>
        </IP>
        <subnetMask>
        </subnetMask>
        <portGroup>
        </portGroup>
        <mtu>
        </mtu>
		<vlanId>
        </vlanId>
		<virtualSwitch>
		</virtualSwitch>
      </vmkernel>
    </vmkernels>
  </templates>
  <hosts>
    <test />
  </hosts>
</hostConfig>
'@
$xmlHost.Save($xmlHostPath)

$hostCheck = Test-Path $xmlHostPath
IF ($hostCheck -eq $True){Write-Host "Portgroup file created successfully. Continuing..." -foreground "Green"}
ELSE
{Write-Host "Portgroup file not created. Exiting..." -foreground "Red";Exit}


$domainName = Read-Host "Enter the desired domain name (e.g. contoso.com):"
$ntpServer1 = Read-Host "Enter the primary NTP Server:"
$ntpServer2 = Read-Host "Enter the secondary NTP Server:"
$dnsServer1 = Read-Host "Enter the primary DNS Server:"
$dnsServer2 = Read-Host "Enter the secondary DNS Server:"
$syslogServer = Read-Host "Enter the address of the Syslog server:"
$enableSSH = Read-Host "Enable SSH on hosts? (True or False):"

Write-Host "Populating Common Parameters into XML file..." -foreground "Yellow"

[XML]$xmlUpdate = Get-Content $xmlHostPath
$newDomainElement = $xmlUpdate.CreateElement("domainName")
$newDomainElement.InnerText = $domainName
$xmlUpdate.SelectSingleNode("//commonParams").AppendChild($newDomainElement) | Out-Null
$newNtp1Element = $xmlUpdate.CreateElement("ntpServer1")
$newNtp1Element.InnerText = $ntpServer1
$xmlUpdate.SelectSingleNode("//commonParams").AppendChild($newNtp1Element) | Out-Null
$newNtp2Element = $xmlUpdate.CreateElement("ntpServer2")
$newNtp2Element.InnerText = $ntpServer2
$xmlUpdate.SelectSingleNode("//commonParams").AppendChild($newNtp2Element) | Out-Null
$newDns1Element = $xmlUpdate.CreateElement("dnsServer1")
$newDns1Element.InnerText = $dnsServer1
$xmlUpdate.SelectSingleNode("//commonParams").AppendChild($newDns1Element) | Out-Null
$newDns2Element = $xmlUpdate.CreateElement("dnsServer2")
$newDns2Element.InnerText = $dnsServer2
$xmlUpdate.SelectSingleNode("//commonParams").AppendChild($newDns2Element) | Out-Null
$newSyslogElement = $xmlUpdate.CreateElement("syslogServer")
$newSyslogElement.InnerText = $syslogServer
$xmlUpdate.SelectSingleNode("//commonParams").AppendChild($newSyslogElement) | Out-Null
$newSSHElement = $xmlUpdate.CreateElement("enableSSH")
$newSSHElement.InnerText = $enableSSH
$xmlUpdate.SelectSingleNode("//commonParams").AppendChild($newSSHElement) | Out-Null
$xmlUpdate.hostConfig.commonParams.childnodes|where {$_.name -eq "test"} | % {$xmlUpdate.hostConfig.commonParams.RemoveChild($_)} | Out-Null
$xmlUpdate.Save($xmlHostPath)

Read-Host "Press Enter to begin host discovery"

[XML]$xmlUpdate = Get-Content $xmlHostPath

$getHosts = Get-VMHost
foreach ($esx in $getHosts) {
$testHost = $xmlHostConfig.hostConfig.hosts.host|Where {$_.name -eq $esx}
IF ($testHost -eq $null) {
$getHostNetwork = Get-VMhost $esx
$parentNode = $xmlUpdate.hostConfig.templates
$destinationNode = $xmlUpdate.hostConfig.hosts
$cloneNode = $parentNode.SelectSingleNode("host")
$addNameAttribute = $xmlUpdate.CreateAttribute("name")
$addNameAttribute.Value = $esx.Name
$newNode = $xmlUpdate.CreateElement("host")
$newNode.InnerXML = $cloneNode.InnerXML
[void]$destinationNode.AppendChild($newNode).Attributes.Append($addNameAttribute)
$updateCluster = ($xmlUpdate.hostConfig.hosts.host|Where {$_.name -eq $esx.Name}).cluster = $esx.Parent.Name
$getHostNetwork = Get-VMhost $esx | Get-VMHostNetworkAdapter | Where {$_.name -like "vmk*"}
foreach ($vmk in $getHostNetwork) {
$pgProperties = Get-VMHost $esx | Get-VirtualPortgroup -name $vmk.PortgroupName
$vmkernelDest = ($xmlUpdate.hostConfig.hosts.host|Where {$_.name -eq $esx.Name}).vmkernels
$vmkernelClone = $xmlUpdate.hostConfig.templates.vmkernels.SelectSingleNode("vmkernel")
$addVmkAttribute = $xmlUpdate.CreateAttribute("name")
$addVmkAttribute.Value = $vmk.name
$newVmkNode = $xmlUpdate.CreateElement("vmkernel")
$newVmkNode.InnerXML = $vmkernelClone.InnerXML
[void]$vmkernelDest.AppendChild($newVmkNode).Attributes.Append($addVmkAttribute)
$updateVmkIP = ($vmkernelDest.vmkernel|Where {$_.name -eq $vmk.Name}).IP = $vmk.IP
$updateVmkSubnet = ($vmkernelDest.vmkernel|Where {$_.name -eq $vmk.Name}).subnetMask = $vmk.SubnetMask
$updateVmkVlanId = ($vmkernelDest.vmkernel|Where {$_.name -eq $vmk.Name}).vlanId = $pgProperties.vlanId.ToString()
$updateVmkPortGroupName = ($vmkernelDest.vmkernel|Where {$_.name -eq $vmk.Name}).portGroup = $vmk.PortGroupName
$updateVmkMtu = ($vmkernelDest.vmkernel|Where {$_.name -eq $vmk.Name}).mtu = $vmk.mtu.ToString()
$updateVswitch = ($vmkernelDest.vmkernel|Where {$_.name -eq $vmk.Name}).virtualSwitch = $pgProperties.virtualSwitchName
$xmlUpdate.hostConfig.hosts.childnodes|where {$_.name -eq "test"} | % {$xmlUpdate.hostConfig.hosts.RemoveChild($_)} | Out-Null
($xmlUpdate.hostConfig.hosts.host|where {$_.name -eq $esx}).vmkernels.childNodes|Where {$_.name -eq "test"} | % {($xmlUpdate.hostConfig.hosts.host|where {$_.name -eq $esx}).vmkernels.RemoveChild($_)} | Out-Null
}}
ELSE {Write-Host "Host settings already exist. Skipping..." -foreground "Yellow"}
}
$xmlUpdate.Save($xmlHostPath)

Write-Host "The following ESXi hosts exist in $($xmlFilePath)" -foreground "Yellow"
$xmlUpdate.hostConfig.hosts.host | Sort cluster | format-table

Read-Host "Press Enter to begin Network discovery"

[XML]$xmlNetwork = Get-Content $xmlNetworkPath
$getClusters = Get-Cluster
foreach ($cluster in $getClusters) {
$getPortgroups = $cluster | Get-VMHost | Where {$_.state -eq "Connected"} | Get-Random | Get-VirtualPortGroup | Where {$_.key -notlike "*dvportgroup*"}
foreach ($pgName in $getPortGroups) {
$testPg = $xmlNetwork.vSwitchConfig.Portgroups.Portgroup|Where {$_.name -eq $pgName.Name}
IF ($testPg -eq $null) {
$parentNode = $xmlNetwork.vSwitchConfig.templates
$destinationNode = $xmlNetwork.vSwitchConfig.Portgroups
$cloneNode = $parentNode.SelectSingleNode("Portgroup")
$addNameAttribute = $xmlNetwork.CreateAttribute("name")
$addNameAttribute.Value = $pgName.Name
$newNode = $xmlNetwork.CreateElement("Portgroup")
$newNode.InnerXML = $cloneNode.InnerXML
[void]$destinationNode.AppendChild($newNode).Attributes.Append($addNameAttribute)
$updateNetwork = ($xmlNetwork.vSwitchConfig.Portgroups.Portgroup|Where {$_.name -eq $pgName.Name})
$updateVLAN = $updateNetwork.vlanId = $pgName.VLanId.ToString()
$updateVirtualSwitch = $updateNetwork.virtualSwitch = $pgName.VirtualSwitchName
$updateCluster = $updateNetwork.cluster = $cluster.Name
} ELSE {($testCluster = $testPg|Where {$_.cluster -eq $cluster.Name}); 
IF ($testCluster -eq $null) {
$addCluster = $xmlNetwork.CreateElement("cluster");
$addCluster.InnerText = $cluster
$testPg.AppendChild($addCluster) | Out-Null }ELSE{}}
}}
$xmlNetwork.Save($xmlNetworkPath)
