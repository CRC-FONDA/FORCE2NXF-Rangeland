nextflow.enable.dsl=2

params.forceVer = "latest"

process downloadAuxiliary{

    //Has to be downloaded anyways, so we can use it only for wget
    container "davidfrantz/force:${params.forceVer}"
    memory { 500.MB * task.attempt }

    output:
    path 'input/grid/datacube-definition.prj', emit: cubeFile
    path 'input/vector/aoi.gpkg', emit: aoiFile
    path 'input/endmember/hostert-2003.txt', emit: endmemberFile

    """
    wget -O auxiliary.tar.gz https://box.hu-berlin.de/f/eb61444bd97f4c738038/?dl=1
    tar -xzf auxiliary.tar.gz
    mv EO-01/input/ input/
    """

}