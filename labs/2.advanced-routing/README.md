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
cafe   nginx   192.168.2.210   True         24s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`cafe-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
cafe-nginx      LoadBalancer   10.110.78.90     192.168.2.210   80:32561/TCP   34s
coffee-v1-svc   ClusterIP      10.110.104.7     <none>          80/TCP         35s
coffee-v2-svc   ClusterIP      10.106.7.135     <none>          80/TCP         34s
coffee-v3-svc   ClusterIP      10.101.144.146   <none>          80/TCP         34s
kubernetes      ClusterIP      10.96.0.1        <none>          443/TCP        402d
tea-post-svc    ClusterIP      10.101.97.170    <none>          80/TCP         34s
tea-svc         ClusterIP      10.100.124.14    <none>          80/TCP         34s
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
export NGF_IP=`kubectl get svc cafe-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
export HTTP_PORT=`kubectl get svc cafe-nginx -o jsonpath='{.spec.ports[0].targetPort}'`
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
Server address: 10.0.156.103:8080
Server name: coffee-v1-c48b96b65-782sw
Date: 24/Oct/2025:15:20:46 +0000
URI: /coffee
Request ID: db3b0f2df6ba9cb4bf5dc2f1a8861722
```

Access `coffee-v2` using a query string
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee?TEST=v2
```

Output should be similar to
```code
Server address: 10.0.156.80:8080
Server name: coffee-v2-685fd9bb65-m7lrq
Date: 24/Oct/2025:15:20:59 +0000
URI: /coffee?TEST=v2
Request ID: 5d26539722a330107c229135b0f56d0f
```

Access `coffee-v2` using an HTTP header
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee -H "version: v2"
```

Output should be similar to
```code
Server address: 10.0.156.80:8080
Server name: coffee-v2-685fd9bb65-m7lrq
Date: 24/Oct/2025:15:21:14 +0000
URI: /coffee
Request ID: bca9e322dd3c42f37fba0bbb4bf36094
```

Access `coffee-v3` using a query string
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee?queryRegex=query-a
```

Output should be similar to
```code
Server address: 10.0.156.101:8080
Server name: coffee-v3-7fb98466f-2dzqr
Date: 24/Oct/2025:15:21:26 +0000
URI: /coffee?queryRegex=query-a
Request ID: 6bbaa2a9612b82fc8ee8d4dd3e49a06b
```

Access `coffee-v3` using an HTTP header
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee -H "headerRegex: header-a"
```

Output should be similar to
```code
Server address: 10.0.156.101:8080
Server name: coffee-v3-7fb98466f-2dzqr
Date: 24/Oct/2025:15:21:40 +0000
URI: /coffee
Request ID: d1047da5f3873a0c854ec1e109a1d646
```

Access `tea` using `GET`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/tea
```

Output should be similar to
```code
Server address: 10.0.156.99:8080
Server name: tea-596697966f-hpxtc
Date: 24/Oct/2025:15:21:52 +0000
URI: /tea
Request ID: d8abee9b48b93c9f440d69a1240c5fc7
```

Access `tea` using `POST`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/tea -X POST
```

Output should be similar to
```code
Server address: 10.0.156.96:8080
Server name: tea-post-5647b8d885-jngtg
Date: 24/Oct/2025:15:22:03 +0000
URI: /tea
Request ID: 19f6f5f9f27c701f9a8bed30dcb80c74
```

Delete the lab

```code
kubectl delete -f .
```
