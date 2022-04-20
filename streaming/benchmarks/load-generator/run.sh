#!/bin/bash 

set -e

echo "Use cloud: ${CLOUD}."

CLOUDSUF=-${CLOUD}
SUFFIX=${CLOUDSUF/-gcp/}

mkdir workdir
cd workdir
git clone -b kubernetes$SUFFIX https://$GITHUB_TOKEN@github.com/$GITHUB_REPO.git .
cd uc1$SUFFIX/terraform

terraform init

INSTANCES=$(( ($LOAD_INTENSITY + ($MAX_INSTANCE_LOAD - 1)) / $MAX_INSTANCE_LOAD ))
export TF_VAR_load_instance_count=$INSTANCES
export TF_VAR_num_sensors=$LOAD_INTENSITY
export TF_VAR_target=$TARGET
export TF_VAR_http_url=$HTTP_URL
export TF_VAR_pubsub_input_topic=$PUBSUB_INPUT_TOPIC
export TF_VAR_run_name=runx
export TF_VAR_project=$GCP_PROJECT
export TF_VAR_subnet_id=$AWS_SUBNET_ID

_term() { 
  echo "Start destroying terraform."
  terraform destroy -auto-approve
  rm -r -f ../../../workdir
  echo "Destroy finished."
  exit
}

trap _term SIGTERM SIGINT

echo "Start applying terraform."
# Force recreate
terraform destroy -auto-approve && terraform apply -auto-approve
echo "Apply finished."

echo "Start sleeping forever."
while :
do
  sleep 1s # We still need to listen for signals
done
