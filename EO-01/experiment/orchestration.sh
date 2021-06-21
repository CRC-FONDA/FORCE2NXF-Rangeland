nodes=( 21 20 15 10 5 3 1 )
runs=( 1 2 3 )

for run in "${runs[@]}"
do
    for node in "${nodes[@]}"
    do

        echo "Run experiment for $node nodes, run: $run"
        bash runKubernetesExperiment.sh $node $run

    done
done 