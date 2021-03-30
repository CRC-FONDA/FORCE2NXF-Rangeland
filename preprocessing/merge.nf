nextflow.enable.dsl=2

process merge {

    tag { id }

    container 'rocker/geospatial'

    input:
    path ("merge.r")
    tuple val( id ), path( 'tile/tile?.tif' )
    path cube

    output:
    tuple val( id ), path( "${id.substring(12)}.tif" ), path( "tile/tile1.tif" ), emit: tilesMergedNoMeta

    """
    ./merge.r ${id.substring(12)}.tif tile/tile*.tif
    """

}