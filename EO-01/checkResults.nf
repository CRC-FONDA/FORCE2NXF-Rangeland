nextflow.enable.dsl=2

process checkResults {

    container 'rocker/geospatial'
    memory '12000 MB'

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