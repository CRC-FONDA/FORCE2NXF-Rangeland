
sensors = "LT04,LT05,LE07"
timeRange = "20060420,20060420"
useCPU = 4

process downloadParams{

    //Has to be downloaded anyways, so we can use it only for wget
    container 'fegyi001/force'

    output:
    file 'input/' into auxiliaryFiles
    file 'input/grid/datacube-definition.prj' into cubeFile
    file 'input/vector/aoi.gpkg' into aoiFile
    file 'input/dem/' into demFiles
    file 'input/wvdb/' into wvdbFiles

    """
    wget -O auxiliary.tar.gz https://box.hu-berlin.de/f/eb61444bd97f4c738038/?dl=1
    tar -xzf auxiliary.tar.gz
    mv EO-01/input/ input/
    """

}

process downloadData{

    container 'fegyi001/force'

    input:
    file aoi from aoiFile

    output:
    //Folders with data of one single image
    file 'data/*/*' into data

    """
    mkdir meta
    force-level1-csd -u -s $sensors meta

    mkdir data
    touch queue.txt

    force-level1-csd -s $sensors -d $timeRange -c 0,70 meta/ data/ queue.txt $aoi
    """

}

process generateTileAllowList{

    container 'fegyi001/force'

    input:
    file aoi from aoiFile
    file 'tmp/datacube-definition.prj' from cubeFile    // is there a way to copy the file to this location without specifying the filename?

    output:
    //Tile allow for this image
    file 'tileAllow.txt' into tileAllow

    """
    force-tile-extent $aoi tmp/ tileAllow.txt
    rm -r tmp
    """

}

process generateAnalysisMask{

    container 'fegyi001/force'

    input:
    file aoi from aoiFile
    file 'mask/datacube-definition.prj' from cubeFile    // is there a way to copy the file to this location without specifying the filename?

    output:
    //Mask for whole region
    file 'mask/' into masks

    """
    force-cube $aoi mask/ rasterize 30
    """

}

process preprocess{
    
    container 'fegyi001/force'

    input:

    //only process one directory at once
    file data from data.flatten()
    file cube from cubeFile
    file tile from tileAllow
    file dem  from demFiles
    file wvdb from wvdbFiles

    output:
    //One BOA image
    file '**BOA.tif' into boaFiles
    //One QAI image
    file '**QAI.tif' into qaiTiles
    stdout preprocessLog

    """
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
    sed -i "/FILE_DEM =/c\\FILE_DEM = $dem/dem.vrt" \$PARAM
    sed -i "/DIR_WVPLUT =/c\\DIR_WVPLUT = $wvdb" \$PARAM
    sed -i "/FILE_TILE =/c\\FILE_TILE = $tile" \$PARAM
    sed -i "/TILE_SIZE =/c\\TILE_SIZE = \$TILESIZE" \$PARAM
    sed -i "/BLOCK_SIZE =/c\\BLOCK_SIZE = \$BLOCKSIZE" \$PARAM
    sed -i "/ORIGIN_LON =/c\\ORIGIN_LON = \$ORIGINX" \$PARAM
    sed -i "/ORIGIN_LAT =/c\\ORIGIN_LAT = \$ORIGINY" \$PARAM
    sed -i "/PROJECTION =/c\\PROJECTION = \$CRS" \$PARAM
    sed -i "/NTHREAD =/c\\NTHREAD = $useCPU/" \$PARAM

    # preprocess
    force-l2ps \$FILEPATH \$PARAM > level2_log\$BASE.log            ### added a properly named logfile, we can make some tests based on this (probably in a different process?)

    results=`find level2_ard/*/*.tif`
    #join tile and filename
    for path in \$results; do
       mv \$path \${path%/*}_\${path##*/}
    done;

    """

}

boaTiles = boaTiles.flatten().map{ x -> [x.simpleName, x]}.groupTuple()

boaTiles.into{boaTilesToMerge ; boaTilesDone}
boaTilesToMerge = boaTilesToMerge.filter{ x -> x[1].size() > 1 }
boaTilesDone = boaTilesDone.filter{ x -> x[1].size() == 1 }.map{ x -> [x[0], x[1][0]]}

process mergeBOA{

    input:
    tuple val(id), file('tile/tile?.tif') from boaTilesToMerge

    output:
    tuple val(id), file('merged.tif') into boaTilesMerged

    """
    mv tile/tile1.tif "$id".tif
    gdal_merge.py -q -o $id".tif" -n $NODATA -a_nodata $NODATA \
    -init $NODATA -of GTiff -co 'INTERLEAVE=BAND' -co 'COMPRESS=LZW' -co 'PREDICTOR=2' \
    -co 'NUM_THREADS=ALL_CPUS' -co 'BIGTIFF=YES' -co "BLOCKXSIZE=$XBLOCK" \
    -co "BLOCKYSIZE=$YBLOCK" $OUT/$TILE/$BASE"_TEMP1.tif" $OUT/$TILE/$BASE"_TEMP2.tif"
    """

}

boaTilesDone = boaTilesDone.concat(boaTilesMerged)

boaTilesDone.view()

// process processCubeQAI{

//     container 'fegyi001/force'

//     input:
//     //Run this methode for all qai images seperately
//     file qai from qaiFiles.flatten()
//     file 'ard/datacube-definition.prj' from cubeFile
//     file tileAllow from tileAllow

//     output:
//     file '**QAI.tif' into qaiTiles

//     """
//     printf '%s\\n' "$qai"
//     force-cube "$qai" ard/ near 30

//     results=`find ard/*/*QAI.tif`

//     for path in \$results; do
//         mv \$path \${path%/*}_\${path##*/}
//     done;
//     """

// }

qaiTiles = qaiTiles.flatten().map{ x -> [x.baseName.substring(0,20), x]}.groupTuple()
qaiTiles.into{qaiTilesToMerge ; qaiTilesDone}
qaiTilesToMerge = qaiTilesToMerge.filter{ x -> x[1].size() > 1 }
qaiTilesDone = qaiTilesDone.filter{ x -> x[1].size() == 1 }.map{ x -> [x[0], x[1][0]]}

process mergeQAI{

    input:
    tuple val(id), file('tile/tile?.tif') from qaiTilesToMerge

    output:
    tuple val(id), file('merged.tif') into qaiTilesMerged

    """
    mv tile/tile1.tif merged.tif
    """

}

qaiTilesDone = qaiTilesDone.concat(qaiTilesMerged)


class Pair {
    Object a
    Object b
    Object c

    Pair(a, b, c) {          
        this.a = a
        this.b = b
        this.c = c
    }
}

//own Pair, otherwise flat would unzip tuples
// higherParsFlat = higherPars.map{x-> x[2].collect{ y -> new Pair(x[0], x[1], y)}}.flatten().map{x -> [x.a, x.b, x.c]}

// process processHigherLevel{

//     container 'fegyi001/force'

//     input:
//     //Process higher level for each filename seperately
//     tuple val(filename), file(ard), file(higherPar) from higherParsFlat
//     file mask from masks
//     file parameters from auxiliaryFiles

//     output:
//     file higherPar into higherPar2

//     """
//     echo $filename
//     mkdir trend
//     force-higher-level $higherPar
//     """

// }

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