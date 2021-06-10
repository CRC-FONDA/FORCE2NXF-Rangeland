nextflow.enable.dsl=2

//includes
include { generateTileAllowList } from './generateTileAllowList'
include { generateAnalysisMask } from './generateAnalysisMask'
include { preprocess } from './preprocess'
include { merge as mergeBOA; merge as mergeQAI } from './merge'
include { applyMeta as applyMetaBOA; applyMeta as applyMetaQAI } from './applyMeta'

//Closure to extract the parent directory of a file
def extractDirectory = { it.parent.toString().substring(it.parent.toString().lastIndexOf('/') + 1 ) }

params.outdata = ""
params.useCPU = 2
params.resolution = 30
//Number of images to merge in one process
params.groupSize = 100

workflow preprocessing {

    take: 
        data
        dem
        wvdb
        cubeFile
        aoiFile

    main:

        generateTileAllowList( aoiFile, cubeFile )
        generateAnalysisMask( aoiFile, cubeFile )
        
        //Group masks by tile
        masks = generateAnalysisMask.out.masks.flatten().map{ x -> [ extractDirectory(x), x ] }
        
        preprocess( data, cubeFile, generateTileAllowList.out.tileAllow, dem, wvdb )

        //Group by tile, date and sensor
        boaTiles = preprocess.out.boaTiles.flatten().map{ [ "${extractDirectory(it)}_${it.simpleName}", it ] }.groupTuple()
        qaiTiles = preprocess.out.qaiTiles.flatten().map{ [ "${extractDirectory(it)}_${it.simpleName}", it ] }.groupTuple()

        //Find tiles to merge
        boaTilesToMerge = boaTiles.filter{ x -> x[1].size() > 1 }
                                .map{ [ it.substring( 0, 11 ), it[1] ] }
                                .groupTuple( remainder : true, size : params.groupSize ).map{ [ it[0], it[1] .flatten() ] }
        qaiTilesToMerge = qaiTiles.filter{ x -> x[1].size() > 1 }
                                .map{ [ it.substring( 0, 11 ), it[1] ] }
                                .groupTuple( remainder : true, size : params.groupSize ).map{ [ it[0], it[1] .flatten() ] }

        //Find tiles with only one file
        boaTilesDone = boaTiles.filter{ x -> x[1].size() == 1 }.map{ x -> [ x[0] .substring( 0, 11 ), x[1][0] ] }
        qaiTilesDone = qaiTiles.filter{ x -> x[1].size() == 1 }.map{ x -> [ x[0] .substring( 0, 11 ), x[1][0] ] }

        mergeBOA( file("${moduleDir}/bin/merge-boa.r"), boaTilesToMerge, cubeFile )
        mergeQAI( file("${moduleDir}/bin/merge-qai.r"), qaiTilesToMerge, cubeFile )

        //Concat merged list with single images, group by tile over time
        boaTiles = mergeBOA.out.tilesMerged
                        .concat( boaTilesDone ).groupTuple()
                        .map { [it[0], it[1].flatten() ] }
        qaiTiles = mergeQAI.out.tilesMerged
                        .concat( qaiTilesDone ).groupTuple()
                        .map { [it[0], it[1].flatten() ] }
    
    emit:
        tilesAndMasks = boaTiles.join( qaiTiles ).join( masks )
        
}