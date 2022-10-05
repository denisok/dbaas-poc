# dbaas-poc
playground for dbaas releated PoCs


## Crossplane

Create config package:

```sh
cd packages/eks
kubectl crossplane build configuration
kubectl crossplane push configuration ghcr.io/denisok/dbaas-platform-eks:v0.0.6
```

Start k8s cluster:

```sh
minikube start
```

Install Crossplane with AWS provider:

```sh
kubectl create namespace crossplane-system
helm install crossplane --namespace crossplane-system crossplane-stable/crossplane --set provider.packages={crossplane/provider-aws:v0.32.0}
```

Create creds, use `aws-cli` (should be setup and configured) and setup script:
```sh
curl -O https://raw.githubusercontent.com/crossplane/crossplane/release-1.9/docs/snippets/configure/aws/providerconfig.yaml
curl -O https://raw.githubusercontent.com/crossplane/crossplane/release-1.9/docs/snippets/configure/aws/setup.sh
chmod +x setup.sh
./setup.sh
```

Provider config `providerconfig.yaml`:
```yaml
---
apiVersion: aws.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-creds
      key: creds
```

```sh
kubectl apply -f providerconfig.yaml 
```

Install composite resource:
```sh
kubectl crossplane install configuration ghcr.io/denisok/dbaas-platform-eks:v0.0.6
```

Create cluster claim `cluster-claim_eks.yaml`:
```yaml
apiVersion: eks.dbaas.percona.com/v1alpha1
kind: EKSkubernetesCluster
metadata:
  name: cluster3
spec:
  parameters:
    minNodeCount: 3
    nodeSize: small
    version: "1.23"
```

Apply claim:
```sh
kubectl apply -f cluster-claim_eks.yaml
kubectl get ekskubernetesclusters
```

Get kubeconfig:
```sh
kubectl --namespace crossplane-system get secret
kubectl --namespace crossplane-system get secret 354ba2d4-06a1-46ed-bfac-19cb5e71ba0a-ekscluster --output jsonpath="{.
data.kubeconfig}" | base64 --decode | tee eks-config.yaml
```
