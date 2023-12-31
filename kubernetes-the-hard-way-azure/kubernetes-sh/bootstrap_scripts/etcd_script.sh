num_controllers="$1"
end_of_seq=$((num_controllers-1))
controllers=($(seq 0 1 $end_of_seq))

etcd_servers=()
for index in ${!controllers[*]}; do
  etcd_servers+=("controller-${index}=https://10.240.0.1${index}:2380")
done

etcd_list=$(echo "${etcd_servers[@]}" | sed 's/ /,/g' )

# For idempotency
rm etcd-v3.4.15-linux-amd64 -rf
rm etcd-v3.4.15-linux-amd64.tar.gz -rf
sudo rm /var/lib/etcd -rf
sudo systemctl stop etcd
sudo systemctl disable etcd

wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar.gz"

tar -xvf etcd-v3.4.15-linux-amd64.tar.gz
sudo mv etcd-v3.4.15-linux-amd64/etcd* /usr/local/bin/

sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd  #delete this if you need to reset etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

INTERNAL_IP=$( echo $(hostname -I) | xargs)
ETCD_NAME=$(hostname -s)

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster $etcd_list \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


# start etcd
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd


#### verify
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
