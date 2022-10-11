# dbaas-poc
playground for dbaas releated PoCs


## Build

How to create config package:

```sh
cd packages/eks
kubectl crossplane build configuration
kubectl crossplane push configuration ghcr.io/denisok/dbaas-platform:v0.0.12
```

## Use

Setup and Install: [script that deploys it in minikube](./up.sh)

Use: `kubectl apply -f DBClaim.yaml`
Check out `DBClaim.yaml` to see how you can use the claim

## Troubleshoot:

```
kubectl get event --all-namespaces --sort-by='.metadata.managedFields[0].time'
```
