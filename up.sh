#!/bin/bash

set -e

echo "########## starting minikube"

minikube status || minikube start 
#--nodes=5 --cpus=3 --memory=4G

echo
echo "########## installing crossplane with providers"

kubectl get namespace crossplane-system || \
    kubectl create namespace crossplane-system 

helm status --namespace crossplane-system crossplane || \
    helm install crossplane --wait --namespace crossplane-system \
        crossplane-stable/crossplane \
        --set provider.packages=\{crossplane/provider-aws:v0.32.0,crossplane/provider-helm:v0.11.1,crossplane/provider-kubernetes:v0.4.1\}

echo
echo "########## waiting for Crossplane to deploy"

kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/crossplane-provider-helm
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/crossplane-provider-kubernetes

echo
echo "########## allow SAs to operate cluster it is running on"

SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|crossplane-system:|g')
kubectl get clusterrolebinding provider-kubernetes-admin-binding || \
    kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"

SA=$(kubectl -n crossplane-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|crossplane-system:|g')
kubectl get clusterrolebinding provider-helm-admin-binding || \
    kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"

echo
echo "########## configure providers"

cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-provider
spec:
  credentials:
    source: InjectedIdentity
---
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: helm-provider
spec:
  credentials:
    source: InjectedIdentity
EOF

echo
echo "########## deploy dbaas platform"
kubectl get configuration.pkg.crossplane.io/denisok-dbaas-platform || \
  kubectl crossplane install configuration ghcr.io/denisok/dbaas-platform:v0.0.12
kubectl wait --for=condition=Healthy configuration.pkg.crossplane.io/denisok-dbaas-platform --timeout=2m
exit 0
echo
echo "########## deploy pmm"

cat <<EOF | kubectl apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: pmm
spec:
  forProvider:
    chart:
      name: pmm
      repository: https://percona.github.io/percona-helm-charts/
      version: 0.3.8
    namespace: default
    values:
      image:
        repository: perconalab/pmm-server-fb
        tag: "PR-2685-0944b52"
      pmmEnv:
        DISABLE_UPDATES: "1"
        ENABLE_DBAAS: "1"
        PMM_PUBLIC_ADDRESS: "monitoring-service"
  providerConfigRef:
    name: helm-provider
EOF

echo
echo "########## wait for pmm"
kubectl wait --for=condition=Ready release.helm.crossplane.io/pmm --timeout=2m
kubectl wait --for=condition=Ready pod --selector=app.kubernetes.io/name=pmm --timeout=3m

export NODE_PORT=$(kubectl get service -o jsonpath="{.spec.ports[0].nodePort}" monitoring-service)
export NODE_IP=$(kubectl get nodes -o jsonpath="{.items[0].status.addresses[0].address}")
export PMM_PASS=$(kubectl get secret pmm-secret -o jsonpath='{.data.PMM_ADMIN_PASSWORD}' | base64 --decode)

echo
echo "########## Your DBaaS is ready!"
echo "https://$NODE_IP:$NODE_PORT/graph/dbaas/dbclusters"
echo "password:$PMM_PASS"
