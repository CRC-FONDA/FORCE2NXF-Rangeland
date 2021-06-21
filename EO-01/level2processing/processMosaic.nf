nextflow.enable.dsl=2

params.outdata = ""
params.forceVer = "latest"

process processMosaic{

    tag { product }
    container "davidfrantz/force:${params.forceVer}"
    memory { 1500.MB * task.attempt }
    publishDir "${params.outdata}/trend/mosaic/$product", mode:'copy'

    input:
    tuple val( product ), path('trend/*')
    path 'trend/datacube-definition.prj'
    output:
    tuple val( product ), path( 'trend/*' ), emit: trendFiles

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