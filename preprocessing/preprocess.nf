nextflow.enable.dsl=2

params.outdata = ""
params.useCPU = 2
params.forceVer = "latest"

process preprocess {

    tag { data.simpleName }

    container "davidfrantz/force:${params.forceVer}"

    publishDir "${params.outdata}/preprocess_logs", mode: 'copy', pattern: '**.log'
    publishDir "${params.outdata}/preprocess_prm", mode: 'copy', pattern: '**.prm'

    errorStrategy 'retry'
    maxRetries 5

    cpus params.useCPU
    memory '4500 MB'

    input:
    path data
    path cube
    path tile
    path dem
    path wvdb

    output:
    path 'level2_ard/*/*BOA.tif', emit: boaTiles optional true
    path 'level2_ard/*/*QAI.tif', emit: qaiTiles optional true
    //Logs
    path 'level2_log/*.log'
    path '*.prm'

    """
    FILEPATH=$data
    BASE=\$(basename $data)

    # make directories
    mkdir level2_ard
    mkdir level2_log
    mkdir level2_tmp

    # generate parameterfile from scratch
    force-parameter . LEVEL2 0
    PARAM=\$BASE.prm
    mv *.prm \$PARAM

    # read grid definition
    CRS=\$(sed '1q;d' $cube)
    ORIGINX=\$(sed '2q;d' $cube)
    ORIGINY=\$(sed '3q;d' $cube)
    TILESIZE=\$(sed '6q;d' $cube)
    BLOCKSIZE=\$(sed '7q;d' $cube)

    # set parameters
    sed -i "/^DIR_LEVEL2 /c\\DIR_LEVEL2 = level2_ard/" \$PARAM
    sed -i "/^DIR_LOG /c\\DIR_LOG = level2_log/" \$PARAM
    sed -i "/^DIR_TEMP /c\\DIR_TEMP = level2_tmp/" \$PARAM
    sed -i "/^FILE_DEM /c\\FILE_DEM = $dem/global_srtm-aster.vrt" \$PARAM
    sed -i "/^DIR_WVPLUT /c\\DIR_WVPLUT = $wvdb" \$PARAM
    sed -i "/^FILE_TILE /c\\FILE_TILE = $tile" \$PARAM
    sed -i "/^TILE_SIZE /c\\TILE_SIZE = \$TILESIZE" \$PARAM
    sed -i "/^BLOCK_SIZE /c\\BLOCK_SIZE = \$BLOCKSIZE" \$PARAM
    sed -i "/^ORIGIN_LON /c\\ORIGIN_LON = \$ORIGINX" \$PARAM
    sed -i "/^ORIGIN_LAT /c\\ORIGIN_LAT = \$ORIGINY" \$PARAM
    sed -i "/^PROJECTION /c\\PROJECTION = \$CRS" \$PARAM
    sed -i "/^NTHREAD /c\\NTHREAD = $params.useCPU" \$PARAM

    # preprocess
    force-l2ps \$FILEPATH \$PARAM > level2_log/\$BASE.log            ### added a properly named logfile, we can make some tests based on this (probably in a different process?)
    """

}