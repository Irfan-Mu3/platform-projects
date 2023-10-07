#!/bin/bash

num_controllers="$1"
end_of_seq=$((num_controllers-1))
controllers=($(seq 0 1 $end_of_seq))
controller_instances=( "${controllers[@]/#/controller-}" )

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-configs/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

lb_ip=$(az network public-ip show \
          --resource-group irfan-rg \
          --name kubernetes-the-hard-way-ip \
          --query ipAddress \
          --output tsv)

for instance in "${controller_instances[@]}"; do
  feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                     --pool-name kubernetes-lb-backendpool \
                                                     --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)

  scp -oStrictHostKeyChecking=no -P ${feport} -i ~/.ssh/id_rsa_${instance} encryption-configs/encryption-config.yaml azureuser@${lb_ip}:~/
done
