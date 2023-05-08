nextflow.enable.dsl = 2

params.sensors_level1 = "LT04,LT05,LE07,S2A"
params.forceVer = "latest"

process FORCE-DOWNLOAD_DATA {

    container "davidfrantz/force:${params.forceVer}"

    input:
    path aoi
    val time_range

    output:
    //Folders with data of one single image
    path 'data/*/*', emit: imagery_data

    """
    mkdir meta
    force-level1-csd -u -s $params.sensors_level1 meta
    mkdir data
    force-level1-csd -s $params.sensors_level1 -d $time_range -c 0,70 meta/ data/ queue.txt $aoi
    """

}
