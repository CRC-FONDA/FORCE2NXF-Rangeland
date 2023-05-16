nextflow.enable.dsl = 2

process FORCE_HIGHER_LEVEL {

    container "davidfrantz/force:${params.force_version}"

    input:
    path config

    output:
    path 'trend/*.tif*', emit: trend_files


"""
mkdir trend

force-higher-level $config

#Rename files: /trend/<Tile>/<Filename> to <Tile>_<Filename>, otherwise we can not reextract the tile name later
results=`find trend -name '*.tif*'`
for path in \$results; do
    mv \$path \${path%/*}_\${path##*/}
done;
"""

}

