## Kubernetes-the-hard-way project + Lets-encrypt-auto-cert project on Azure

This project consists of two things:
1) An implementation of Kubernetes the hard way on Azure based on [Kelsey Hightower's](https://github.com/kelseyhightower/kubernetes-the-hard-way) work.
2) A design for a basic algorithm to obtain Let's Encrypt certs automatically used on the app-gateway of which the controller nodes sit behind.

## Steps to get this to work:

 1. Deploy infra. to obtain Let's Enc. certificate for SSL
```
terraform -chdir=letsencrypt-tf -var="tenant_id=ten_id123456" -var="subscription_id=sub_id123456" apply <<< yes
. letsencrypt-sh/sslcerts.sh
```
2. Copy the cert into kubernetes-tf folder
3. Deploy infrastructure for Kubernetes
```
terraform -chdir=kubernetes-tf -var="tenant_id=ten_id123456" -var="subscription_id=sub_id123456" apply <<< yes
. kubernetes-sh/main.sh
```

## To modify number of controllers/workers
1. Under /kubernetes-tf/compute_resources.tf, modify the no. of suffixes for the controller or workers:
```
  controllers         = ["0", "1", ...]
  workers             = ["0", "1", ...]
```
Use numbers as above.
2. Simultaneously, under kubernetes-sh/main.sh, update the number of controllers/workers:
```
num_controllers=1
num_workers=1
```
