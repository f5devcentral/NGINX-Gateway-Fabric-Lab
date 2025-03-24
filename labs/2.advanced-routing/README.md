# Advanced routing using HTTP matching conditions

This use case shows how to publish two sample applications using HTTP matching conditions routing

Get NGINX Gateway Fabric Node IP, HTTP and HTTPS NodePorts
```code
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -n nginx-gateway -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc ngf-nginx-gateway-fabric -n nginx-gateway -o jsonpath='{.spec.ports[0].nodePort}'`
export HTTPS_PORT=`kubectl get svc ngf-nginx-gateway-fabric -n nginx-gateway -o jsonpath='{.spec.ports[1].nodePort}'`
```

Check NGINX Gateway Fabric IP address, HTTP and HTTPS ports
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT\nHTTPS port : $HTTPS_PORT"
```

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/1.advanced-routing
```

Create the gateway object
```code
kubectl apply -f 0.gateway.yaml
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS   PROGRAMMED   AGE
gateway   nginx             True         5s
```

Deploy two sample web applications
```code
kubectl apply -f 1.coffee.yaml
kubectl apply -f 2.tea.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                             READY   STATUS    RESTARTS   AGE
pod/coffee-v1-c48b96b65-2hmrj    1/1     Running   0          8s
pod/coffee-v2-685fd9bb65-mmpfr   1/1     Running   0          8s
pod/coffee-v3-7fb98466f-dzj59    1/1     Running   0          8s
pod/tea-596697966f-hsjg5         1/1     Running   0          5s
pod/tea-post-5647b8d885-jblbd    1/1     Running   0          6s

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/coffee-v1-svc   ClusterIP   10.102.194.199   <none>        80/TCP    8s
service/coffee-v2-svc   ClusterIP   10.111.207.205   <none>        80/TCP    8s
service/coffee-v3-svc   ClusterIP   10.104.112.139   <none>        80/TCP    8s
service/kubernetes      ClusterIP   10.96.0.1        <none>        443/TCP   38d
service/tea-post-svc    ClusterIP   10.100.126.195   <none>        80/TCP    6s
service/tea-svc         ClusterIP   10.107.201.2     <none>        80/TCP    5s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee-v1   1/1     1            1           8s
deployment.apps/coffee-v2   1/1     1            1           8s
deployment.apps/coffee-v3   1/1     1            1           8s
deployment.apps/tea         1/1     1            1           6s
deployment.apps/tea-post    1/1     1            1           6s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-v1-c48b96b65    1         1         1       8s
replicaset.apps/coffee-v2-685fd9bb65   1         1         1       8s
replicaset.apps/coffee-v3-7fb98466f    1         1         1       8s
replicaset.apps/tea-596697966f         1         1         1       6s
replicaset.apps/tea-post-5647b8d885    1         1         1       6s
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

Access `coffee-v1`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to
```code
Server address: 192.168.36.121:8080
Server name: coffee-v1-c48b96b65-2hmrj
Date: 24/Mar/2025:21:42:57 +0000
URI: /coffee
Request ID: 451c39b43214b1c6f4e67e1b7f4c1c79
```

Access `coffee-v2` using a query string
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee?TEST=v2
```

Output should be similar to
```code
Server address: 192.168.36.122:8080
Server name: coffee-v2-685fd9bb65-mmpfr
Date: 24/Mar/2025:21:45:47 +0000
URI: /coffee?TEST=v2
Request ID: d7329ba2172188751a4eb7a3ca5d6a61
```

Access `coffee-v2` using an HTTP header
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee -H "version: v2"
```

Output should be similar to
```code
Server address: 192.168.36.122:8080
Server name: coffee-v2-685fd9bb65-mmpfr
Date: 24/Mar/2025:21:47:04 +0000
URI: /coffee
Request ID: c09a40d327a3b106c0dd10bbe5c68907
```

Access `tea` using `GET`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/tea
```

Output should be similar to
```code
Server address: 192.168.36.116:8080
Server name: tea-596697966f-lk2gp
Date: 24/Mar/2025:21:08:23 +0000
URI: /tea
Request ID: 09603099f3ad42da023a6184019ffbb6
```

Access `tea` using `POST`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/tea -X POST
```

Output should be similar to
```code
Server address: 192.168.169.185:8080
Server name: tea-post-5647b8d885-jblbd
Date: 24/Mar/2025:21:43:38 +0000
URI: /tea
Request ID: 9648eefa26ddb5bb69eeac24525a1181
```

Delete the lab

```code
kubectl delete -f .
```
