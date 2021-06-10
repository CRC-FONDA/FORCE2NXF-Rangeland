#!/bin/bash

# set parameters - this is usually done by hand
PARAM=$1

# pathes
sed -i "/^DIR_LOWER /cDIR_LOWER = ard/" $PARAM
sed -i "/^DIR_HIGHER /cDIR_HIGHER = trend/" $PARAM
sed -i "/^DIR_MASK /cDIR_MASK = mask/" $PARAM
sed -i "/^BASE_MASK /cBASE_MASK = aoi.tif" $PARAM
sed -i "/^FILE_ENDMEM /cFILE_ENDMEM = endmember.txt" $PARAM
sed -i "/^FILE_TILE /cFILE_TILE = tiles.txt" $PARAM

# threading
sed -i "/^NTHREAD_READ /cNTHREAD_READ = 8" $PARAM
sed -i "/^NTHREAD_COMPUTE /cNTHREAD_COMPUTE = 100" $PARAM
sed -i "/^NTHREAD_WRITE /cNTHREAD_WRITE = 4" $PARAM

# resolution
sed -i "/^RESOLUTION /cRESOLUTION = 30" $PARAM

# sensors
sed -i "/^SENSORS /cSENSORS = LND04 LND05 LND07" $PARAM

# date range
sed -i "/^DATE_RANGE /cDATE_RANGE = 1984-01-01 2006-12-31" $PARAM

# spectral index
sed -i "/^INDEX /cINDEX = SMA" $PARAM

# interpolation
sed -i "/^INT_DAY /cINT_DAY = 8" $PARAM
sed -i "/^OUTPUT_TSI /cOUTPUT_TSI = TRUE" $PARAM

# polar metrics
sed -i "/^POL /cPOL = VPS VBL VSA" $PARAM
sed -i "/^OUTPUT_POL /cOUTPUT_POL = TRUE" $PARAM
sed -i "/^OUTPUT_TRO /cOUTPUT_TRO = TRUE" $PARAM
sed -i "/^OUTPUT_CAO /cOUTPUT_CAO = TRUE" $PARAM

exit 0
