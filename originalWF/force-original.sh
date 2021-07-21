#!/bin/bash

# original FORCE workflow
set -e

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

INPUTDIR=$1
WORKDIR=$2

# Docker prep
IMAGE=davidfrantz/force:3.6.5
shopt -s expand_aliases
alias docker-force='docker run --rm -it -v $INPUTDIR:/data/input -v $WORKDIR:/data/eo -w /data/eo -u $(id -u):$(id -g) $IMAGE'

# make directories
cd $WORKDIR
mkdir -p mask ard log tmp trend

# copy datacube definition to mask directory
cp $INPUTDIR/grid/datacube-definition.prj mask/

# generate processing masks
echo "START: generate masks"
time docker-force force-cube /data/input/vector/aoi.gpkg mask rasterize 30

# generate a tile allow-list
echo "START: tile allow-list"
time docker-force force-tile-extent /data/input/vector/aoi.gpkg mask tiles.txt

# Level 2 parameter file
echo "START: Level 2 Processing"
docker-force force-parameter . LEVEL2 0
mv LEVEL2-skeleton.prm ard.prm
cp $INPUTDIR/download/data/queue.txt queue.txt
$BIN/force-l2ps-params.sh ard.prm $INPUTDIR/grid/datacube-definition.prj # usually done by hand

# preprocessing to Level 2 ARD
time docker-force force-level2 ard.prm

# higher level (TSA) parameter file
echo "START: Higher Level Processing"
docker-force force-parameter . TSA 0
mv TSA-skeleton.prm trend.prm
$BIN/force-hlps-params.sh trend.prm tiles.txt # usually done by hand

# higher level processing
time docker-force force-higher-level trend.prm

# mosaicking
echo "START: mosaicking"
time docker-force force-mosaic trend

# pyramids
echo "START: pyramids"
time docker-force force-pyramid trend/*/*.tif

exit 0
