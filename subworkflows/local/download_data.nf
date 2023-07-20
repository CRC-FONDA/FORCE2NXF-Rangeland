include { FORCE-DOWNLOAD_DATA } from '../../modules/local/force-download_data'

workflow DOWNLOAD_DATA {
    take:
    aoi         //   file: /path/to/aoi.gpkg"
    timeRange   // string: time range in FORCE format

    main:
    imagery_data = FORCE-DOWNLOAD_DATA ( aoi, time_range ).out.imagery_data

    emit:
    imagery_data
}
