sed -i "/process.pod = /c\\     process.pod = [ label : 'eo-experiment', value : 'n-$1_e-$2' ]" nextflow.config