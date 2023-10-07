#!/bin/bash

dry_run=$1

# assumes snap is installed (it is on ubuntu)
sudo snap install core </dev/null
sudo snap refresh core </dev/null

# removes auto-installed certbot if any
sudo apt-get remove certbot </dev/null

# install certbot
sudo snap install --classic certbot </dev/null

# prepare certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot -f

# make hook files executable if not
chmod +x auth-hook.sh
chmod +x manual-cleanup-hook.sh
chmod +x deploy-hook.sh

certbot_args=(
  --manual
  --force-renewal
  -d *.irfan-k8s.bips.bjsscloud.net
  -d irfan-k8s.bips.bjsscloud.net
  -n
  --agree-tos
  --preferred-challenges dns-01
  --server https://acme-v02.api.letsencrypt.org/directory
  --register-unsafely-without-email
  --rsa-key-size 4096
  --manual-auth-hook ./auth-hook.sh
  --manual-cleanup-hook ./manual-cleanup-hook.sh
  --deploy-hook ./deploy-hook.sh
  --cert-name kube-certs
)

if [[ "$dry_run" = true ]]; then
  echo "dry running..."
  certbot_args+=(--dry-run)
fi

sudo certbot certonly "${certbot_args[@]}"

# wait for other thread to consume file first, before ending to prevent race
while [ ! -f DEPLOYED_CERTIFICATES ]
do
  sleep 2
done

echo "Certbot completed"
exit