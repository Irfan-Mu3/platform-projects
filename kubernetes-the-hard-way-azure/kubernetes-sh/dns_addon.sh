kubectl apply -f pod-configs/coredns.yml
# need to wait (10s ish)
sleep 15
kubectl get pods -l k8s-app=kube-dns -n kube-system

# debug
#kubectl delete deployment coredns --namespace=kube-system
#kubectl get deployment --namespace=kube-system
#kubectl rollout restart -n kube-system deployment/coredns

#kubectl config set-context --current --namespace=<my-namespace>
#kubectl get serviceAccounts --namespace=default
