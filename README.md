# FORCE on Nextflow: Scalable Analysis of Earth Observation data on Commodity Clusters

## Long-term vegetation dynamics in the Mediterranean

This repository focuses on a specific workflow to re-assess the widespread rangeland degradation in the Mediterranean as reported 20 years ago with limited input data. With the unlimited data access of today, however, we found that total vegetation on the island of Crete, Greece, did rather increase. Yet, we still cannot dispel that vegetation degradation occurred as most increase in vegetation cover was found in the woody vegetation, which potentially represents a degradation process related to the increase of impalatable species.

This repository offers two implementations of the workflow. The [original one](originalWF/force-original.sh) in standalone FORCE and a [ported one](nextflowWF/workflow-dsl2.nf) in FORCE on Nextflow.
We refer to the thematic workflow paper itself: [in preparation](abc), and [our paper](abc) comparing the different implementations. 

<p align="center">
  <img src="DAG_both.jpg" width = "50%">
</p>

*DAGs: The left DAG represents the original implementation in FORCE, right DAG the ported Version in Nextflow. Boxes represent processes and arrows their execution order (left) or mutual dependencies (right). Solid arrows mean that a parent task must finish completely before the dependent task can start, whereas dashed arrows indicate that a dependent task can start as soon as a first data item has been processed by the parent. Solid boxed mark CPU-, dashed boxes IO-bound tasks. Numbers in brackets represent the number of executions.*

Before you start, make sure you installed:
- [FORCE](https://davidfrantz.github.io/code/force/)
- [Nextflow](https://www.nextflow.io/)

*The workflow itself uses [FORCE in Docker](https://force-eo.readthedocs.io/en/latest/setup/docker.html). However, you may use FORCE to download necessary input data.*

To run on Kubernetes:
- [Kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)

To run in Docker:
- [Docker](https://www.docker.com/) 


### Input data
To execute both workflows, the following data are required ([filelist](experiment/filelist.txt)).
Smaller datasets are already included in this repository:
```
cd inputdata
```
#### Landsat observations (download): 
Landsat is a joint NASA/U.S. Geolical Survey satellite mission that provides continuous Earth obersvation data since 1984 at 30m spatial resolution with a temporal revisit frequency of 8-16 days.
Landsast carries multispectral optical instruments that observe the land surface in the visible to shortwave infrared spectrum.
For infos on Landsat, see [here](https://www.usgs.gov/core-science-systems/nli/landsat).
```
cd download
mkdir -p meta
force-level1-csd -u -s "LND04 LND05 LND07" meta
mkdir -p data
force-level1-csd -s "LND04 LND05 LND07" -d "19840101,20061231" -c 0,70 meta/ data/ queue.txt vector/aoi.gpkg
```
*For the original workflow, the file queue (``queue.txt``), needs to hold filenames relative to ``/data/input/``, which is the mountpoint of the ``inputdata`` directory within the Docker container (i.e., ``-v path-to-repo/inputdata:/data/input``);  [see this example](inputdata/download/data/queue.txt).*

#### Water Vapor Database (wvdb):
For atmospheric correction of Landsat data, information on the atmospheric water vapor content is necessary. 
For this, we are using a precompiled water vapor database, see [here](https://zenodo.org/record/4468701) for details.
```
wget -O wvp-global.tar.gz https://zenodo.org/record/4468701/files/wvp-global.tar.gz?download=1
tar -xzf wvp-global.tar.gz --directory wvdb/
rm wvp-global.tar.gz
```

#### Area of interest (vector):
The repository includes a geospatial vector dataset that holds the boundary of Crete, Greece, i.e., our study area.

#### Digital Elevation Model (dem):
A DEM is necessary for topographic correction of Landsat data, and helps to distinguish between cloud shadows and water surfaces. This repository includes a 1 arcsecond DEM covering Crete. The DEM obtained by the Shuttle Radar Topography Mission (SRTM) is primarily used, but filled with the Advanced Spaceborne Thermal Emission and Reflection Radiometer (ASTER) DEM for areas not covered by the SRTM DEM. Data courtesy of the Ministry of Economy, Trade, and Industry (METI) of Japan and the United States National Aeronautics and Space Administration (NASA).

#### Endmember spectra (endmember):
For unmixing satellite-observed reflectance into sub-pixel fractions of land surface components (e.g. photosynthetic active vegetation), endmember spectra are necessary. This repository includes four endmembers (photosynthetic active vegetation, soil, rock, photogrammetric shade) as used in [Hostert et al. 2003](https://www.sciencedirect.com/science/article/abs/pii/S0034425703001457).

#### Datacube definition (grid):
The file ``datacube-definition.prj`` is included in this repository, which stores information about the projection and reference grid of the generated datacube. For details see the [FORCE main paper](https://www.mdpi.com/2072-4292/11/9/1124).

### Execute workflow

#### Original workflow

Adjust input and output pathes to your needs.
You will also need to adapt parallelization parameters in [force-l2ps-param.sh](originalWF/force-l2ps-params.sh#L28-L30) and [force-hlps-param.sh](originalWF/force-hlps-params.sh#L22-L24) to settings that will work on your machine.
```
time originalWF/force-original.sh $PWD/inputdata $PWD/outputdata &> outputdata/stdout.log
```

#### Nextflow workflow
##### Local
```
cd nextflowWF
nextflow run workflow-dsl2.nf \
-c nextflow.config \
--inputdata ../inputdata \
--outdata ../outputdata \
--groupSize 100 \
--forceVer 3.6.5 \
-with-report ../outputdata/report.html
```
##### Kubernetes
1. Setup a user role
```
kubectl -f kubernetes/nextflow-pod-role.yaml
kubectl -f kubernetes/nextflow-role-binding.yaml
```
2. setup a read-write-many storage, in the following: ceph-fs-volume
```
kubectl -f kubernetes/ceph-fs.yaml
```
3. setup a data storage (read-many +), in the following: datasets
 - repeat the last step with a new volume, or upload your data in the created one
4. clone this repository in the root directory of the ceph-fs-volume
```
kubectl -f kubernetes/ceph-pod.yaml
kubectl exec ceph-pod -it -n default -- /bin/bash
cd /workdir
git clone https://github.com/CRC-FONDA/FORCE2NXF-Rangeland.git
```
5. adjust the [nextflow.config](nextflowWF/nextflow.config) according to your needs

6. run Nextflow workflow
```
cd nextflowWF
nextflow kuberun /workdir/FORCE2NXF-Rangeland/nextflowWF/workflow-dsl2.nf \ #cloned repository from git
-c nextflow.config \
-v ceph-fs-volume:/workdir \ # mount the read-write-many volume
-v datasets:/data \ # mount the input data
-profile kubernetesConf \
-queue-size 100 \
--inputdata /data/ \ # root directory where all input data is stored: dem, wvdb, download/data
--outdata /workdir/output \
--groupSize 100 \ # grouping x elements in the merge stage
--forceVer 3.6.5 \
-pod-image fabianlehmann/nextflow:connectionResetFix \ # use Nextflow version with our fixes
-with-report /workdir/output/report.html
```

### Experiments

We performed two types of experiments to investigate whether the ported workflow scales as expected and to detect potential bottlenecks. We first ran the original workflow in its original environment to obtain confirmed results and ensured that all other configurations produce the same results. We subtracted the runtime of the check-result task in the Nextflow workflow from the overall execution time, to achieve comparable results. 

Experiments were repeated three times ([Results](experiment/results)); we report the median of the measured runtimes. We measure wall-clock execution times rounded to minutes. For the distributed setting, we also report on efficiency of task executions, defined as the theoretical time obtained by dividing single node execution time through the number of nodes, divided by the observed runtime. Thus, an efficiency of 1 means perfect scaling, while an efficiency of 0.5, for instance, means that the distributed runtime is only half as good as theoretically possible. We utilized Nextflow version 21.04.0-edge with bugfixes [(Fix extended glob)](https://github.com/nextflow-io/nextflow/pull/2182) [(Fix: Connection-reset crashes the workflow)](https://github.com/nextflow-io/nextflow/pull/2174) and Kubernetes version 1.19.3.

#### Execute

We configured our Kubernetes cluster in a way we described in the previous paragraphs.

```
cd experiment/
bash startOrchestration.sh
```

#### Results

Results like traces, reports, etc. can be found in the [results](experiment/results) directory: 

#### Plots

To evaluate the results, we analyzed the traces with the [Analysis.ipynb](experiment/Analysis.ipynb). The plots generated can be found in [plots/](experiment/plots/).
