kubectl apply -f pod-configs/nginx-test.yml
# wait till ready (13s ish)
sleep 15
kubectl get pods -l app=nginx