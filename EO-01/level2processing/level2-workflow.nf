nextflow.enable.dsl=2

//inputs
include { processHigherLevel } from './processHigherLevel.nf'
include { processMosaic } from './processMosaic.nf'
include { processPyramid } from './processPyramid.nf'

params.outdata = ""
params.sensors_level2 = "LND04 LND05 LND07"
params.startdate = "1984-01-01"
params.enddate = "2006-12-31"
params.resolution = 30
params.useCPU = 2
params.onlyTile = null

workflow level2processing {

    take: 
        tilesAndMasks
        cubeFile
        endmemberFile

    main:
        processHigherLevel( tilesAndMasks, cubeFile , endmemberFile )

        trendFiles = processHigherLevel.out.trendFiles.flatten().map{ x -> [ x.simpleName.substring(12), x ] }

        trendFilesMosaic = trendFiles.groupTuple()
        
        processMosaic( trendFilesMosaic, cubeFile )

        processPyramid( trendFiles.filter { it[1].name.endsWith('.tif')  } )

    emit:
        trendFiles = processMosaic.out.trendFiles

}