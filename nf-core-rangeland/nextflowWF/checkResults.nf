nextflow.enable.dsl=2

process checkResults {

    //Only retry if OutOfMemoryError
    errorStrategy = { task.exitStatus == 143 ? 'retry' : 'ignore' }
    container 'rocker/geospatial:3.6.3'

    input:
    file{ "trend/?/*" }
    file( reference )
 
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