
echo first parementer: number nodes, second parementer: trial

mkdir -p ./results/$1/$2/

#preparation
bash clearEnvironment.sh
bash labelNodes.sh $1

podName=eo-experiment-n$1-e$2

#execution phase
bash runOnKubernetes.sh $podName > ./results/$1/$2/execution.log

bash waitForPod.sh $podName

kubectl logs $podName -n default > ./results/$1/$2/pod.log

#finish phase
bash collectResults.sh $1 $2
bash clearPods.sh

mv experiment.log ./results/$1/$2/experiment.log