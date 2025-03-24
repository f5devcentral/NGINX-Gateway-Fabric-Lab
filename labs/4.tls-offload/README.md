# TLS offload

This use case shows how to apply TLS offload and HTTP-to-HTTPS redirection

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
cd ~/NGINX-Gateway-Fabric-Lab/labs/4.tls-offload
```

Create the certificate/key pair and the `ReferenceGrant` object
```code
kubectl apply -f 0.certificate.yaml
```

Create the gateway object
```code
kubectl apply -f 1.gateway.yaml
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME   CLASS   ADDRESS   PROGRAMMED   AGE
cafe   nginx             True         3s
```

Deploy the sample web applications
```code
kubectl apply -f 2.coffee.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                          READY   STATUS    RESTARTS   AGE
pod/coffee-56b44d4c55-mhnth   1/1     Running   0          4s

NAME                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.98.90.73   <none>        80/TCP    4s
service/kubernetes   ClusterIP   10.96.0.1     <none>        443/TCP   38d

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   1/1     1            1           4s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-56b44d4c55   1         1         1       4s
```

Create the HTTP routes
```code
kubectl apply -f 3.httproute.yaml
```

Check the HTTP routes
```code
kubectl get httproute
```

Output should be similar to
```code
NAME                HOSTNAMES              AGE
cafe-tls-redirect   ["cafe.example.com"]   4s
coffee              ["cafe.example.com"]   4s
```

Access `coffee` using `HTTP`
```code
curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to
```code
HTTP/1.1 302 Moved Temporarily
Server: nginx
Date: Mon, 24 Mar 2025 22:07:33 GMT
Content-Type: text/html
Content-Length: 138
Connection: keep-alive
Location: https://cafe.example.com/coffee

<html>
<head><title>302 Found</title></head>
<body>
<center><h1>302 Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

Access `coffee` using `HTTPS`
```code
curl -k --resolve cafe.example.com:$HTTPS_PORT:$NGF_IP https://cafe.example.com:$HTTPS_PORT/coffee
```

Output should be similar to
```code
Server address: 192.168.36.124:8080
Server name: coffee-56b44d4c55-mhnth
Date: 24/Mar/2025:22:08:55 +0000
URI: /coffee
Request ID: 5c73de2ddd40965aee71d1518b21923f
```

Delete the lab

```code
kubectl delete -f .
```
