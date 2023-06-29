nextflow.enable.dsl = 2

process FORCE_PYRAMID {

    tag { tile }
    container "davidfrantz/force:${params.force_version}"

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
