
num_controllers=1
num_workers=1

# keys & configs
mkdir cfssl-items encryption-configs kubeconfig-items pod-configs

# Create PKI, Kube config files and data enc. keys. Upload to respected vm.
. certificate_authority.sh "$num_controllers" "$num_workers"
. kube_config_files.sh "$num_controllers" "$num_workers"
. data_encryption_keys.sh "$num_workers"

# Bootstrap nodes
. bootstrapping_etcd.sh "$num_controllers"
. bootstrapping_controllers.sh "$num_controllers"
. bootstrapping_workers.sh "$num_workers"

# Configure kubectl for remoting
. configuring_kubernetes.sh

# Create pods
. dns_addon.sh
. nginx_addon.sh

