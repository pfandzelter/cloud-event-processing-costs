# Streaming Implementations

Our Streaming implementations include UC1 and UC3 use-cases for:

* Apache Flink on Google Kubernetes Engine with HTTP triggers
* Apache Flink on Google Kubernetes Engine with Pub/Sub triggers
* Apache Flink on Amazon Elastic Kubernetes Service with HTTP triggers
* Apache Samza on Google Kubernetes Engine with HTTP triggers
* Google Cloud Dataflow with HTTP triggers

The implementations for all DSP engines are implemented with the Apache Beam SDK.
The source code of all implementations is available in [Theodolite's main repository](https://github.com/cau-se/theodolite).

This repository provides Kubernetes resources as well as [Theodolite](https://www.theodolite.rocks/) *Benchmark* and *Execution* resources.
They can be used to run our implementations in an automated way, collect required metrics and analyze them on-the-fly.

## Cluster Setup

Before running benchmarks, a Kubernetes cluster has to be created and the following steps must be applied:

### Google Cloud Setup

*(Only required when running Kubernetes at GCP.)*

A ConfigMap with your GCP project ID has to be created:

```sh
kubectl create configmap gcp-config --from-literal=project=<project-id>
```

A Secret containing your GCP service account key has to be created:

```sh
kubectl create secret generic gcp-key --from-file=key.json=<path-to-gcp-key>.json
```

#### Stackdriver Exporter

*(Only required when using Pub/Sub and/or Cloud Dataflow.)*

Install the Stackdriver Exporter with:

```sh
kubectl apply -f cluster/stackdriver-exporter
```

Stackdriver Exporter is used to access GCP metrics from Theodolite to decide whether a certain deployment can handle the tested load profile.

#### Config Connector

*(Only required when using Pub/Sub and/or Cloud Dataflow.)*

Some of our benchmarks require [GCP Config Connector](https://cloud.google.com/config-connector/) to be installed. This requires setting the corresponding flags during GKE cluster creation and applying the following steps:

1. Replace `<project-id>` with your GCP project ID in `cluster/config-connector/config-connector.yaml`.
2. Replace `<project-id>` with your GCP project ID in `cluster/config-connector/pubsub-enabler.yaml`.
3. Run `cluster/config-connector/setup-config-connector.sh`.

#### GCloud client

*(Only required when using Pub/Sub and/or Cloud Dataflow.)*

Install the GCloud client pod with:

```sh
kubectl apply -f cluster/gcloud-client
```

This pod is used to verify whether resetting Pub/Sub subscriptions is done.

### AWS setup

*(Only required when running Kubernetes at AWS.)*

Create credentials for DynamoDB:

```sh
kubectl create secret generic aws-dynamodb-credentials --from-literal=AWS_ACCESS_KEY=<your-aws-access-key> --from-literal=AWS_SECRET_KEY=<your-aws-secret-key>
```

Configure the executions with the public subnet ID of your Kubernetes cluster.

### PVC for Theodolite results

To create a persistent volume claim for your benchmarks results, which outlives Theodolite re-installations, run:

```sh
kubectl apply -f cluster/pvc.yaml
```

### Install Theodolite

Clone the Theodolite repository from <https://github.com/cau-se/theodolite> and install its Helm chart, either for using HTTP or Pub/Sub:

```sh
# When running the HTTP-based benchmarks:
helm install theodolite <path-to-theodolite>/helm -f cluster/helm-config/http.yaml
# When running the Pub/Sub-based benchmarks:
helm install theodolite <path-to-theodolite>/helm -f cluster/helm-config/pubsub.yaml
```

### Create the HTTP Load Balancer

As creating the HTTP Load Balancer may take some time, you should create it before running the benchmarks:

```sh
kubectl apply -f benchmarks/http-bridge/http-bridge-service-load-balancer.yaml
```

Get the load balancer hostname (AWS) or IP address (GCP):

```sh
kubectl get svc theodolite-http-bridge-load-balancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' # AWS
kubectl get svc theodolite-http-bridge-load-balancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}' # GCP
```

Update the execution YAML with the load balancer hostname or IP address.

## Running Benchmarks

A detailed explanation on how to run benchmarks with Theodolite is provided with [Theodolite's documentation](http://theodolite.rocks). The essential steps are:

1. Deploy the benchmarks along with the necessary benchmark resource ConfigMaps via:

  ```sh
  benchmarks/create-configmaps.sh
  kubectl apply -f benchmarks/<benchmark-file>.yaml
  ```

2. Start one or multiple benchmark executions, by deploying the execution files located in `executions`:

  ```sh
  kubectl apply -f executions/<execution-file>.yaml
  ```

3. Theodolite will create a bunch of CSV files containing the experiment results. The [Theodolite documentation](http://theodolite.rocks) explains how to copy and interprete these files.

## Analyzing Benchmark Results

The results of our experiments can be found in `analysis/results-aws`, `analysis/results-gcp`, and `analysis/results-gcp2`. The `analysis/setup.csv` file contains the setup information for each experiment.

Analyzing experiment results is done with the `analysis/cost-metric.ipynb` notebook. To run it, some dependencies have to be installed, which can be done with:

```sh
pip install -r analysis/requirements.txt
```

Besides some plots and tables, the notebook produces a `streaming-results.csv` files, which contains the costs per steup and load profile.
