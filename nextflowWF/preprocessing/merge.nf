nextflow.enable.dsl=2

process merge {

    tag { id }

    container 'davidfrantz/force:dev'
    memory { 2000.MB * task.attempt }
    time { 20.minute * task.attempt }

    input:
    path ("merge.r")
    tuple val( id ), path( 'input/?/*' )
    path cube

    output:
    tuple val( id ), path( "*.tif" ), emit: tilesMerged

    """

    files=`find -L input/ -type f -printf "%f\\n" | sort | uniq`
    numberFiles=`echo \$files | wc -w`
    currentFile=0

    for file in \$files
    do
        currentFile=\$((currentFile+1))
        echo "Merging \$file (\$currentFile of \$numberFiles)"
        
        onefile=`ls -- */*/\${file} | head -1`
        
        #merge together
        matchingFiles=`ls -- */*/\${file}`
        ./merge.r \$file \${matchingFiles}

        #apply meta
        force-mdcp \$onefile \$file

    done

    """

}