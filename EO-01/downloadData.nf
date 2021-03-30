nextflow.enable.dsl=2

params.downloadData = false
params.sensors_level1 = "LT04,LT05,LE07,S2A"

process downloadData{

    container 'davidfrantz/force'

    when:
    params.downloadData

    input:
    path aoi

    output:
    //Folders with data of one single image
    path 'data/*/*' into data

    """
    mkdir meta
    force-level1-csd -u -s $params.sensors_level1 meta
    mkdir data
    force-level1-csd -s $params.sensors_level1 -d $timeRange -c 0,70 meta/ data/ queue.txt $aoi
    """

}