lb_ip=$(az network public-ip show \
          --resource-group irfan-rg \
          --name kubernetes-the-hard-way-ip \
          --query ipAddress \
          --output tsv)


kubectl create secret generic kubernetes-the-hard-way \
  --from-literal="mykey=mydata"

instance="controller-0"
feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                     --pool-name kubernetes-lb-backendpool \
                                                     --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)
ssh -i ~/.ssh/id_rsa_${instance} azureuser@${lb_ip} -p ${feport} -oStrictHostKeyChecking=no -t "sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem\
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"

#####
kubectl create deployment nginx --image=nginx
# wait till ready (13s ish)
kubectl get pods -l app=nginx

POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8080:80

# on another term
curl --head http://127.0.0.1:8080

# on previous term, end port-forwarding
^C

kubectl logs $POD_NAME
kubectl exec -ti $POD_NAME -- nginx -v
# nginx version: nginx/1.23.4

# makes a port on the node (a vm) to reach into the pod's virtual port (80)
# the node port is randomly selected here
kubectl expose deployment nginx --port 80 --type NodePort -n default
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')

# This part is needed regardless
az network nsg rule create -g irfan-rg \
  --nsg-name kubernetes-nsg \
  -n AllowsKubeNginxService \
  --priority 104 \
  --destination-port-ranges "${NODE_PORT}" \
  --destination-asgs kubernetes-asg \
  --access Allow \
  --protocol TCP \
  --description "Allow Kubernetes Nginx Pod access"

# If using LB is used for connection, we hit feport, then that hits NODE_PORT through below (this allows directly targeting a VM)
az network lb inbound-nat-rule create -g irfan-rg \
  --lb-name kubernetes-lb \
  --backend-pool-name kubernetes-lb-workerpool \
  --frontend-ip-name kubernetes-lb-frontend \
  -n kubernetes-inboundnat-nginx-nodeport \
  --protocol Tcp \
  --frontend-port-range-start 1000 \
  --frontend-port-range-end  1100 \
  --backend-port ${NODE_PORT}

#hardcoded query ([-1])
# find node instance
kubectl get pods -o wide --all-namespaces | grep nginx
instance=... #type into terminal from result above
feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                     --pool-name kubernetes-lb-workerpool \
                                                     --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[-1].frontendPort" -otsv)

curl -I http://"${EXTERNAL_IP}":"${feport}"

