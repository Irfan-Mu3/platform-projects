#!/bin/bash

# certbot provides us with the TXT value challenge via the $CERTBOT_VALIDATION variable
echo $CERTBOT_VALIDATION > DNS_CHALLENGE_REQUEST

until [ -f DNS_CHALLENGE_CREATED ]
do
     sleep 5
done
echo "Challenge completed"

# Consume file to complete the challenge (needed so hook can run multiple times)
rm DNS_CHALLENGE_CREATED -f

# Wait for DNS propagation
sleep 30
exit