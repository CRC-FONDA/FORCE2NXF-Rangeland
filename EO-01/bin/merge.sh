#!/bin/bash

RESAMPLE="$2"
RES=$3

INP="tile/"
if [[ ! "$RESAMPLE" =~ "rasterize" ]]; then
    NODATA=$(gdalinfo tile/tile1.tif | grep NoData | head -n 1 |  sed 's/ //g' | cut -d '=' -f 2)
fi

TILESIZE=$(head -n 6 $cube | tail -1 )
CHUNKSIZE=$(head -n 7 $cube | tail -1 )

XBLOCK=$(echo $TILESIZE  $RES | awk '{print int($1/$2)}')
YBLOCK=$(echo $CHUNKSIZE $RES | awk '{print int($1/$2)}')

mv tile/tile1.tif "$1".tif

results=`find tile/*.tif`
for path in $results; do

    gdal_merge.py -q -o "out.tif" -n $NODATA -a_nodata $NODATA \
        -init $NODATA -of GTiff -co 'INTERLEAVE=BAND' -co 'COMPRESS=LZW' -co 'PREDICTOR=2' \
        -co 'NUM_THREADS=ALL_CPUS' -co 'BIGTIFF=YES' -co "BLOCKXSIZE=$XBLOCK" \
        -co "BLOCKYSIZE=$YBLOCK" "$1".tif "$path".tif

    #delete merged files
    rm "$1".tif "$path"

    mv out.tif "$1".tif
done;