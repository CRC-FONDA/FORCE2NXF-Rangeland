nextflow.enable.dsl=2

process applyMeta {

    tag { id }

    container 'davidfrantz/force'

    input:
    tuple val( id ), path( dst ), path( src )

    output:
    tuple val( id ), path( "${dst}" ), emit: tilesMerged

    """
    #To use resume
    mv ${dst} ${dst}_tmp
    cp ${dst}_tmp ${dst}
    force-mdcp $src ${dst}
    """

}