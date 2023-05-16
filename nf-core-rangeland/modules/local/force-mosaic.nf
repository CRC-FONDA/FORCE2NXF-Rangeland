nextflow.enable.dsl = 2

process FORCE_MOSAIC{

    tag { product }
    container "davidfrantz/force:${params.force_version}"

    input:
    tuple val( product ), path('trend/*')
    path 'trend/datacube-definition.prj'
    output:
    tuple val( product ), path( 'trend/*' ), emit: trend_files

    """
    #Move files from trend/<Tile>_<Filename> to trend/<Tile>/<Filename>
    results=`find trend/*.tif*`
    for path in \$results; do
        mkdir -p \${path%_$product*}
        mv \$path \${path%_$product*}/${product}.\${path#*.}
    done;

    force-mosaic trend/
    """

}
