echo go
nextflow kuberun /workdir/B5-Workflow-Earth-Observation/EO-01/workflow-dsl2.nf \
-v ceph-fs-volume:/workdir \
-v fonda-datasets:/data \
-profile kubernetesConf \
-queue-size 100 \
--inputdata /data/b5/eo-01 \
--outdata /workdir/output \
--groupSize 100 \
--forceVer 3.6.5 \
-pod-image fabianlehmann/nextflow:connectionResetFix \
-with-dag /workdir/output/dag.dot \
-with-report /workdir/output/report.html \
-with-timeline /workdir/output/timeline.html \
-with-trace /workdir/output/trace.txt \
-name $1