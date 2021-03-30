nextflow.enable.dsl=2

process generateTileAllowList{

    container 'davidfrantz/force'

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