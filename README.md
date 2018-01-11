# 20170804-19322

AddHostPortGroup.ps1
 
This script prompts the user to enter the name of the portgroup, the VLAN ID, the Virtual Switch it will be added to and the cluster. Then it pulls all the data from the XML file where this data will be stored which is a path defined in the variable $xmlPortgroups. You will need to update the path when its been finalized with Lighthouse for this and all the scripts that reference these files. You will also need to update the name of the vCenter server you’re connecting to in all the scripts and replace “vcenter01.domain.com”
 
The data is first written to the XML file then the port group is added to all the hosts in the cluster that was chosen. After this has been completed, we retrieve all the hosts that have this new portgroup added to ensure it has been added everywhere. If it hasn’t, you’ll need to manually add the port group to any hosts.
 
AllHosts-AuditHostPortGroups.ps1
 
This script checks every host in a cluster to ensure that all the port groups are there and on the correct vSwitch. All the customer needs to do is enter the name of the cluster and we pull all the data from the hosts and from the XML file. We are checking the name, the vlan, and the vSwitch. If there are any issues they will be listed in Red in the output.
 
AllHosts-FixHostvSwitches.ps1
 
This script fixes any issues with existing vSwitches on a per-cluster basis. After the customer enters the name of a cluster, we’ll gather the desired state config from the XML file and then we will check each vSwitch to ensure it has the correct active NICs, standby NICs, load balancing policy, vSwitch failover policy, Notify switches policy, and failback policy. This does a check and a fix and lets you know what it did in each step.
 
AuditHostConfiguration.ps1
 
This script grabs data from all 3 XML files and ensures that the configuration of an individual host matches the desired host configuration policy. The customer enters the name of the host (not the FQDN, just the regular host name) and the script combines the entered name with the desired domain name defined in the XML file and checks for the correct DNS servers, search domain, domain name, syslog server, ntp server, SSH configuration, power policy, and then the datastores that have been added. Any additional checks can be made if needed for advanced system settings like queue depth we just need to add it to the XML file and then I can add more checks into this script.
 
HostProfileScript.ps1
 
This is a host profile script just for setting desired config on a brand new host or resetting the settings of an existing host. The script prompts for the name of a host and whether the host should be placed in maintenance mode before the settings are applied. Not a requirement, but just in case I figured I’d add it in there. Data is gathered from the 3 XML files again and then it starts changing settings. The host is placed in maintenance mode (or not), then DNS is configured, NTP, Syslog, SSH, High performance power policy, vSwitch0 is configured, then the management network is configured, the default “VM Network” portgroup is removed, any additional vSwitches defined in the XML files are added with the appropriate NICs, NIC teaming, security policy, and so on. Then we add portgroups to those virtual switches, we create vmkernel interfaces on the appropriate vSwitches and portgroups and enable vMotion. The advanced settings area is really just for NFS storage (specifically NetApp recommended settings and can be removed or replaced if other settings are required. Then we add any NFS datastores (this can be removed if the customer has no NFS) then we move the host into the appropriate cluster based on what was listed in the XML file and we exit maintenance mode.
 
MigrateVmFromDvSwitchPgToVswitchPg.ps1
 
This is the migration script for moving VMs from dvswitches to vswitches. The customer is prompted to enter the Source portgroup on the dvswitch then the destination port on the vswitch. After that, all the VMs that are currently on that source dvportgroup are gathered then we migrate only the active network adapters on the dvportgroup to the destination portgroup.
 
RemoveHostPortGroup.ps1
 
This script is for removing a port group from a cluster. The customer is prompted to enter the portgroup to be deleted along with the cluster it currently exists on. We first check to see if the portgroup is still in use by getting all the VMs in that cluster where the network adapter matches the name entered. If there are more than zero VMs in that list, we report that error, wait 60 seconds, then exit the script and nothing else happens. If no VMs turn up in that report, we remove that portgroup from all the hosts in that cluster. Once that is complete, we go into the XML file and pull that portgroup out of there as well. If that portgroup name exists on multiple clusters, we only remove the reference to the cluster we’re removing the portgroup from, not the entire portgroup.
 
To explain this better. If you have a portgroup named “Web Network” that exists on “Cluster01” and “Cluster02” and you want to remove it from “Cluster02”,  we only remove the line in the XML file for “Cluster02” and still leave “Web Network” and “Cluster01”. Once this is complete we then do a check on the hosts in that cluster to see if any of them still have a portgroup named whatever was just removed. If they do, it is reported and that portgroup will need to be removed manually.

