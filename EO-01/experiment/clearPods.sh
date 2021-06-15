pods=`kubectl get pods -n default | grep "nf-" | awk '{print$1}'`
kubectl delete pod  -n default $pods
pods=`kubectl get pods -n default | grep "Error" | awk '{print$1}'`
kubectl delete pod  -n default $pods
pods=`kubectl get pods -n default | grep "Completed" | awk '{print$1}'`
kubectl delete pod  -n default $pods