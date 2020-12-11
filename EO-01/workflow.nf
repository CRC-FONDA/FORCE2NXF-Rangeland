
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
    #sed -i '1d' tileAllow.txt

    mkdir higherPars

    cp input/parameters/higher-level_trends.prm higher-level_trends.prm
    sed -i "/DIR_LOWER =/c\\DIR_LOWER = ard/" higher-level_trends.prm
    sed -i "/DIR_HIGHER =/c\\DIR_HIGHER = trend/" higher-level_trends.prm
    sed -i "/DIR_MASK =/c\\DIR_MASK = mask/" higher-level_trends.prm
    sed -i "/FILE_ENDMEM  =/c\\FILE_ENDMEM = $parameters/endmember/hostert-2003.txt" higher-level_trends.prm
    sed -i "/FILE_ENDMEM =/c\\FILE_ENDMEM = $parameters/endmember/hostert-2003.txt" higher-level_trends.prm

    while IFS="" read -r t; do
        X=\${t:1:4}
        Y=\${t:7:11}
        cp higher-level_trends.prm higherPars/"\$t.prm"
        sed -i "s/REPX/\$X/g" higherPars/"\$t.prm"
        sed -i "s/REPY/\$Y/g" higherPars/"\$t.prm"
    done < tileAllow.txt
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
    file parameters from auxiliaryFiles
    //only process one directory at once
    file data from data.flatten()
    file 'tileAllow.txt' from tileAllow

    output:
    //One BOA image
    file '**BOA.tif' into boaTiles
    //One QAI image
    file '**QAI.tif' into qaiTiles
    stdout preprocessLog

    """
    FILEPATH=$data
    PARAM=$parameters/parameters/level2.prm
    mkdir level2_wrs
    mkdir level2_log
    mkdir level2_tmp
    touch queue.txt
    sed -i "/DIR_LEVEL2 =/c\\DIR_LEVEL2 = level2_wrs/" \$PARAM
    sed -i "/FILE_QUEUE =/c\\FILE_QUEUE = queue.txt" \$PARAM
    sed -i "/DIR_LOG =/c\\DIR_LOG = level2_log/" \$PARAM
    sed -i "/DIR_TEMP =/c\\DIR_TEMP = level2_tmp/" \$PARAM
    sed -i "/FILE_DEM =/c\\FILE_DEM = input/dem/dem.vrt" \$PARAM
    sed -i "/DIR_WVPLUT =/c\\DIR_WVPLUT = input/wvdb/" \$PARAM
    sed -i "/DO_REPROJ =/c\\DO_REPROJ = TRUE" \$PARAM
    sed -i "/DO_TILE =/c\\DO_TILE = TRUE" \$PARAM
    sed -i "/FILE_TILE =/c\\FILE_TILE = tileAllow.txt" \$PARAM
    sed -i "/NTHREAD =/c\\NTHREAD = $useCPU" \$PARAM
    force-l2ps \$FILEPATH \$PARAM


    results=`find level2_wrs/*/*.tif`
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
//     file 'ard/datacube-definition.prj' from projectionFile
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