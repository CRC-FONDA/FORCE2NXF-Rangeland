while : ; do
    podState=`kubectl get pods -n default | grep "\b$1\b" | awk '{print$3}'`
    echo $1 - $podState
    if [ "$podState" == "Failed" ] || [ "$podState" == "Completed" ] || [ "$podState" == "Unknown" ] ; then
        break
    fi
    sleep 10s
done
