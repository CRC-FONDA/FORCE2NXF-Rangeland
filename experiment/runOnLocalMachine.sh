#!/bin/bash

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

mkdir -p ./results/local/$1/

echo go
nextflow run "$BIN/../nextflowWF/workflow-dsl2.nf" \
-c "$BIN/nextflow.config" \
--inputdata "/data/Jakku/fonda/data/EO-01/input" \
--outdata "/data/Jakku/fonda/B5-EO-01-NF" \
--groupSize 100 \
--forceVer 3.6.5 \
-with-dag ./results/local/$1/dag.dot \
-with-report ./results/local/$1/report.html \
-with-timeline ./results/local/$1/timeline.html \
-with-trace ./results/local/$1/trace.txt \
-name eo-experiment-test-n$1-e$2 &> ./results/local/$1/log.log

mv .nextflow.* ./results/local/$1/

find ./work/ -name '.command.*' -print0 | tar -cvjf ./results/local/$1/logs.tar.bz2 --null --files-from -
