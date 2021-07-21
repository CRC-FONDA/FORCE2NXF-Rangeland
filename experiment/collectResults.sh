
mkdir -p ./results/$1/$2/

kubectl cp default/ceph-pod:/workdir/$USER/.nextflow.log ./results/$1/$2/logs.log
kubectl cp default/ceph-pod:/workdir/output/dag.dot ./results/$1/$2/dag.dot
#convert dag to pdf / html
kubectl cp default/ceph-pod:/workdir/output/report.html ./results/$1/$2/report.html
kubectl cp default/ceph-pod:/workdir/output/timeline.html ./results/$1/$2/timeline.html
kubectl cp default/ceph-pod:/workdir/output/trace.txt ./results/$1/$2/trace.txt

kubectl exec ceph-pod -n default -- bash /workdir/FORCE2NXF-Rangeland/EO-01/experiment/collectLogs.sh

kubectl cp default/ceph-pod:/workdir/output/logs.tar.bz2 ./results/$1/$2/logs.tar.bz2

cp .nextflow.* ./results/$1/$2/