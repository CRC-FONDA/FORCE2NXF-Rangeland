#!/bin/bash

ID=$1
CUBE=$2
RES=$3

INP="tile/"

NODATA=$(gdalinfo tile/tile1.tif | grep NoData | head -n 1 |  sed 's/ //g' | cut -d '=' -f 2)

TILESIZE=$(head -n 6 $CUBE | tail -1 )
CHUNKSIZE=$(head -n 7 $CUBE | tail -1 )

XBLOCK=$(echo $TILESIZE  $RES | awk '{print int($1/$2)}')
YBLOCK=$(echo $CHUNKSIZE $RES | awk '{print int($1/$2)}')

mv tile/tile1.tif "$ID".tif

results=`find tile -name '*.tif'`
for path in $results; do

    gdal_merge.py -q -o "out.tif" -n $NODATA -a_nodata $NODATA \
        -init $NODATA -of GTiff -co 'INTERLEAVE=BAND' -co 'COMPRESS=LZW' -co 'PREDICTOR=2' \
        -co 'NUM_THREADS=ALL_CPUS' -co 'BIGTIFF=YES' -co "BLOCKXSIZE=$XBLOCK" \
        -co "BLOCKYSIZE=$YBLOCK" "$ID".tif "$path"

    #delete merged files
    rm "$ID".tif "$path"

    mv out.tif "$ID".tif
done;

exit 0
