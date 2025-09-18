# Advanced routing using HTTP matching conditions

This use case shows how to publish two sample applications using HTTP matching conditions routing

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/2.advanced-routing
```

Deploy two sample web applications
```code
kubectl apply -f 0.coffee.yaml
kubectl apply -f 1.tea.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                              READY   STATUS    RESTARTS   AGE
pod/cafe-nginx-7444846d75-cgmms   1/1     Running   0          91s
pod/coffee-v1-c48b96b65-5trnr     1/1     Running   0          91s
pod/coffee-v2-685fd9bb65-dz5pp    1/1     Running   0          91s
pod/coffee-v3-7fb98466f-478hw     1/1     Running   0          91s
pod/tea-596697966f-hzjw5          1/1     Running   0          91s
pod/tea-post-5647b8d885-5xxvf     1/1     Running   0          91s

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/cafe-nginx      NodePort    10.103.90.239    <none>        80:31436/TCP   91s
service/coffee-v1-svc   ClusterIP   10.107.70.64     <none>        80/TCP         91s
service/coffee-v2-svc   ClusterIP   10.102.153.99    <none>        80/TCP         91s
service/coffee-v3-svc   ClusterIP   10.110.117.58    <none>        80/TCP         91s
service/kubernetes      ClusterIP   10.96.0.1        <none>        443/TCP        268d
service/tea-post-svc    ClusterIP   10.105.108.172   <none>        80/TCP         91s
service/tea-svc         ClusterIP   10.102.222.60    <none>        80/TCP         91s

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cafe-nginx   1/1     1            1           91s
deployment.apps/coffee-v1    1/1     1            1           91s
deployment.apps/coffee-v2    1/1     1            1           91s
deployment.apps/coffee-v3    1/1     1            1           91s
deployment.apps/tea          1/1     1            1           91s
deployment.apps/tea-post     1/1     1            1           91s

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/cafe-nginx-7444846d75   1         1         1       91s
replicaset.apps/coffee-v1-c48b96b65     1         1         1       91s
replicaset.apps/coffee-v2-685fd9bb65    1         1         1       91s
replicaset.apps/coffee-v3-7fb98466f     1         1         1       91s
replicaset.apps/tea-596697966f          1         1         1       91s
replicaset.apps/tea-post-5647b8d885     1         1         1       91s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 2.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`cafe-nginx-7444846d75-cgmms` pod is the NGINX Gateway Fabric dataplane
```
NAME                          READY   STATUS    RESTARTS   AGE
cafe-nginx-7444846d75-cgmms   1/1     Running   0          113s
coffee-v1-c48b96b65-5trnr     1/1     Running   0          113s
coffee-v2-685fd9bb65-dz5pp    1/1     Running   0          113s
coffee-v3-7fb98466f-478hw     1/1     Running   0          113s
tea-596697966f-hzjw5          1/1     Running   0          113s
tea-post-5647b8d885-5xxvf     1/1     Running   0          113s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME   CLASS   ADDRESS         PROGRAMMED   AGE
cafe   nginx   10.103.90.239   True         2m43s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`cafe-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
cafe-nginx      NodePort    10.103.90.239    <none>        80:31436/TCP   28s
coffee-v1-svc   ClusterIP   10.107.70.64     <none>        80/TCP         28s
coffee-v2-svc   ClusterIP   10.102.153.99    <none>        80/TCP         28s
coffee-v3-svc   ClusterIP   10.110.117.58    <none>        80/TCP         28s
kubernetes      ClusterIP   10.96.0.1        <none>        443/TCP        268d
tea-post-svc    ClusterIP   10.105.108.172   <none>        80/TCP         28s
tea-svc         ClusterIP   10.102.222.60    <none>        80/TCP         28s
```

Create the HTTP routes
```code
kubectl apply -f 3.cafe-routes.yaml
```

Check the HTTP routes
```code
kubectl get httproute
```

Output should be similar to
```code
NAME     HOSTNAMES              AGE
coffee   ["cafe.example.com"]   8s
tea      ["cafe.example.com"]   8s
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc cafe-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

Access `coffee-v1`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to
```code
Server address: 10.0.156.109:8080
Server name: coffee-v1-c48b96b65-5trnr
Date: 12/Jun/2025:11:00:28 +0000
URI: /coffee
Request ID: 1a0b8a08ec4f94f6a5f02e7649165b18
```

Access `coffee-v2` using a query string
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee?TEST=v2
```

Output should be similar to
```code
Server address: 10.0.156.121:8080
Server name: coffee-v2-685fd9bb65-dz5pp
Date: 12/Jun/2025:11:00:44 +0000
URI: /coffee?TEST=v2
Request ID: eac31b251dfdf398033d8e8373df14c9
```

Access `coffee-v2` using an HTTP header
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee -H "version: v2"
```

Output should be similar to
```code
Server address: 10.0.156.121:8080
Server name: coffee-v2-685fd9bb65-dz5pp
Date: 12/Jun/2025:11:01:00 +0000
URI: /coffee
Request ID: 0f5cd7a2f62965279c4bdc52c660c97d
```

Access `coffee-v3` using a query string
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee?queryRegex=query-a
```

Output should be similar to
```code
Server address: 192.168.169.141:8080
Server name: coffee-v3-7fb98466f-tgq8k
Date: 18/Sep/2025:21:26:26 +0000
URI: /coffee?queryRegex=query-a
Request ID: 2c755a8391ebd2df87f416510fb5478b
```

Access `coffee-v3` using an HTTP header
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee -H "headerRegex: header-a"
```

Output should be similar to
```code
Server address: 192.168.169.141:8080
Server name: coffee-v3-7fb98466f-tgq8k
Date: 18/Sep/2025:21:25:13 +0000
URI: /coffee
Request ID: 81431954b4b52edc01d707b4e5822792
```

Access `tea` using `GET`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/tea
```

Output should be similar to
```code
Server address: 10.0.156.108:8080
Server name: tea-596697966f-hzjw5
Date: 12/Jun/2025:11:01:13 +0000
URI: /tea
Request ID: 7a45019ce6b1380b5d5402be89103703
```

Access `tea` using `POST`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/tea -X POST
```

Output should be similar to
```code
Server address: 10.0.156.122:8080
Server name: tea-post-5647b8d885-5xxvf
Date: 12/Jun/2025:11:01:32 +0000
URI: /tea
Request ID: 92c6bb8c35b24c1ca0e68eaaf4bbbf40
```

Delete the lab

```code
kubectl delete -f .
```
