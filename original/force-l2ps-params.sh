#!/bin/bash

# set parameters - this is usually done by hand
PARAM=$1
CUBE=$2

# read grid definition
CRS=$(sed '1q;d' $CUBE)
ORIGINX=$(sed '2q;d' $CUBE)
ORIGINY=$(sed '3q;d' $CUBE)
TILESIZE=$(sed '6q;d' $CUBE)
BLOCKSIZE=$(sed '7q;d' $CUBE)

# set parameters
sed -i "/^FILE_QUEUE /cFILE_QUEUE = queue.txt" $PARAM
sed -i "/^DIR_LEVEL2 /cDIR_LEVEL2 = ard/" $PARAM
sed -i "/^DIR_LOG /cDIR_LOG = log/" $PARAM
sed -i "/^DIR_TEMP /cDIR_TEMP = tmp/" $PARAM
sed -i "/^FILE_DEM /cFILE_DEM = dem/global_srtm-aster.vrt" $PARAM
sed -i "/^DIR_WVPLUT /cDIR_WVPLUT = wvdb" $PARAM
sed -i "/^FILE_TILE /cFILE_TILE = tiles.txt" $PARAM
sed -i "/^TILE_SIZE /cTILE_SIZE = $TILESIZE" $PARAM
sed -i "/^BLOCK_SIZE /cBLOCK_SIZE = $BLOCKSIZE" $PARAM
sed -i "/^ORIGIN_LON /cORIGIN_LON = $ORIGINX" $PARAM
sed -i "/^ORIGIN_LAT /cORIGIN_LAT = $ORIGINY" $PARAM
sed -i "/^PROJECTION /cPROJECTION = $CRS" $PARAM
sed -i "/^NPROC /cNPROC = 112" $PARAM
sed -i "/^NTHREAD /cNTHREAD = 1" $PARAM
sed -i "/^DELAY /cDELAY = 0" $PARAM

exit 0
