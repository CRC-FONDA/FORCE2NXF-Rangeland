nextflow.enable.dsl = 2

process FORCE_GENERATE_ANALYSIS_MASK{

    container "davidfrantz/force:3.7.11"

    input:
    path aoi
    path 'mask/datacube-definition.prj'

    output:
    //Mask for whole region
    path 'mask/*/*.tif', emit: masks

    """
    force-cube -o mask/ -s $params.resolution $aoi
    """

}
