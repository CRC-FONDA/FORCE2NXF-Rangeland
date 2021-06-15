
echo first parementer: number nodes, second parementer: trial

#preparation
bash clearEnvironment.sh
bash labelNodes.sh $1

#execution phase
bash run.sh

#finish phase
bash collectResults.sh $1 $2
bash clearPods.sh