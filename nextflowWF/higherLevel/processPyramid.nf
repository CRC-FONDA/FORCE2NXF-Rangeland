nextflow.enable.dsl=2

params.outdata = ""
params.forceVer = "latest"

process processPyramid {

    tag { tile }
    publishDir "${params.outdata}/trend/pyramid/", saveAs: {"${it.substring(12,it.indexOf("."))}/trend/${it.substring(0,11)}/$it"}, mode:'copy'
    container "davidfrantz/force:${params.forceVer}"
    memory { 1500.MB * task.attempt }
    time { 3.minute * task.attempt }
    stageInMode 'copy'

    input:
    tuple val( tile ), path( image )
    
    output:
    path( '**' ), emit: trends

    """
    files="*.tif"
    for file in \$files; do
        force-pyramid \$file
    done
    ls -la
    """

}