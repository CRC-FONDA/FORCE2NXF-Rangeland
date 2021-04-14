nextflow kuberun /workdir/B5-Workflow-Earth-Observation/EO-01/workflow-dsl2.nf \
-v ceph-fs-volume:/workdir \
-v fonda-datasets:/data \
-profile kubernetesConf \
-queue-size 30 \
--inputdata /data/b5/eo-01/ \
--outdata /workdir/output/ \
-pod-image fabianlehmann/nextflow:fix \
-resume