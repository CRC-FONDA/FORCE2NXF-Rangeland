include { ARIA2               } from '../../modules/nf-core/aria2/main'
include { UNTAR               } from '../../modules/nf-core/untar/main'
include { FORCE-DOWNLOAD_DATA } from '../../modules/local/force-download_data'

workflow DOWNLOAD_DATA {
    take:
    aoi         //   file: /path/to/aoi.gpkg"
    timeRange   // string: time range in FORCE format

    main:

    // water vapor data
    ARIA2 ( params.water_vapor_url )
    UNTAR ( [:], ARIA2.out.downloaded_file )
    water_vapor_data = UNTAR.out.untar.map { it[1] }

    // remote sensing imagery
    imagery_data = FORCE-DOWNLOAD_DATA ( aoi, time_range ).out.imagery_data

    emit:
    water_vapor_data
    imagery_data
}
