//RUN:
//nextflow run workflow-dsl2.nf -with-report report.html -with-dag flowchart.html --outdata="/home/ubuntu/data/data/outputs/" --inputdata="/home/ubuntu/data/data/inputs/" -bg  > log.log

nextflow.enable.dsl = 2

include { CHECK_RESULTS } from '../modules/local/check_results'
include { PREPROCESSING } from '../subworkflows/local/preprocessing'
include { HIGHER_LEVEL }  from '../subworkflows/local/higher_level'

println("input data path: '$params.input'")

time_range = "${params.start_date.replace('-', '')},${params.end_date.replace('-', '')}"

def inRegion = input -> {
    Integer date = input.simpleName.split("_")[3] as Integer
    Integer start = params.start_date.replace('-','') as Integer
    Integer end = params.end_date.replace('-','') as Integer
    return date >= start && date <= end
}

workflow RANGELAND {

    data           = Channel.fromPath( "${params.input}/*/*", type: 'dir') .flatten()
    data           = data.flatten().filter{ inRegion(it) }
    dem            = file( "$params.dem")
    wvdb           = file( "$params.wvdb")
    cube_file      = file( "$params.data_cube" )
    aoi_file       = file( "$params.aoi" )
    endmember_file = file( "$params.endmember" )

    PREPROCESSING(data, dem, wvdb, cube_file, aoi_file)

    preprocessed_data = PREPROCESSING.out.tiles_and_masks.filter { params.only_tile ? it[0] == params.only_tile : true }

    HIGHER_LEVEL( preprocessed_data, cube_file, endmember_file )

    grouped_trend_data = HIGHER_LEVEL.out.trend_files.map{ it[1] }.flatten().buffer( size: Integer.MAX_VALUE, remainder: true )

    if ( !params.skip_result_checking ) {
        CHECK_RESULTS( grouped_trend_data, file( "../assets/reference.RData" ) )
    }

}
