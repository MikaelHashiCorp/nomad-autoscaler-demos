#!/bin/bash

resource_group="hcs-autosc-main-mws-maximum-flea"

for scale_set_name in $(az vmss list --resource-group $resource_group --query "[].name" -o tsv); do 
  echo "Scale Set: $scale_set_name"
  echo -e "InstanceName\tPublicIP"
  az vmss list-instances --resource-group $resource_group --name $scale_set_name --query "[].{InstanceName: osProfile.computerName, InstanceID: instanceId}" -o tsv | while read -r instanceName instanceID; do 
    publicIp=$(az vmss list-instance-public-ips --resource-group $resource_group --name $scale_set_name --query "[?instanceId=='$instanceID'].ipAddress" -o tsv)
    echo -e "$instanceName\t${publicIp:-None}"
  done | column -t
done










