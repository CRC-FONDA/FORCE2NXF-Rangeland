nextflow.enable.dsl = 2

params.outdata = ""
params.forceVer = "latest"

process PREPROCESS_CONFIG {

    debug TRUE

    tag { data.simpleName }

    container "davidfrantz/force:${params.forceVer}"

    publishDir "${params.outdata}/preprocess_prm", mode: 'copy', pattern: '*.prm', enabled: params.publish

    errorStrategy 'retry'
    maxRetries 5

    input:
    path data
    path cube
    path tile
    path dem
    path wvdb

    output:
    tuple path("*.prm"), path(data), emit: preprocess_config_and_data
    path "*.prm"

    script:

    """
    BASE=\$(basename $data)

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
    sed -i "/^FILE_DEM /c\\FILE_DEM = $dem/global_srtm-aster.vrt" \$PARAM
    sed -i "/^DIR_WVPLUT /c\\DIR_WVPLUT = $wvdb" \$PARAM
    sed -i "/^FILE_TILE /c\\FILE_TILE = $tile" \$PARAM
    sed -i "/^TILE_SIZE /c\\TILE_SIZE = \$TILESIZE" \$PARAM
    sed -i "/^BLOCK_SIZE /c\\BLOCK_SIZE = \$BLOCKSIZE" \$PARAM
    sed -i "/^ORIGIN_LON /c\\ORIGIN_LON = \$ORIGINX" \$PARAM
    sed -i "/^ORIGIN_LAT /c\\ORIGIN_LAT = \$ORIGINY" \$PARAM
    sed -i "/^PROJECTION /c\\PROJECTION = \$CRS" \$PARAM
    sed -i "/^NTHREAD /c\\NTHREAD = $params.useCPU" \$PARAM
    """

}
