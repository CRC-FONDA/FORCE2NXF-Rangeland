
sensors = "LT04,LT05,LE07"
timeRange = "20060420,20060420"
shapeFile = "crete.shp" //later aoi.shp
useCPU = 4

process downloadParams{

    //Has to be downloaded anyways, so we can use it only for wget
    container 'fegyi001/force'

    output:
    file 'input/' into auxiliaryFiles
    file 'input/grid/datacube-definition.prj' into projectionFile

    """
    wget -O parameters https://box.hu-berlin.de/f/eb61444bd97f4c738038/?dl=1
    tar -xzf parameters
    mv EO-01/input/ input/
    """

}

process downloadData{

    container 'fegyi001/force'

    input:
    file parameters from auxiliaryFiles

    output:
    //Folders with data of one single image
    file 'data/*/*' into data
    //Pathes to all these folders
    file 'queue.txt' into queue

    """
    mkdir meta
    force-level1-csd -u -s $sensors meta

    mkdir data
    touch queue.txt

    force-level1-csd -s $sensors -d $timeRange -c 0,70 meta/ data/ queue.txt input/vector/$shapeFile
    """

}

process generateTileAllowList{

    container 'fegyi001/force'

    input:
    file 'ard/datacube-definition.prj' from projectionFile
    file parameters from auxiliaryFiles

    output:
    //Tile allow for this image
    file 'tileAllow.txt' into tileAllow

    """
    force-tile-extent $parameters/vector/$shapeFile ard/ tileAllow.txt
    """

}

process generateAnalysisMask{

    container 'fegyi001/force'

    input:
    file 'mask/datacube-definition.prj' from projectionFile
    file parameters from auxiliaryFiles

    output:
    //Mask for whole region
    file 'mask/' into masks

    """
    force-cube $parameters/vector/$shapeFile mask/ rasterize 30
    """

}

process preprocess{
    
    container 'fegyi001/force'

    input:

    //only process one directory at once
    file data from data.flatten()
    file cube from projectionFile
    file tile from tileAllow
    file parameters from auxiliaryFiles

    output:
    //One BOA image
    file '**BOA.tif' into boaTiles
    //One QAI image
    file '**QAI.tif' into qaiTiles
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
    sed -i "/DIR_LEVEL2 =/c\\DIR_LEVEL2 = level2_ard/" \$PARAM
    sed -i "/DIR_LOG =/c\\DIR_LOG = level2_log/" \$PARAM
    sed -i "/DIR_TEMP =/c\\DIR_TEMP = level2_tmp/" \$PARAM
    sed -i "/FILE_DEM =/c\\FILE_DEM = $parameters/dem/dem.vrt" \$PARAM
    sed -i "/DIR_WVPLUT =/c\\DIR_WVPLUT = $parameters/wvdb/" \$PARAM
    sed -i "/FILE_TILE =/c\\FILE_TILE = $tile" \$PARAM
    sed -i "/TILE_SIZE =/c\\TILE_SIZE = \$TILESIZE" \$PARAM
    sed -i "/BLOCK_SIZE =/c\\BLOCK_SIZE = \$BLOCKSIZE" \$PARAM
    sed -i "/ORIGIN_LON =/c\\ORIGIN_LON = \$ORIGINX" \$PARAM
    sed -i "/ORIGIN_LAT =/c\\ORIGIN_LAT = \$ORIGINY" \$PARAM
    sed -i "/PROJECTION =/c\\PROJECTION = \$CRS" \$PARAM
    sed -i "/NTHREAD =/c\\NTHREAD = $useCPU/" \$PARAM

    # preprocess
    force-l2ps \$FILEPATH \$PARAM > level2_log/\$BASE.log            ### added a properly named logfile, we can make some tests based on this (probably in a different process?)

    #join tile and filename
    results=`find level2_ard/*/*.tif`
    for path in \$results; do
       mv \$path \${path%/*}_\${path##*/}
    done;

    """

}

//Group by tile, date and sensor
boaTiles = boaTiles.flatten().map{ x -> [x.simpleName, x]}.groupTuple()
qaiTiles = qaiTiles.flatten().map{ x -> [x.simpleName, x]}.groupTuple()

//Copy Stream
boaTiles.into{boaTilesToMerge ; boaTilesDone}
qaiTiles.into{qaiTilesToMerge ; qaiTilesDone}

//Find tiles to merge
boaTilesToMerge = boaTilesToMerge.filter{ x -> x[1].size() > 1 }
qaiTilesToMerge = qaiTilesToMerge.filter{ x -> x[1].size() > 1 }

//Find tiles with only one file
boaTilesDone = boaTilesDone.filter{ x -> x[1].size() == 1 }.map{ x -> [x[0], x[1][0]]}
qaiTilesDone = qaiTilesDone.filter{ x -> x[1].size() == 1 }.map{ x -> [x[0], x[1][0]]}

process mergeBOA{

    container 'fegyi001/force'

    input:
    tuple val(id), file('tile/tile?.tif') from boaTilesToMerge
    file cube from projectionFile

    output:
    tuple val(id), file('**.tif') into boaTilesMerged

    """
    merge.sh $id cubic 30
    """

}

process mergeQAI{

    container 'fegyi001/force'

    input:
    tuple val(id), file('tile/tile?.tif') from qaiTilesToMerge
    file cube from projectionFile

    output:
    tuple val(id), file('**.tif') into qaiTilesMerged

    """
    merge.sh $id near 30
    """

}

//Concat merged list with single images, group by tile over time
boaTilesDone = boaTilesDone.concat(boaTilesMerged).map{ x -> [x[0].substring(0,11), x[1]]}.groupTuple()
qaiTilesDone = qaiTilesDone.concat(qaiTilesMerged).map{ x -> [x[0].substring(0,11), x[1]]}.groupTuple()

process processHigherLevel{

    container 'fegyi001/force'

    input:
    tuple val(tile), file("ard/*") from boaTilesDone
    file 'ard/datacube-definition.prj' from projectionFile
    file mask from masks
    file parameters from auxiliaryFiles

    //output:
    //file higherPar into higherPar2

    """

    PARAM=$parameters/parameters/higher-level_trends.prm
    
    #Replace pathes
    sed -i "/DIR_LOWER =/c\\DIR_LOWER = ard/" \$PARAM
    sed -i "/DIR_HIGHER =/c\\DIR_HIGHER = trend/" \$PARAM
    sed -i "/DIR_MASK =/c\\DIR_MASK = mask/" \$PARAM
    sed -i "/FILE_ENDMEM  =/c\\FILE_ENDMEM = $parameters/endmember/hostert-2003.txt" \$PARAM
    sed -i "/FILE_ENDMEM =/c\\FILE_ENDMEM = $parameters/endmember/hostert-2003.txt" \$PARAM

    #Replace Tile to process
    TILE="$tile"
    X=\${TILE:1:4}
    Y=\${TILE:7:11}
    sed -i "s/REPX/\$X/g" \$PARAM
    sed -i "s/REPY/\$Y/g" \$PARAM

    echo \$X
    echo \$Y
    ls ard/
    mkdir trend
    
    force-higher-level \$PARAM
    """

}

// process processMosaic{

//     container 'fegyi001/force'

//     input:
//     //Use higherpar files of all images
//     file 'higher/parameters/*' from higherPar2.flatten().unique{ x -> x.baseName }.buffer( size: Integer.MAX_VALUE, remainder: true ).unique()
//     //Use only one tile allow, should be joined instead.
//     file 'higher/tile.txt' from tileAllow.flatten().buffer( size: Integer.MAX_VALUE, remainder: true )

//     output:
//     file 'higher/mosaic/*.vrt' into masaics

//     """
//     mv higher/tile.txt1 higher/tiles.txt
//     force-mosaic higher
//     """

// }

// process processPyramid{

//     container 'fegyi001/force'

//     input:
//     file mosaic from masaics.flatten()

//     output:
//     stdout result

//     """
//     force-pyramid $mosaic
//     """

// }

// result.view()