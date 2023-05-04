nextflow.enable.dsl = 2
params.forceVer = "latest"

process FORCE_GENERATE_TILE_ALLOW_LIST{

    container "davidfrantz/force:${params.forceVer}"

    input:
    path aoi
    path 'tmp/datacube-definition.prj'

    output:
    //Tile allow for this image
    path 'tile_allow.txt', emit: tile_allow

    """
    force-tile-extent $aoi tmp/ tile_allow.txt
    rm -r tmp
    """

}
