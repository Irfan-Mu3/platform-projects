
num_workers="$1"
end_of_seq=$((num_workers-1))
workers=($(seq 0 1 $end_of_seq))
worker_instances=( "${workers[@]/#/worker-}" )

lb_ip=$(az network public-ip show \
          --resource-group irfan-rg \
          --name kubernetes-the-hard-way-ip \
          --query ipAddress \
          --output tsv)

for instance in "${worker_instances[@]}" ; do
  feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                     --pool-name kubernetes-lb-workerpool \
                                                     --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)

  ssh -i ~/.ssh/id_rsa_${instance} azureuser@${lb_ip} -p ${feport} -oStrictHostKeyChecking=no 'bash -s' < bootstrap_scripts/workers_script.sh
done

# Verify (run on any controller) (might need to wait a few seconds for workers to be found)
sleep 15
instance="controller-0"
feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                     --pool-name kubernetes-lb-backendpool \
                                                     --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)
ssh -i ~/.ssh/id_rsa_${instance} azureuser@${lb_ip} -p ${feport} -oStrictHostKeyChecking=no -t "kubectl get nodes --kubeconfig admin.kubeconfig"
