#!/bin/bash

# set parameters - this is usually done by hand
PARAM=$1

# set parameters
sed -i "/^DIR_LEVEL2 /cDIR_LEVEL2 = ard/" $PARAM
sed -i "/^DIR_LOG /cDIR_LOG = log/" $PARAM
sed -i "/^DIR_TEMP /cDIR_TEMP = tmp/" $PARAM
sed -i "/^FILE_DEM /cFILE_DEM = dem/global_srtm-aster.vrt" $PARAM
sed -i "/^DIR_WVPLUT /cDIR_WVPLUT = wvdb" $PARAM
sed -i "/^FILE_TILE /cFILE_TILE = tiles.txt" $PARAM
sed -i "/^NTHREAD /cNTHREAD = 56" $PARAM

exit 0
