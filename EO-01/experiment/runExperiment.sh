
echo first parementer: number nodes, second parementer: trial

mkdir -p ./results/$1/$2/

#preparation
bash clearEnvironment.sh
bash labelNodes.sh $1

#execution phase
bash run.sh $1 $2 > ./results/$1/$2/execution.log

#finish phase
bash collectResults.sh $1 $2
bash clearPods.sh