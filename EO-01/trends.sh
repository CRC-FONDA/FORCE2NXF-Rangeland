#!/bin/bash

EXPECTED_ARGS=1

if [ $# -ne $EXPECTED_ARGS ]; then
  echo "Usage: `basename $0` dir-data"
  echo ""
  echo "       dir-data: directory with data for input/output"
  echo ""
  exit
fi


INP=$1

if [ ! -r $INP ]; then
  echo "$INP is not existing/readable"
  exit
fi

cd $INP


# define relative I/O directories
# these need to match the "data repository" and the parameterfiles
#----------------------------------------------------------------------------------

# satellite data
LANDSAT_MAIN="input/landsat"
LANDSAT_META="$LANDSAT_MAIN"/"metadata"
LANDSAT_DATA="$LANDSAT_MAIN"/"data"

# vector data and area-of-interest (AOI)
VECTOR_MAIN="input/vector"
AOI="$VECTOR_MAIN"/"crete.shp"

# definition of the ARD grid
GRID_MAIN="input/grid"
GRID_DEF="$GRID_MAIN"/"datacube-definition.prj"

# parameter files
PAR_MAIN="input/parameters"
PAR_LEVEL2="$PAR_MAIN"/"level2.prm"
PAR_TRENDS="$PAR_MAIN"/"higher-level_trends.prm"

# Level 2 data (output)
LEVEL2_MAIN="output/level2"
LEVEL2_WRS="$LEVEL2_MAIN"/"wrs"
LEVEL2_LOG="$LEVEL2_MAIN"/"log"
LEVEL2_TMP="$LEVEL2_MAIN"/"tmp"
LEVEL2_ARD="$LEVEL2_MAIN"/"ard"

# Analysis masks (output)
MASK_MAIN="output/mask"

# Higher Level data (output)
HIGHER_MAIN="output/higher-level"
HIGHER_PARS="$HIGHER_MAIN"/"parameters"

# Tile allow list (output)
TILE_ALLOW="$HIGHER_MAIN"/"tiles.txt"


# basic input tests, do you need these, or is this somehow handled by the workflow language?
# just an example here
#----------------------------------------------------------------------------------
if [ ! -r "$PAR_LEVEL2" ]; then
  echo "$PAR_LEVEL2 is not readable"; exit
fi


# Next lines are for downloading the satellite data, we assume this is already done
# Uncomment this if necessary, do not do this multiple times
#----------------------------------------------------------------------------------

#mkdir -p "$LANDSAT_MAIN"
#mkdir -p "$LANDSAT_META"
#mkdir -p "$LANDSAT_DATA"

# initialize metadata catalogue
#force-level1-csd -u -s LT04,LT05,LE07 "$LANDSAT_META"

# download data
#force-level1-csd -s LT04,LT05,LE07 -d 19840101,20061231 -c 0,70 "$LANDSAT_META" "$LANDSAT_DATA" "$LANDSAT_MAIN"/"queue.txt" "$AOI"


# Step 1: preprocessing
#----------------------------------------------------------------------------------

mkdir -p "$LEVEL2_MAIN"
mkdir -p "$LEVEL2_WRS"
mkdir -p "$LEVEL2_LOG"
mkdir -p "$LEVEL2_TMP"
mkdir -p "$LEVEL2_ARD"

# this here can be parallelized per image, todo: expose the loop
# todo with feedback from Fabian, how to handle the parameterfile? Especially directories
# how do we make the input data available to the groups?
# should the parameterfiles be in this repository, or rather in the "data repository"?
# cp and sed?
force-level2 "$PAR_LEVEL2"


# Step 1.5: data cubing
#----------------------------------------------------------------------------------

cp "$GRID_DEF" -t "$LEVEL2_ARD"

# collect the processed files
find "$LEVEL2_WRS" -name '*BOA.tif' > "$LEVEL2_WRS"/"boa.txt"
find "$LEVEL2_WRS" -name '*QAI.tif' > "$LEVEL2_WRS"/"qai.txt"


# This here handles the cubing in a 2nd step to avoid lock-file issue
# Run on a single machine, run sequentially
# There is a way to distribute this on a cluster, but we should talk before
# This and the next step can be done simultaneously
while IFS="" read -r f; do
  printf '%s\n' "$f"
  force-cube "$f" "$LEVEL2_ARD" cubic 30
done < "$LEVEL2_WRS"/"boa.txt"

# A different resampling is required for the quality bits
# Run on a single machine, run sequentially
# There is a way to distribute this on a cluster, but we should talk before
# This and the previous step can be done simultaneously
while IFS="" read -r f; do
  printf '%s\n' "$f"
  force-cube "$f" "$LEVEL2_ARD" near 30
done < "$LEVEL2_WRS"/"qai.txt"


# Step 1.6: generate analysis masks
#----------------------------------------------------------------------------------

# generate analysis masks to only compute trends over the AOI land surface
mkdir -p "$MASK_MAIN"
cp "$GRID_DEF" -t "$MASK_MAIN"
force-cube "$AOI" "$MASK_MAIN" rasterize 30


# Step 2: Higher Level processing
#----------------------------------------------------------------------------------

mkdir -p "$HIGHER_MAIN"
mkdir -p "$HIGHER_PARS"

# generate a tile allow list, we loop over these tiles in the next step
force-tile-extent "$AOI" "$LEVEL2_ARD" "$TILE_ALLOW"

# remove 1st line, not needed here
sed -i '1d' "$TILE_ALLOW"

# generate a parameterfile for each tile
# this loop here doesn't take long, keep sequentially?!
while IFS="" read -r t; do
  X=${t:1:4}
  Y=${t:7:11}
  cp "$PAR_TRENDS" "$HIGHER_PARS"/"$t.prm"
  sed -i "s/REPX/$X/g" "$HIGHER_PARS"/"$t.prm"
  sed -i "s/REPY/$Y/g" "$HIGHER_PARS"/"$t.prm"
done < "$TILE_ALLOW"


# higher-level processing
# loop over each tile, these can be distributed in a cluster
for p in "$HIGHER_PARS"/"*.prm"; do
  force-higher-level "$p"
done


# Step 3: make a mosaic and compute pyramids
#----------------------------------------------------------------------------------

# run on one machine
force-mosaic "$HIGHER_MAIN"

# this here can be distributed to nodes and cores
for f in "$HIGHER_MAIN"/"mosaic/*.vrt"; do 
  force-pyramid $f
done

