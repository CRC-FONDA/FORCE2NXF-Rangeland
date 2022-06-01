nextflow.enable.dsl=2
params.forceVer = "latest"

process downloadWaterVapor{

    //Has to be downloaded anyways, so we can use it only for wget
    container "davidfrantz/force:${params.forceVer}"

    output:
    file 'wvdb/', emit: wvdbFiles

    """
    wget -O wvp-global.tar.gz https://zenodo.org/record/4468701/files/wvp-global.tar.gz?download=1
    mkdir wvdb
    tar -xzf wvp-global.tar.gz --directory wvdb/
    """

}