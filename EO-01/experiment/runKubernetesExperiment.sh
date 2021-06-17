
echo first parementer: number nodes, second parementer: trial

mkdir -p ./results/$1/$2/

#preparation
bash clearEnvironment.sh
bash labelNodes.sh $1

#execution phase
bash runOnKubernetes.sh $1 $2 > ./results/$1/$2/execution.log

#finish phase
bash collectResults.sh $1 $2
bash clearPods.sh

mv experiment.log ./results/$1/$2/experiment.log