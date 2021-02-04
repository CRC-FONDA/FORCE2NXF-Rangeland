
//If the data should be downloaded
params.downloadData = false

//Download automatically, if not yet done
Channel.of(file('download/data/*/*', type: 'dir')).flatten().ifEmpty{ params.downloadData = true }

sensors_level1 = "LT04,LT05,LE07,S2A"
sensors_level2 = "LND04 LND05 LND07"

startdate = "1984-01-01"
enddate = "2006-12-31"
timeRange = "${startdate.replace('-', '')},${enddate.replace('-', '')}"

resolution = 30
useCPU = 2

//Closure to extract the parent directory of a file
def extractDirectory = { it.parent.toString().substring(it.parent.toString().lastIndexOf('/') + 1 ) }

process downloadAuxiliary{

    //Has to be downloaded anyways, so we can use it only for wget
    container 'davidfrantz/force'

    output:
    file 'input/' into auxiliaryFiles
    file 'input/grid/datacube-definition.prj' into cubeFile
    file 'input/vector/aoi.gpkg' into aoiFile
    file 'input/dem/' into demFiles
    file 'input/endmember/hostert-2003.txt' into endmemberFile

    """
    wget -O auxiliary.tar.gz https://box.hu-berlin.de/f/eb61444bd97f4c738038/?dl=1
    tar -xzf auxiliary.tar.gz
    mv EO-01/input/ input/
    """

}

process downloadWaterVapor{

    //Has to be downloaded anyways, so we can use it only for wget
    container 'davidfrantz/force'

    output:
    file 'wvdb/' into wvdbFiles

    """
    wget -O wvp-global.tar.gz https://zenodo.org/record/4468701/files/wvp-global.tar.gz?download=1
    mkdir wvdb
    tar -xzf wvp-global.tar.gz --directory wvdb/
    """

}

process downloadData{

    container 'davidfrantz/force'

    when:
    params.downloadData

    input:
    //import the data
    file data from Channel.from( file('download/data/', type: 'dir') )
    file meta from Channel.from( file('download/meta/', type: 'dir') )
    file aoi from aoiFile

    output:
    //Folders with data of one single image
    file 'data/*/*' into data

    """
    #check if meta data was just downloaded
    if [ ! -f "meta/metadata_landsat.csv" ] || [ ! -f "meta/metadata_sentinel2.csv" ]; then
        echo "Download meta data."
        force-level1-csd -u -s $sensors_level1 meta
    fi
    force-level1-csd -s $sensors_level1 -d $timeRange -c 0,70 meta/ data/ queue.txt $aoi
    """

}

data = data.mix ( Channel.of(file('download/data/*/*', type: 'dir') ) .flatten() ). unique { it.simpleName }



process generateTileAllowList{

    container 'davidfrantz/force'

    input:
    file aoi from aoiFile
    file 'tmp/datacube-definition.prj' from cubeFile

    output:
    //Tile allow for this image
    file 'tileAllow.txt' into tileAllow

    """
    force-tile-extent $aoi tmp/ tileAllow.txt
    rm -r tmp
    """

}

process generateAnalysisMask{

    container 'davidfrantz/force'

    input:
    file aoi from aoiFile
    file 'mask/datacube-definition.prj' from cubeFile

    output:
    //Mask for whole region
    file 'mask/*/*.tif' into masks

    """
    force-cube $aoi mask/ rasterize $resolution
    """

}

//Group masks by tile
masks = masks.flatten().map{ x -> [ extractDirectory(x), x ] }

process preprocess{

    tag { data.simpleName }

    container 'davidfrantz/force'

    errorStrategy 'retry'
    maxRetries 5

    cpus useCPU
    memory '4 GB'

    input:

    //only process one directory at once
    file data from data.flatten()
    file cube from cubeFile
    file tile from tileAllow
    file dem  from demFiles
    file wvdb from wvdbFiles

    output:
    //One BOA image
    file 'level2_ard/*/*BOA.tif' optional true into boaTiles
    //One QAI image
    file 'level2_ard/*/*QAI.tif' optional true into qaiTiles
    stdout preprocessLog

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
    sed -i "/^FILE_DEM /c\\FILE_DEM = $dem/dem.vrt" \$PARAM
    sed -i "/^DIR_WVPLUT /c\\DIR_WVPLUT = $wvdb" \$PARAM
    sed -i "/^FILE_TILE /c\\FILE_TILE = $tile" \$PARAM
    sed -i "/^TILE_SIZE /c\\TILE_SIZE = \$TILESIZE" \$PARAM
    sed -i "/^BLOCK_SIZE /c\\BLOCK_SIZE = \$BLOCKSIZE" \$PARAM
    sed -i "/^ORIGIN_LON /c\\ORIGIN_LON = \$ORIGINX" \$PARAM
    sed -i "/^ORIGIN_LAT /c\\ORIGIN_LAT = \$ORIGINY" \$PARAM
    sed -i "/^PROJECTION /c\\PROJECTION = \$CRS" \$PARAM
    sed -i "/^NTHREAD /c\\NTHREAD = $useCPU/" \$PARAM

    # preprocess
    force-l2ps \$FILEPATH \$PARAM > level2_log/\$BASE.log            ### added a properly named logfile, we can make some tests based on this (probably in a different process?)
    """

}

//Group by tile, date and sensor
boaTiles = boaTiles.flatten().map{ x -> [ "${extractDirectory(x)}_${x.simpleName}", x ] }.groupTuple()
qaiTiles = qaiTiles.flatten().map{ x -> [ "${extractDirectory(x)}_${x.simpleName}", x ] }.groupTuple()

//Copy Stream
boaTiles.into{ boaTilesToMerge ; boaTilesDone }
qaiTiles.into{ qaiTilesToMerge ; qaiTilesDone }

//Find tiles to merge
boaTilesToMerge = boaTilesToMerge.filter{ x -> x[1].size() > 1 }
qaiTilesToMerge = qaiTilesToMerge.filter{ x -> x[1].size() > 1 }

//Find tiles with only one file
boaTilesDone = boaTilesDone.filter{ x -> x[1].size() == 1 }.map{ x -> [ x[0], x[1][0] ] }
qaiTilesDone = qaiTilesDone.filter{ x -> x[1].size() == 1 }.map{ x -> [ x[0], x[1][0] ] }

process mergeBOA{

    tag { id }

    container 'davidfrantz/force'

    input:
    tuple val( id ), file( 'tile/tile?.tif' ) from boaTilesToMerge
    file cube from cubeFile

    output:
    tuple val( id ), file( '**.tif' ) into boaTilesMerged

    """
    merge.sh ${id.substring(12)} $cube $resolution
    """

}

process mergeQAI{

    tag { id }

    container 'davidfrantz/force'

    input:
    tuple val( id ), file( 'tile/tile?.tif' ) from qaiTilesToMerge
    file cube from cubeFile

    output:
    tuple val( id ), file( '**.tif' ) into qaiTilesMerged

    """
    merge.sh ${id.substring(12)} $cube $resolution
    """

}

//Concat merged list with single images, group by tile over time
boaTilesDoneAndMerged = boaTilesMerged.concat(boaTilesDone).map{ x -> [ x[0].substring(0,11), x[1] ] }.groupTuple()
qaiTilesDoneAndMerged = qaiTilesMerged.concat(qaiTilesDone).map{ x -> [ x[0].substring(0,11), x[1] ] }.groupTuple()

process processHigherLevel{

    container 'davidfrantz/force'
    tag { tile }
    
    errorStrategy 'retry'
    maxRetries 5

    cpus useCPU
    memory '4500 MB'

    input:
    tuple val( tile ), file( "ard/${tile}/*" ), file( "ard/${tile}/*" ), file( "mask/${tile}/aoi.tif" ) from boaTilesDoneAndMerged.join( qaiTilesDoneAndMerged ).join( masks )
    file 'ard/datacube-definition.prj' from cubeFile
    file endmember from endmemberFile

    output:
    file 'trend/*.tif*' into trendFiles


    """   
    # generate parameterfile from scratch
    force-parameter . TSA 0
    PARAM=trend_"$tile".prm
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
    sed -i "/^NTHREAD_COMPUTE /c\\NTHREAD_COMPUTE = $useCPU" \$PARAM  # might need some modification
    sed -i "/^NTHREAD_WRITE /c\\NTHREAD_WRITE = 1" \$PARAM            # might need some modification

    # replace Tile to process
    TILE="$tile"
    X=\${TILE:1:4}
    Y=\${TILE:7:11}
    sed -i "/^X_TILE_RANGE /c\\X_TILE_RANGE = \$X \$X" \$PARAM
    sed -i "/^Y_TILE_RANGE /c\\Y_TILE_RANGE = \$Y \$Y" \$PARAM

    # resolution
    sed -i "/^RESOLUTION /c\\RESOLUTION = $resolution" \$PARAM

    # sensors
    sed -i "/^SENSORS /c\\SENSORS = $sensors_level2" \$PARAM

    # date range
    sed -i "/^DATE_RANGE /c\\DATE_RANGE = $startdate $enddate" \$PARAM

    # spectral index
    sed -i "/^INDEX /c\\INDEX = SMA" \$PARAM
    
    # interpolation
    sed -i "/^INT_DAY /c\\INT_DAY = 8" \$PARAM
    sed -i "/^OUTPUT_TSI /c\\OUTPUT_TSI = TRUE" \$PARAM

    # polar metrics
    sed -i "/^POL /c\\POL = VPS VBL VSA" \$PARAM
    sed -i "/^OUTPUT_POL /c\\OUTPUT_POL = TRUE" \$PARAM
    sed -i "/^OUTPUT_TRO /c\\OUTPUT_TRO = TRUE" \$PARAM
    sed -i "/^OUTPUT_CAO /c\\OUTPUT_CAO = TRUE" \$PARAM

    echo \$X
    echo \$Y
    ls ard/
    mkdir trend
    
    force-higher-level \$PARAM

    #Rename files: /trend/<Tile>/<Filename> to <Tile>_<Filename>, otherwise we can not reextract the tile name later
    results=`find trend -name '*.tif*'`
    for path in \$results; do
       mv \$path \${path%/*}_\${path##*/}
    done;
    """

}

trendFiles = trendFiles.flatten().map{ x -> [ x.simpleName.substring(12), x ] }.groupTuple()

process processMosaic{

    tag { product }
    container 'davidfrantz/force'

    input:
    tuple val( product ), file('trend/*') from trendFiles
    file 'trend/datacube-definition.prj' from cubeFile
    output:
    tuple val( product ), file( 'trend/*' ) into trendFiles2

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

process processPyramid{

    tag { product }
    publishDir "trend", mode:'copy'
    container 'davidfrantz/force'

    input:
    tuple val( product ), file( 'trend/*' ) from trendFiles2
    file 'trend/datacube-definition.prj' from cubeFile
    
    output:
    file( '**' ) into trends

    """
    #trick to find it by publish dir
    touch trend

    force-pyramid trend/mosaic/*
    """

}