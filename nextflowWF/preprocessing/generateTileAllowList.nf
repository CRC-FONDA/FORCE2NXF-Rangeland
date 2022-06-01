nextflow.enable.dsl=2
params.forceVer = "latest"

process generateTileAllowList{

    container "davidfrantz/force:${params.forceVer}"
    memory { 500.MB * task.attempt }
    time { 3.minute * task.attempt }

    input:
    path aoi
    path 'tmp/datacube-definition.prj'

    output:
    //Tile allow for this image
    path 'tileAllow.txt', emit: tileAllow

    """
    force-tile-extent $aoi tmp/ tileAllow.txt
    rm -r tmp
    """

}