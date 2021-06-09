nextflow.enable.dsl=2

process merge {

    tag { id }

    container 'davidfrantz/force:dev'

    input:
    path ("merge.r")
    tuple val( id ), path( 'input/?/*' )
    path cube

    output:
    tuple val( id ), path( "*.tif" ) emit: tilesMergedNoMeta

    """

    files=`find -L input/ -type f -printf "%f\\n" | sort | uniq`

    for file in \$files
    do
        ls -- */*/\${file}
        onefile=`ls -- */*/\${file} | head -1`
        
        #merge together
        ./merge.r \$file ls -- */*/\${file}

        #apply meta
        force-mdcp \$onefile \$file

    done
        
    """

}