# To read *.pem files, use: openssl x509 -in *.pem -text -noout

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


#  Provision a Certificate Authority that can be used to generate additional TLS certificates:
#  Generate the CA configuration file, certificate, and private key:
cat > cfssl-items/ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca cfssl-items/ca-csr.json | cfssljson -bare cfssl-items/ca
# Generates ca.pem and ca-key.pem

# Use the below, if we want to create an intermediate CA.
#cfssl gencert -initca ca-csr.json | cfssljson -bare root-ca

# Provision a Profile, that describes general info about the certificate (to be created),
# i.e. their duration and uses.
cat > cfssl-items/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "intermediate-kubernetes": {
        "usages": ["cert sign", "crl sign"],
        "expiry": "8760h",
        "ca_constraint": {
          "is_ca": true,
          "max_path_len": 1
        }
      },
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

## If using as intermediate:
## Generate the private key and CSR for the intermediate CA
#cfssl genkey ca-csr.json \
#| cfssljson -bare ca
## Sign intermediate with root-ca
#cfssl sign -ca root-ca.pem \
#  -ca-key root-ca-key.pem \
#  -config ca-config.json \
#  -profile kubernetes \
#  ca.csr \
#| cfssljson -bare ca

# Now, generate client and server certificates for each Kubernetes component

# Generate admin client certificate and private key
cat > cfssl-items/admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=cfssl-items/ca.pem \
  -ca-key=cfssl-items/ca-key.pem \
  -config=cfssl-items/ca-config.json \
  -profile=kubernetes \
  cfssl-items/admin-csr.json | cfssljson -bare cfssl-items/admin


# Kubelet must use a credential that identifies them as being in the system:nodes group,
# with a username of system:node:<nodeName>
# Generate a certificate and private key for each Kubernetes worker node:

for instance in "${worker_instances[@]}"; do
cat > cfssl-items/${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
EXTERNAL_IP="${lb_ip}"
INTERNAL_IP=$(az vm show -d -g irfan-rg -n ${instance} --query privateIps -otsv)

cfssl gencert \
  -ca=cfssl-items/ca.pem \
  -ca-key=cfssl-items/ca-key.pem \
  -config=cfssl-items/ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  cfssl-items/${instance}-csr.json | cfssljson -bare cfssl-items/${instance}
done

# Generate the kube-controller-manager client certificate and private key:
cat > cfssl-items/kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=cfssl-items/ca.pem \
  -ca-key=cfssl-items/ca-key.pem \
  -config=cfssl-items/ca-config.json \
  -profile=kubernetes \
  cfssl-items/kube-controller-manager-csr.json | cfssljson -bare cfssl-items/kube-controller-manager


# Generate the kube-proxy client certificate and private key
cat > cfssl-items/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=cfssl-items/ca.pem \
  -ca-key=cfssl-items/ca-key.pem \
  -config=cfssl-items/ca-config.json \
  -profile=kubernetes \
  cfssl-items/kube-proxy-csr.json | cfssljson -bare cfssl-items/kube-proxy


# Generate the kube-scheduler client certificate and private key:
cat > cfssl-items/kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=cfssl-items/ca.pem \
  -ca-key=cfssl-items/ca-key.pem \
  -config=cfssl-items/ca-config.json \
  -profile=kubernetes \
  cfssl-items/kube-scheduler-csr.json | cfssljson -bare cfssl-items/kube-scheduler


# The Kubernetes API Server Certificate
# The kubernetes-the-hard-way static IP address will be included in the list of subject alternative names for the Kubernetes API Server certificate.
# This will ensure the certificate can be validated by remote clients.
# Generate the Kubernetes API Server certificate and private key:
KUBERNETES_PUBLIC_ADDRESS=${lb_ip}
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local
cat > cfssl-items/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=cfssl-items/ca.pem \
  -ca-key=cfssl-items/ca-key.pem \
  -config=cfssl-items/ca-config.json \
  -hostname=10.32.0.1,$(echo "${controllers[@]/#/10.240.0.1}"  | sed 's/ /,/g'),${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  cfssl-items/kubernetes-csr.json | cfssljson -bare cfssl-items/kubernetes

# The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens
# as described in the managing service accounts documentation.
# Generate the service-account certificate and private key:
cat > cfssl-items/service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF
cfssl gencert \
  -ca=cfssl-items/ca.pem \
  -ca-key=cfssl-items/ca-key.pem \
  -config=cfssl-items/ca-config.json \
  -profile=kubernetes \
  cfssl-items/service-account-csr.json | cfssljson -bare cfssl-items/service-account



## Upload
for instance in "${worker_instances[@]}"; do
  feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                   --pool-name kubernetes-lb-workerpool \
                                                   --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)

  scp -oStrictHostKeyChecking=no -P ${feport} -i ~/.ssh/id_rsa_${instance} \
    cfssl-items/ca.pem \
    cfssl-items/${instance}-key.pem \
    cfssl-items/${instance}.pem \
    azureuser@${lb_ip}:~/
done

for instance in "${controller_instances[@]}"; do
  feport=$(az network lb address-pool address list --lb-name kubernetes-lb \
                                                     --pool-name kubernetes-lb-backendpool \
                                                     --resource-group irfan-rg --query "[?contains(name,'irfan-rg_kubernetes-nic-${instance}ipconfig1')].inboundNatRulesPortMapping[0].frontendPort" -otsv)

  scp -oStrictHostKeyChecking=no -P ${feport} -i ~/.ssh/id_rsa_${instance} \
    cfssl-items/admin.pem \
    cfssl-items/admin-key.pem \
    cfssl-items/ca.pem \
    cfssl-items/ca-key.pem \
    cfssl-items/kubernetes-key.pem \
    cfssl-items/kubernetes.pem \
    cfssl-items/service-account-key.pem \
    cfssl-items/service-account.pem azureuser@${lb_ip}:~/
done
