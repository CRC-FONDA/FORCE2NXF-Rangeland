kubectl exec ceph-pod -n default --  rm /workdir/output -r
kubectl exec ceph-pod -n default --  rm /workdir/fabian -r
kubectl exec ceph-pod -n default --  rm /workdir/work -r
rm .nextflow -r