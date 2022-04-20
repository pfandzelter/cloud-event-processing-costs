
export SERVICE_ACCOUNT_NAME=config-connector
export PROJECT_ID=$1

# Create IAM service account 
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME

# Give the IAM service account elevated permissions on your project
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/editor"

# Create an IAM policy binding between the IAM service account and the predefined Kubernetes service account that Config Connector runs:
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com --member="serviceAccount:$PROJECT_ID.svc.id.goog[cnrm-system/cnrm-controller-manager]" --role="roles/iam.workloadIdentityUser"

# Configuring Config Connector
kubectl apply -f configconnector.yaml 

# Specifying where to create your resources
kubectl annotate namespace default cnrm.cloud.google.com/project-id=$PROJECT_ID

# Verifying your installation
kubectl wait -n cnrm-system --for=condition=Ready pod --all


# Enable PubSub
kubectl apply -f pubsub-enabler.yaml 

# Verfiy pubsub enabled
kubectl get service.serviceusage.cnrm.cloud.google.com/pubsub.googleapis.com
