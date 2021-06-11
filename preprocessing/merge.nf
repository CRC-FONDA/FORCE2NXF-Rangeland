nextflow.enable.dsl=2

process merge {

    tag { id }

    container 'davidfrantz/force:dev'
    memory '2000 MB'

    input:
    path ("merge.r")
    tuple val( id ), path( 'input/?/*' )
    path cube

    output:
    tuple val( id ), path( "*.tif" ), emit: tilesMerged

    """

    files=`find -L input/ -type f -printf "%f\\n" | sort | uniq`

    for file in \$files
    do
        
        onefile=`ls -- */*/\${file} | head -1`
        
        #merge together
        matchingFiles=`ls -- */*/\${file}`
        ./merge.r \$file \${matchingFiles}

        #apply meta
        force-mdcp \$onefile \$file

    done

    """

}