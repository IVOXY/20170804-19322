


try {
    $portgroups = get-content -raw -path ".\cdb\cluster1-portgroups.json" |convertfrom-json
}
catch {throw "I don't have a valid portgroup database definition"}

foreach ($portgroup in $portgroups.portgroups) {
    write-host $portgroup.name
    write-host $portgroup.vlan

}