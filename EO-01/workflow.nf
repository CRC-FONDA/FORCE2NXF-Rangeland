
sensors = "LT04,LT05,LE07"
timeRange = "20061201,20061231"
shapeFile = "crete.shp"
//TODO export input/vector/**, determine name automatically

process downloadParams{

    //Has to be downloaded anyways, so we can use it only for wget
    container 'fegyi001/force'

    output:
    file 'input/' into parameterFiles
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
    file parameters from parameterFiles

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

process preprocess{
    
    container 'fegyi001/force'

    input:
    file parameters from parameterFiles
    //only process one directory at once
    file data from data.flatten()

    output:
    //One BOA image
    file '**BOA.tif' into boaFiles
    //One QAI image
    file '**QAI.tif' into qaiFiles

    """
    FILEPATH=$data
    PARAM=$parameters/parameters/level2.prm
    mkdir level2_wrs
    mkdir level2_log
    mkdir level2_tmp
    sed -i "/DIR_LEVEL2 =/c\\DIR_LEVEL2 = level2_wrs/" \$PARAM
    sed -i "/FILE_QUEUE =/c\\FILE_QUEUE = queue.txt" \$PARAM
    sed -i "/DIR_LOG =/c\\DIR_LOG = level2_log/" \$PARAM
    sed -i "/DIR_TEMP =/c\\DIR_TEMP = level2_tmp/" \$PARAM
    sed -i "/FILE_DEM =/c\\FILE_DEM = input/dem/dem.vrt" \$PARAM
    sed -i "/DIR_WVPLUT =/c\\DIR_WVPLUT = input/wvdb/" \$PARAM
    force-l2ps \$FILEPATH \$PARAM
    """


}

process processCubeBOA{

    container 'fegyi001/force'

    input:
    //Run this methode for all boa images seperately
    file boa from boaFiles.flatten()
    file 'ard/datacube-definition.prj' from projectionFile

    """
    printf '%s\\n' "$boa"
    force-cube "$boa" ard/ cubic 30
    """

}

process processCubeQAI{

    container 'fegyi001/force'

    input:
    //Run this methode for all qai images seperately
    file qai from qaiFiles.flatten()
    file 'ard/datacube-definition.prj' from projectionFile

    output:
    //Two outputs, to use it twice
    tuple val(qai.baseName), file('ard/') into ardFiles1
    tuple val(qai.baseName), file('ard/') into ardFiles2

    """
    printf '%s\\n' "$qai"
    force-cube "$qai" ard/ near 30
    """

}

process generateAnalysisMask{

    container 'fegyi001/force'

    input:
    file 'mask/datacube-definition.prj' from projectionFile
    file parameters from parameterFiles

    output:
    //Mask for whole region
    file 'mask/' into masks

    """
    force-cube $parameters/vector/$shapeFile mask/ rasterize 30
    """

}

process generateTileAllowList{

    container 'fegyi001/force'

    input:
    tuple val(filename), file(ard) from ardFiles1
    file parameters from parameterFiles

    output:
    //Combination of filename, ARD images of this file and higher pars
    tuple val(filename), file(ard), file('higherPars/*.prm') into higherPars
    //Tile allow for this image
    file 'tileAllow.txt' into tileAllow

    """
    echo $filename
    force-tile-extent $parameters/vector/$shapeFile ard/ tileAllow.txt
    sed -i '1d' tileAllow.txt

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
higherParsFlat = higherPars.map{x-> x[2].collect{ y -> new Pair(x[0], x[1], y)}}.flatten().map{x -> [x.a, x.b, x.c]}

process processHigherLevel{

    container 'fegyi001/force'

    input:
    //Process higher level for each filename seperately
    tuple val(filename), file(ard), file(higherPar) from higherParsFlat
    file mask from masks
    file parameters from parameterFiles

    output:
    file higherPar into higherPar2

    """
    echo $filename
    mkdir trend
    force-higher-level $higherPar
    """

}

process processMosaic{

    container 'fegyi001/force'

    input:
    //Use higherpar files of all images
    file 'higher/parameters/*' from higherPar2.flatten().unique{ x -> x.baseName }.buffer( size: Integer.MAX_VALUE, remainder: true ).unique()
    //Use only one tile allow, should be joined instead.
    file 'higher/tile.txt' from tileAllow.flatten().buffer( size: Integer.MAX_VALUE, remainder: true )

    output:
    file 'higher/mosaic/*.vrt' into masaics

    """
    mv higher/tile.txt1 higher/tiles.txt
    force-mosaic higher
    """

}

process processPyramid{

    container 'fegyi001/force'

    input:
    file mosaic from masaics.flatten()

    output:
    stdout result

    """
    force-pyramid $mosaic
    """

}

result.view()