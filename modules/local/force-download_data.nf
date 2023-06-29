nextflow.enable.dsl = 2

process FORCE-DOWNLOAD_DATA {
    container "davidfrantz/force:${params.force_version}"

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
