#!/bin/bash

# original FORCE workflow

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Docker prep
WORKDIR=/data/Jakku/fonda/B5-EO-01
IMAGE=davidfrantz/force:3.6.5
shopt -s expand_aliases
alias docker-force='docker run --rm -it -v $WORKDIR:/data/eo -w /data/eo -u $(id -u):$(id -g) $IMAGE'


# make directories
mkdir -p mask ard log tmp trend

# copy datacube definition to mask directory
cp datacube-definition.prj mask/

# generate processing masks
docker-force force-cube aoi.gpkg mask rasterize 30

# generate a tile allow-list
docker-force force-tile-extent aoi.gpkg mask tiles.txt

# Level 2 parameter file
docker-force force-parameter . LEVEL2 0
mv LEVEL2-skeleton.prm ard.prm
$BIN/force-l2ps-params.sh ard.prm # usually done by hand

# preprocessing to Level 2 ARD
docker-force force-level2 ard.prm

# higher level (TSA) parameter file
docker-force force-parameter . TSA 0
mv TSA-skeleton.prm trend.prm
$BIN/force-hlps-params.sh trend.prm # usually done by hand

# higher level processing
docker-force force-higher-level trend.prm

# mosaicking
docker-force force-mosaic trend

# pyramids
docker-force force-pyramid trend/mosaic/*

exit 0
