kubectl exec ceph-pod -n default --  rm /workdir/output -r
kubectl exec ceph-pod -n default --  rm /workdir/$USER -r
kubectl exec ceph-pod -n default --  rm /workdir/work -r
rm .nextflow -r
rm .nextflow.log*
rm .nextflow.pod*