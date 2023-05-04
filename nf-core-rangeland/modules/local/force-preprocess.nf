nextflow.enable.dsl=2

params.outdata = ""
params.forceVer = "latest"

process FORCE_PREPROCESS {
    tag { data.simpleName }

    container "davidfrantz/force:${params.forceVer}"

    publishDir "${params.outdata}/preprocess_logs", mode: 'copy', pattern: '*.log', enabled: params.publish


    errorStrategy 'retry'
    maxRetries 5

    input:
    tuple path(conf), path(data)

    output:
    path "*BOA.tif", emit: boa_tiles optional true
    path "*QAI.tif", emit: qai_tiles optional true
    path "*.log"

    """
    PARAM=$conf

    # make directories for force output
    mkdir level2_ard
    mkdir level2_log
    mkdir level2_tmp


    # set output directories in parameter file
    sed -i "/^DIR_LEVEL2 /c\\DIR_LEVEL2 = level2_ard/" \$PARAM
    sed -i "/^DIR_LOG /c\\DIR_LOG = level2_log/" \$PARAM
    sed -i "/^DIR_TEMP /c\\DIR_TEMP = level2_tmp/" \$PARAM

    FILEPATH=$data
    BASE=\$(basename $data)
    force-l2ps \$FILEPATH \$PARAM > level2_log\$BASE.log
    """


}
