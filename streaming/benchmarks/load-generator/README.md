# Manual Steps (one-time per cluster)

## Create Secret

```
kubectl create secret generic github-token --from-literal=GITHUB_PAT=<your-personal-access-token>
```

## Create ConfigMap

```
kubectl create configmap terraform-run-script --from-file run.sh
```
