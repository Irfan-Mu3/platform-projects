KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show \
                                    --resource-group irfan-rg \
                                    --name kubernetes-the-hard-way-ip \
                                    --query ipAddress \
                                    --output tsv)

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=cfssl-items/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

kubectl config set-credentials admin \
  --client-certificate=cfssl-items/admin.pem \
  --client-key=cfssl-items/admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
  --cluster=kubernetes-the-hard-way \
  --user=admin

kubectl config use-context kubernetes-the-hard-way


# verification
kubectl version
kubectl get nodes