# Basic URI-based routing

This use case shows how to publish two sample applications using URI-based routing

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
cd ~/NGINX-Gateway-Fabric-Lab/labs/1.basic-app
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
kubectl apply -f 1.cafe.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                          READY   STATUS    RESTARTS   AGE
pod/coffee-56b44d4c55-nm5rx   1/1     Running   0          8m39s
pod/tea-596697966f-lk2gp      1/1     Running   0          8m39s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.102.183.198   <none>        80/TCP    8m39s
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   38d
service/tea          ClusterIP   10.111.232.2     <none>        80/TCP    8m39s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   1/1     1            1           8m39s
deployment.apps/tea      1/1     1            1           8m39s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-56b44d4c55   1         1         1       8m39s
replicaset.apps/tea-596697966f      1         1         1       8m39s
```

Create the HTTP routes
```code
kubectl apply -f 2.httproute.yaml
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

Test application access: to access `coffee`
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to
```code
Server address: 192.168.36.115:8080
Server name: coffee-56b44d4c55-nm5rx
Date: 24/Mar/2025:21:08:19 +0000
URI: /coffee
Request ID: 5136f3dd98058fc9edcad13998902e79
```

To access `tea`
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

Delete the lab

```code
kubectl delete -f .
```
