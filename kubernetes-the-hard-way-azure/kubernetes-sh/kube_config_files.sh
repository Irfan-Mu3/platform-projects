
num_controllers="$1"
num_workers="$2"

ctrl_end_of_seq=$((num_controllers-1))
controllers=($(seq 0 1 $ctrl_end_of_seq))
controller_instances=( "${controllers[@]/#/controller-}" )

work_end_of_seq=$((num_workers-1))
workers=($(seq 0 1 $work_end_of_seq))
worker_instances=( "${workers[@]/#/worker-}" )

lb_ip=$(az network public-ip show \
          --resource-group irfan-rg \
          --name kubernetes-the-hard-way-ip \
          --query ipAddress \
          --output tsv)

KUBERNETES_PUBLIC_ADDRESS=${lb_ip}

for instance in "${worker_instances[@]}"; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=cfssl-items/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kubeconfig-items/${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=cfssl-items/${instance}.pem \
    --client-key=cfssl-items/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=kubeconfig-items/${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=kubeconfig-items/${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=kubeconfig-items/${instance}.kubeconfig
done

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=cfssl-items/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kubeconfig-items/kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=cfssl-items/kube-proxy.pem \
  --client-key=cfssl-items/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kubeconfig-items/kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kubeconfig-items/kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kubeconfig-items/kube-proxy.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=cfssl-items/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kubeconfig-items/kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=cfssl-items/kube-controller-manager.pem \
  --client-key=cfssl-items/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kubeconfig-items/kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kubeconfig-items/kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kubeconfig-items/kube-controller-manager.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=cfssl-items/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kubeconfig-items/kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=cfssl-items/kube-scheduler.pem \
  --client-key=cfssl-items/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kubeconfig-items/kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kubeconfig-items/kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kubeconfig-items/kube-scheduler.kubeconfig

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=cfssl-items/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kubeconfig-items/admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=cfssl-items/admin.pem \
  --client-key=cfssl-items/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=kubeconfig-items/admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=kubeconfig-items/admin.kubeconfig

kubectl config use-context default --kubeconfig=kubeconfig-items/admin.kubeconfig

# Upload config files

for instance in "${worker_instances[@]}" ; do
  feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                   --pool-name kubernetes-lb-workerpool \
                                                   --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)

  scp -oStrictHostKeyChecking=no -P ${feport} -i ~/.ssh/id_rsa_${instance} kubeconfig-items/${instance}.kubeconfig \
    kubeconfig-items/kube-proxy.kubeconfig azureuser@${lb_ip}:~/
done

for instance in "${controller_instances[@]}"; do
  feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                     --pool-name kubernetes-lb-backendpool \
                                                     --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)

  scp -oStrictHostKeyChecking=no -P ${feport} -i ~/.ssh/id_rsa_${instance} \
    kubeconfig-items/admin.kubeconfig \
    kubeconfig-items/kube-controller-manager.kubeconfig \
    kubeconfig-items/kube-scheduler.kubeconfig \
    azureuser@${lb_ip}:~/
done
