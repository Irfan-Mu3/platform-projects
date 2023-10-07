
dry_run=false

cs_ip=$(az network public-ip show \
          --resource-group irfan-certbot-rg \
          --name kubernetes-the-hard-way-certbot-ip \
          --query ipAddress \
          --output tsv)

instance="certbot"

# upload certbot hooks
scp -oStrictHostKeyChecking=no -i ~/.ssh/id_rsa_${instance} hooks/auth-hook.sh hooks/manual-cleanup-hook.sh hooks/deploy-hook.sh azureuser@${cs_ip}:~/

# run cert creation/renewal command
ssh -i ~/.ssh/id_rsa_${instance} azureuser@${cs_ip} \
  -oStrictHostKeyChecking=no 'bash -s' < certbot_script.sh "$dry_run" \
  &
certbot_pid=$!

txt_record_reset=0

while true
do

  # see if file is downloadable
  if scp -oStrictHostKeyChecking=no -i ~/.ssh/id_rsa_${instance} azureuser@${cs_ip}:~/DNS_CHALLENGE_REQUEST ~/  &> /dev/null
        then
            echo "Challenge received"
            # consume request
            ssh -i ~/.ssh/id_rsa_${instance} azureuser@${cs_ip} \
              -oStrictHostKeyChecking=no 'rm ~/DNS_CHALLENGE_REQUEST -f' </dev/null

            # delete any existing challenge record
            if [[ $txt_record_reset -eq 0 ]]; then
              az network dns record-set txt delete -g zones-rg -z irfan-k8s.bips.bjsscloud.net -n _acme-challenge -y
              txt_record_reset=1
            fi

            # create txt record
            chall=$(cat ~/DNS_CHALLENGE_REQUEST)

            # set challenge TXT
            az network dns record-set txt add-record -g zones-rg \
              --zone-name irfan-k8s.bips.bjsscloud.net \
              --record-set-name _acme-challenge \
              --value="$chall" # written as so since we may get a challenge beginning with dashes

            # cleanup
            rm ~/DNS_CHALLENGE_REQUEST

            # end challenge by creating file
            ssh -i ~/.ssh/id_rsa_${instance} azureuser@${cs_ip} \
              -oStrictHostKeyChecking=no 'cat > DNS_CHALLENGE_CREATED' </dev/null

  elif scp -oStrictHostKeyChecking=no -i ~/.ssh/id_rsa_${instance} azureuser@${cs_ip}:~/DEPLOYED_CERTIFICATES ~/ &> /dev/null
        then
                    echo "Certs deployed"

                    # consume the cert for completion
                    ssh -i ~/.ssh/id_rsa_${instance} azureuser@${cs_ip} \
                      -oStrictHostKeyChecking=no 'rm ~/DEPLOYED_CERTIFICATES -f' </dev/null
                    break

                    # cleanup
                    rm ~/DEPLOYED_CERTIFICATES


  elif ps -p $certbot_pid > /dev/null
       then
                   echo "Waiting still..."
       else
                   echo "ERROR: Certbot script has terminated somehow. Checks logs on the vm (typically /var/log/letsencrypt/letsencrypt.log)"
                   break # exit 1 also is fine, but exits wsl if being used
      fi
  sleep 5
done

if ! [[ "$dry_run" = true ]]; then

 # move certs to home dir (on remote), and change perms
 ssh -i ~/.ssh/id_rsa_${instance} azureuser@${cs_ip} \
   -oStrictHostKeyChecking=no 'sudo cp -r -L  /etc/letsencrypt/live/kube-certs/ ~/; sudo chown -R azureuser:azureuser kube-certs/'
 # grab certs
 scp -r -oStrictHostKeyChecking=no -i ~/.ssh/id_rsa_${instance} azureuser@${cs_ip}:~/kube-certs ~/

 # create certs for ssl-offloading on Azure
 openssl pkcs12 -passout pass:fj340w0ghaw0fjcnvw03 -export -out certbot-kube-certificate_fullchain.pfx \
 -inkey ~/kube-certs/privkey.pem -in ~/kube-certs/fullchain.pem

fi

# debug
# get certbot PID for killing
# ps -ef | grep certb