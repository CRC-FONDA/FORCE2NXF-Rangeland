nextflow.enanle.dsl = 2

params.forceVer = "latest"
params.resolution = 30
params.useCPU = 2
params.sensors_level2 = "LND04 LND05 LND07"
params.startdate = "1984-01-01"
params.enddate = "2006-12-31"
params.onlyTile = null


process HIGHER_LEVEL_CONFIG {

    container "davidfrantz/force:${params.forceVer}"
    tag { tile }

    input:
    tuple val( tile ), path( "ard/${tile}/*" ), path( "ard/${tile}/*" ), path( "mask/${tile}/aoi.tif" )
    path 'ard/datacube-definition.prj'
    path endmember

    output:
    path( "higher_level_force_conf/trend_${tile}.prm" ), emit: higher_level_configs

    """
    # generate parameterfile from scratch
    force-parameter . TSA 0
    PARAM=higher_level_force_conf/trend_"$tile".prm
    mv *.prm \$PARAM

    # set parameters

    #Replace pathes
    sed -i "/^DIR_LOWER /c\\DIR_LOWER = ard/" \$PARAM
    sed -i "/^DIR_HIGHER /c\\DIR_HIGHER = trend/" \$PARAM
    sed -i "/^DIR_MASK /c\\DIR_MASK = mask/" \$PARAM
    sed -i "/^BASE_MASK /c\\BASE_MASK = aoi.tif" \$PARAM
    sed -i "/^FILE_ENDMEM /c\\FILE_ENDMEM = $endmember" \$PARAM

    # threading
    sed -i "/^NTHREAD_READ /c\\NTHREAD_READ = 1" \$PARAM              # might need some modification
    sed -i "/^NTHREAD_COMPUTE /c\\NTHREAD_COMPUTE = $params.useCPU" \$PARAM  # might need some modification
    sed -i "/^NTHREAD_WRITE /c\\NTHREAD_WRITE = 1" \$PARAM            # might need some modification


    # replace Tile to process
    TILE="$tile"
    X=\${TILE:1:4}
    Y=\${TILE:7:11}
    sed -i "/^X_TILE_RANGE /c\\X_TILE_RANGE = \$X \$X" \$PARAM
    sed -i "/^Y_TILE_RANGE /c\\Y_TILE_RANGE = \$Y \$Y" \$PARAM

    # resolution
    sed -i "/^RESOLUTION /c\\RESOLUTION = $params.resolution" \$PARAM


    # sensors
    sed -i "/^SENSORS /c\\SENSORS = $params.sensors_level2" \$PARAM


    # date range
    sed -i "/^DATE_RANGE /c\\DATE_RANGE = $params.startdate $params.enddate" \$PARAM


    # spectral index
    sed -i "/^INDEX /c\\INDEX = SMA${params.onlyTile ? ' NDVI BLUE GREEN RED NIR SWIR1 SWIR2' : ''}" \$PARAM
    ${ params.onlyTile ? 'sed -i "/^OUTPUT_TSS /c\\OUTPUT_TSS = TRUE" \$PARAM' : ''}

    # interpolation
    sed -i "/^INT_DAY /c\\INT_DAY = 8" \$PARAM
    sed -i "/^OUTPUT_TSI /c\\OUTPUT_TSI = TRUE" \$PARAM

    # polar metrics
    sed -i "/^POL /c\\POL = VPS VBL VSA" \$PARAM
    sed -i "/^OUTPUT_POL /c\\OUTPUT_POL = TRUE" \$PARAM
    sed -i "/^OUTPUT_TRO /c\\OUTPUT_TRO = TRUE" \$PARAM
    sed -i "/^OUTPUT_CAO /c\\OUTPUT_CAO = TRUE" \$PARAM
    """

}

