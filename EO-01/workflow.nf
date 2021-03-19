//RUN:
//nextflow run workflow.nf -with-docker ubuntu -resume -with-report report.html -with-dag flowchart.html -bg > log.log

data = Channel.of(file('download/data/*/*', type: 'dir') ) .flatten()

sensors_level1 = "LT04,LT05,LE07,S2A"
sensors_level2 = "LND04 LND05 LND07"

startdate = "1984-01-01"
enddate = "2006-12-31"
timeRange = "${startdate.replace('-', '')},${enddate.replace('-', '')}"

resolution = 30
useCPU = 2

onlyTile = null

//Closure to extract the parent directory of a file
def extractDirectory = { it.parent.toString().substring(it.parent.toString().lastIndexOf('/') + 1 ) }

def inRegion = input -> {
    Integer date = input.simpleName.split("_")[3] as Integer
    Integer start = startdate.replace('-','') as Integer
    Integer end = enddate.replace('-','') as Integer
    return date >= start && date <= end
}

process downloadAuxiliary{

    //Has to be downloaded anyways, so we can use it only for wget
    container 'davidfrantz/force'

    output:
    file 'input/grid/datacube-definition.prj' into cubeFile
    file 'input/vector/aoi.gpkg' into aoiFile
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

    publishDir 'preprocess_logs', mode: 'copy', pattern: '**.log'
    publishDir 'preprocess_prm', mode: 'copy', pattern: '**.prm'

    errorStrategy 'retry'
    maxRetries 5

    cpus useCPU
    memory '4 GB'

    input:

    //only process one directory at once
    file data from data.flatten().filter{ inRegion(it) }
    file cube from cubeFile
    file tile from tileAllow
    file dem  from file('dem/')
    file wvdb from wvdbFiles

    output:
    //One BOA image
    file 'level2_ard/*/*BOA.tif' optional true into boaTiles
    //One QAI image
    file 'level2_ard/*/*QAI.tif' optional true into qaiTiles
    //Logs
    file 'level2_log/*.log'
    file '*.prm'

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
    sed -i "/^NTHREAD /c\\NTHREAD = $useCPU" \$PARAM

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

    container 'rocker/geospatial'

    input:
    tuple val( id ), file( 'tile/tile?.tif' ) from boaTilesToMerge
    file cube from cubeFile

    output:
    tuple val( id ), file( "${id.substring(12)}.tif" ), file( "tile/tile1.tif" ) into boaTilesMergedNoMeta

    """
    merge-boa.r ${id.substring(12)}.tif tile/tile*.tif
    """

}

process applyMetaBOA{

    tag { id }

    container 'davidfrantz/force'

    input:
    tuple val( id ), file( dst ), file( src ) from boaTilesMergedNoMeta

    output:
    tuple val( id ), file( "${dst}" ) into boaTilesMerged

    """
    #To use resume
    mv ${dst} ${dst}_tmp
    cp ${dst}_tmp ${dst}
    force-mdcp $src ${dst}
    """

}

process mergeQAI{

    tag { id }

    container 'rocker/geospatial'

    input:
    tuple val( id ), file( 'tile/tile?.tif' ) from qaiTilesToMerge
    file cube from cubeFile

    output:
    tuple val( id ), file( "${id.substring(12)}.tif" ), file( "tile/tile1.tif" ) into qaiTilesMergedNoMeta

    """
    merge-qai.r ${id.substring(12)}.tif tile/tile*.tif
    """

}

process applyMetaQAI{

    tag { id }

    container 'davidfrantz/force'

    input:
    tuple val( id ), file( dst ), file( src ) from qaiTilesMergedNoMeta

    output:
    tuple val( id ), file( "${dst}" ) into qaiTilesMerged

    """
    #To use resume
    mv ${dst} ${dst}_tmp
    cp ${dst}_tmp ${dst}
    force-mdcp $src ${dst}
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
    memory '6500 MB'

    input:
    tuple val( tile ), file( "ard/${tile}/*" ), file( "ard/${tile}/*" ), file( "mask/${tile}/aoi.tif" ) from boaTilesDoneAndMerged.join( qaiTilesDoneAndMerged ).join( masks ).filter { onlyTile ? it[0] == onlyTile : true }
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
    sed -i "/^INDEX /c\\INDEX = SMA${onlyTile ? ' NDVI BLUE GREEN RED NIR SWIR1 SWIR2' : ''}" \$PARAM
    ${ onlyTile ? 'sed -i "/^OUTPUT_TSS /c\\OUTPUT_TSS = TRUE" \$PARAM' : ''}
    
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

trendFiles.flatten().map{ x -> [ x.simpleName.substring(12), x ] }.into { trendFilesMosaic ; trendFilesPyramid }

trendFilesMosaic = trendFilesMosaic.groupTuple()

process processMosaic{

    tag { product }
    container 'davidfrantz/force'
    publishDir "trend/mosaic/$product", mode:'copy'

    input:
    tuple val( product ), file('trend/*') from trendFilesMosaic
    file 'trend/datacube-definition.prj' from cubeFile
    output:
    tuple val( product ), file( 'trend/*' ) into trendFilesCheck

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
    publishDir "trend/pyramid/$product/trend/${image.simpleName.substring(0,11)}/", mode:'copy'
    container 'davidfrantz/force'
    memory '3000 MB'
    stageInMode 'copy'

    input:
    tuple val( product ), file( image ) from trendFilesPyramid.filter { it[1].name.endsWith('.tif')  }
    
    output:
    file( '**' ) into trends

    """
    force-pyramid $image
    """

}

process checkResults {

    container 'rocker/geospatial'

    input:
    file{ "trend/?/*" } from trendFilesCheck.map{ it[1] }.flatten().buffer( size: Integer.MAX_VALUE, remainder: true )
    file( reference ) from file( "test/reference.RData" )
 
    """
    files=`find ./trend/ -maxdepth 1 -mindepth 1 -type d`
    for path in \$files; do
        mkdir -p trend/\$(ls \$path)
        cp \$path/*/* trend/\$(ls \$path)/
        rm \$path -r
    done;
    test.R trend/mosaic $reference log.log
    """

}