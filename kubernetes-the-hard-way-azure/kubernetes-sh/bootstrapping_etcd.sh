
num_controllers="$1"
end_of_seq=$((num_controllers-1))
controllers=($(seq 0 1 $end_of_seq))
controller_instances=( "${controllers[@]/#/controller-}" )

lb_ip=$(az network public-ip show \
          --resource-group irfan-rg \
          --name kubernetes-the-hard-way-ip \
          --query ipAddress \
          --output tsv)

echo "bootstrapping-etcd: controller instances"
echo "${controller_instances[@]}"

for instance in "${controller_instances[@]}"; do
  feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                     --pool-name kubernetes-lb-backendpool \
                                                     --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)

  ssh -i ~/.ssh/id_rsa_${instance} azureuser@${lb_ip} -p ${feport} -oStrictHostKeyChecking=no 'bash -s' < bootstrap_scripts/etcd_script.sh "$num_controllers"
done
