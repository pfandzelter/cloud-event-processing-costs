# (Re)create all ConfigMaps containing the benchmark resources.

kubectl delete configmap terraform-load-generator-gcp
kubectl create configmap terraform-load-generator-gcp --from-file load-generator/terraform-deployment-gcp.yaml
kubectl delete configmap terraform-load-generator-aws
kubectl create configmap terraform-load-generator-aws --from-file load-generator/terraform-deployment-aws.yaml
kubectl delete configmap http-bridge
kubectl create configmap http-bridge --from-file http-bridge
kubectl delete configmap pubsub
kubectl create configmap pubsub --from-file pubsub
kubectl delete configmap uc1-beam-flink-http
kubectl create configmap uc1-beam-flink-http --from-file uc1-beam-flink-http
kubectl delete configmap uc1-beam-flink-pubsub
kubectl create configmap uc1-beam-flink-pubsub --from-file uc1-beam-flink-pubsub
kubectl delete configmap uc1-beam-dataflow-pubsub
kubectl create configmap uc1-beam-dataflow-pubsub --from-file uc1-beam-dataflow-pubsub
kubectl delete configmap uc1-beam-samza-http
kubectl create configmap uc1-beam-samza-http --from-file uc1-beam-samza-http
kubectl delete configmap uc3-beam-flink-http
kubectl create configmap uc3-beam-flink-http --from-file uc3-beam-flink-http
kubectl delete configmap uc3-beam-flink-pubsub
kubectl create configmap uc3-beam-flink-pubsub --from-file uc3-beam-flink-pubsub
kubectl delete configmap uc3-beam-dataflow-pubsub
kubectl create configmap uc3-beam-dataflow-pubsub --from-file uc3-beam-dataflow-pubsub
kubectl delete configmap uc3-beam-samza-http
kubectl create configmap uc3-beam-samza-http --from-file uc3-beam-samza-http
