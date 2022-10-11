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

Check out `DBClaim.yaml` to see how you can use the claim:
```yaml
apiVersion: dbaas.percona.com/v1alpha1
kind: DBclaim
metadata:
  name: psm-db-1
spec:
  compositionSelector:
    matchLabels:
      engine: psmdb
      storage: default
      network: default
  clusterSize: 1
  engineVersion: ""
  engineConfig: ""
```

## Troubleshoot:

```
kubectl get event --all-namespaces --sort-by='.metadata.managedFields[0].time'
```

## PoC results

DevOps/PET could define both infrastructure (EKS, VMs) and services, like deploying PMM on AWS Instance, deploying operators as well as define templates for `DBClaims`.

`DBClaims` could be later consumed either directly when deploying app, just adding `DBClaim` yaml and consume DB connection and secrets from k8s `Secrets`.

Or UI could just create/list `DBClaim` in more general way or any DB types.

One of the result is the way to template DBs that will be deployed is to use compositions: [PSMDB composition](./packages/database/dbclaim-psmdb/composition.yaml)

DevOps/PET could create number of those compositions to deploy CR with different parameters (like storage, networking and etc), so user could consume it by selecting in claims:

```
  compositionSelector:
    matchLabels:
      engine: psmdb
      storage: fast
      network: public
```


Another result is testing access to API.

Currently [dbaas-controller](https://github.com/percona-platform/dbaas-controller) implements proxy api to k8s Percona operators thus `dbaas-controller` needs to call k8s and gets data from k8s operators. That could be expensive call to k8s as api returns full spec and in case of 100 or 1000 of server it could be quite large and time consuming response.

Also if there is no good connection to the k8s cluster situation would be much worse.

Here I measured API request time done in different environments.

### PMM in the same k8s cluster

```
TIME="%e\n" time curl -k -s -o file.out --request POST --url https://172.105.146.244/v1/management/DBaaS/DBClust
ers/List --header 'accept: application/json' --header 'authorization: Basic YWRtaW46VyUrMS5bVCszMV5LemQ7Nw==' --header 'content-type: application
/json' --data '
{
     "kubernetes_cluster_name": "default-pmm-cluster"
}
'
7.42

TIME="%e\n" time curl -k -s -o file.out --request POST --url https://172.105.146.244/v1/management/DBaaS/DBClusters/List --header 'accept: application/json' --header 'authorization: Basic YWRtaW46VyUrMS5bVCszMV5LemQ7Nw==' --header 'content-type: application/json' --data '
{
     "kubernetes_cluster_name": "default-pmm-cluster"
}
'
7.90
```

### PMM in the same k8s cluster

```
TIME="%e\n" time curl -k -s -o file1.out --request POST --url https://localhost:8443/v1/management/DBaaS/DBClusters/List --header 'accept: application/json' --header 'authorization: Basic YWRtaW46YWRtaW4=' --header 'content-type: application/json' --data '
{
     "kubernetes_cluster_name": "lke75856"
}
'

TIME="%e\n" time curl -k -s -o file1.out --request POST --url https://localhost:8443/v1/management/DBaaS/DBClusters/List --header 'accept: application/json' --header 'authorization: Basic YWRtaW46YWRtaW4=' --header 'content-type: application/json' --data '
{
     "kubernetes_cluster_name": "lke75856"
}
'
30.66

TIME="%e\n" time curl -k -s -o file1.out --request POST --url https://localhost:8443/v1/management/DBaaS/DBClusters/List --header 'accept: application/json' --header 'authorization: Basic YWRtaW46YWRtaW4=' --header 'content-type: application/json' --data '
{
     "kubernetes_cluster_name": "lke75856"
}
'
26.60

TIME="%e\n" time curl -k -s --request POST --url https://localhost:8443/v1/management/DBaaS/DBClusters/List --header 'accept: application/json' --header 'authorization: Basic YWRtaW46YWRtaW4=' --header 'content-type: application/json' --data '
{
     "kubernetes_cluster_name": "lke75856"
}
'
<html>
<head><title>504 Gateway Time-out</title></head>
<body>
<center><h1>504 Gateway Time-out</h1></center>
<hr><center>nginx</center>
</body>
</html>
60.04
```

##$ Request to the k8s UI directly and test limit

```
TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/dbaas.percona.com/v1alpha1/dbclaims?limit=5 | jq '.items | length'
0.47
5

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/dbaas.percona.com/v1alpha1/dbclaims?limit=5 | jq '.items | length'
0.32
5

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/dbaas.percona.com/v1alpha1/dbclaims | jq '.items | length'
1.46
20

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/dbaas.percona.com/v1alpha1/dbclaims | jq '.items | length'
0.56
20

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/dbaas.percona.com/v1alpha1/dbclaims | jq '.items | length'
0.57
20

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/dbaas.percona.com/v1alpha1/dbclaims | jq '.items | length'
0.53
20

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/pxc.percona.com/v1/perconaxtradbclusters | jq '.items | length'
0.54
10

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/pxc.percona.com/v1/perconaxtradbclusters | jq '.items | length'
1.09
10

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/pxc.percona.com/v1/perconaxtradbclusters | jq '.items | length'
2.03
10

TIME="%e\n" time curl -s -k --header "Authorization: Bearer $JWT_TOKEN_KUBESYSTEM_DEFAULT" $KUBE_API/apis/pxc.percona.com/v1/perconaxtradbclusters | jq '.items | length'
1.36
10
```

So k8s mitigating such kind of issues be breaking [response in chunks](https://kubernetes.io/docs/reference/using-api/api-concepts/#retrieving-large-results-sets-in-chunks).

Another point is that for listing clusters we don't need full CR response.

The way to mitigate this issue:
1. use k8s directly from UI
2. use `limit`
3. implement proxy layer (operator, crossplane) in k8s

The point #1 is proven by calling `apis/pxc.percona.com/v1/perconaxtradbclusters` - it takes much less time than going through PMM.

Point #2 is also shown, using that from UI would further improve performance, as we don't need full list for UI.

Point #3 is `apis/dbaas.percona.com/v1alpha1/dbclaims` it suppose to return much less info (only that is in DBClaim) and thus further improved bandwidth.
