# TLS offload

This use case shows how to apply TLS offload and HTTP-to-HTTPS redirection

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/4.tls-offload
```

Create the certificate/key pair and the `ReferenceGrant` object
```code
kubectl apply -f 0.certificate.yaml
```

Deploy the sample web applications
```code
kubectl apply -f 1.coffee.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                          READY   STATUS    RESTARTS   AGE
pod/coffee-56b44d4c55-jdst2   1/1     Running   0          3s

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.101.48.47   <none>        80/TCP    3s
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP   268d

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   1/1     1            1           3s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-56b44d4c55   1         1         1       3s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 2.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`cafe-nginx-758ff7574c-kpbqx` pod is the NGINX Gateway Fabric dataplane
```
NAME                          READY   STATUS    RESTARTS   AGE
cafe-nginx-758ff7574c-kpbqx   1/1     Running   0          24s
coffee-56b44d4c55-jdst2       1/1     Running   0          57s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME   CLASS   ADDRESS         PROGRAMMED   AGE
cafe   nginx   192.168.2.210   True         2s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`cafe-nginx` is the NGINX Gateway Fabric dataplane service
```
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                      AGE
cafe-nginx   LoadBalancer   10.101.91.76    192.168.2.210   80:31018/TCP,443:32252/TCP   5s
coffee       ClusterIP      10.96.182.118   <none>          80/TCP                       5s
kubernetes   ClusterIP      10.96.0.1       <none>          443/TCP                      402d
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

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get svc cafe-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
export HTTP_PORT=`kubectl get svc cafe-nginx -o jsonpath='{.spec.ports[0].targetPort}'`
export HTTPS_PORT=`kubectl get svc cafe-nginx -o jsonpath='{.spec.ports[1].targetPort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT\nHTTPS port : $HTTPS_PORT"
```

Access `coffee` using `HTTP`
```code
curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to
```code
HTTP/1.1 302 Moved Temporarily
Server: nginx
Date: Thu, 12 Jun 2025 11:19:04 GMT
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
Server address: 10.0.156.120:8080
Server name: coffee-56b44d4c55-jdst2
Date: 12/Jun/2025:11:19:24 +0000
URI: /coffee
Request ID: 6cb931a24c1c1bbff763d5ba7481a2f3
```

Delete the lab

```code
kubectl delete -f .
```
