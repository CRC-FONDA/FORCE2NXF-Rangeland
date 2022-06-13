//RUN:
//nextflow run workflow-dsl2.nf -with-report report.html -with-dag flowchart.html --outdata="/home/ubuntu/data/data/outputs/" --inputdata="/home/ubuntu/data/data/inputs/" -bg  > log.log

nextflow.enable.dsl=2

include { downloadAuxiliary } from './downloadAuxiliary'
include { checkResults } from './checkResults'
include { preprocessing } from './preprocessing/preprocessing-workflow'
include { higherLevel } from './higherLevel/higherLevel-workflow'

params.inputdata = ""
params.outdata = ""
println("input data path: '$params.inputdata'")

params.sensors_level2 = "LND04 LND05 LND07"
params.startdate = "1984-01-01"
params.enddate = "2006-12-31"
timeRange = "${params.startdate.replace('-', '')},${params.enddate.replace('-', '')}"
params.resolution = 30
params.useCPU = 2
params.onlyTile = null
params.groupSize = 100
params.forceVer = "3.6.5"
params.skipCheckResults = false

def inRegion = input -> {
    Integer date = input.simpleName.split("_")[3] as Integer
    Integer start = params.startdate.replace('-','') as Integer
    Integer end = params.enddate.replace('-','') as Integer
    return date >= start && date <= end
}

workflow {

    data = Channel.fromPath( "${params.inputdata}/download/data/*/*", type: 'dir') .flatten()
    data = data.flatten().filter{ inRegion(it) }
    dem = file( params.inputdata + '/dem/')
    wvdb = file( params.inputdata + '/wvdb/')
    cubeFile = file( "${params.inputdata}/grid/datacube-definition.prj" )
    aoiFile = file( "${params.inputdata}/vector/aoi.gpkg" )
    endmemberFile = file( "${params.inputdata}/endmember/hostert-2003.txt" )

    preprocessing(data, dem, wvdb, cubeFile, aoiFile)
    
    preprocessedData = preprocessing.out.tilesAndMasks.filter { params.onlyTile ? it[0] == params.onlyTile : true }

    higherLevel( preprocessedData, cubeFile, endmemberFile )

    groupedTrendData = higherLevel.out.trendFiles.map{ it[1] }.flatten().buffer( size: Integer.MAX_VALUE, remainder: true )

    if ( !params.skipCheckResults ) {
        checkResults( groupedTrendData, file( "${moduleDir}/checkData/reference.RData" ) )
    }

}
