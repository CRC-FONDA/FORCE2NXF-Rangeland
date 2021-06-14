nextflow.enable.dsl=2

params.outdata = ""
params.forceVer = "latest"

process processPyramid{

    tag { product }
    publishDir "${params.outdata}/trend/pyramid/$product/trend/${image.simpleName.substring(0,11)}/", mode:'copy'
    container "davidfrantz/force:${params.forceVer}"
    memory '1500 MB'
    stageInMode 'copy'

    input:
    tuple val( product ), path( image )
    
    output:
    path( '**' ), emit: trends

    """
    force-pyramid $image
    """

}