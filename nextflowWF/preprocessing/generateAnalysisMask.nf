nextflow.enable.dsl=2

params.resolution = 30
params.forceVer = "latest"

process generateAnalysisMask{

    container "davidfrantz/force:${params.forceVer}"

    input:
    path aoi
    path 'mask/datacube-definition.prj'

    output:
    //Mask for whole region
    path 'mask/*/*.tif', emit: masks

    """
    force-cube $aoi mask/ rasterize $params.resolution
    """

}