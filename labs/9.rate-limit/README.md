# Enforcing JWT authentication using SnippetsFilter

This use case shows how to enforce JWT authentication through SnippetsFilter

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/9.rate-limit
```

Deploy the sample application
```code
kubectl apply -f 0.coffee.yaml
```

Verify that the pod is in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                          READY   STATUS    RESTARTS   AGE
pod/coffee-56b44d4c55-g9gtj   1/1     Running   0          3s

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.107.232.5   <none>        80/TCP    3s
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP   385d

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   1/1     1            1           3s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-56b44d4c55   1         1         1       3s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-56678b747f-jlcp4` is the NGINX Gateway Fabric dataplane pod
```
NAME                             READY   STATUS    RESTARTS   AGE
coffee-56b44d4c55-t8lkr          1/1     Running   0          16s
gateway-nginx-56678b747f-jlcp4   1/1     Running   0          15s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS        PROGRAMMED   AGE
gateway   nginx   10.106.69.99   True         33s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
coffee          ClusterIP   10.110.225.51   <none>        80/TCP         55s
gateway-nginx   NodePort    10.106.69.99    <none>        80:31458/TCP   45s
kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP        386d
```

Create the SnippetsFilter to set up the FastCGI configuration snippets
```code
kubectl apply -f 2.snippetsfilter-ratelimit.yaml
```

Check the SnippetsFilter
```code
kubectl describe snippetsfilter ratelimit
```

Output should be similar to
```code
Name:         ratelimit
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         SnippetsFilter
Metadata:
  Creation Timestamp:  2025-10-08T08:42:51Z
  Generation:          1
  Resource Version:    66775595
  UID:                 43cf9417-f36e-4039-a01b-73c92a138f22
Spec:
  Snippets:
    Context:  http
    Value:    limit_req_zone \$binary_remote_addr zone=rate-limiting-sf:10m rate=2r/s;
    Context:  http.server.location
    Value:    limit_req zone=rate-limiting-sf nodelay;limit_req_status 429;
Status:
  Controllers:
    Conditions:
      Last Transition Time:  2025-10-08T08:42:51Z
      Message:               SnippetsFilter is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
```

Create the HTTP route
```code
kubectl apply -f 3.httproute.yaml
```

Check the HTTP route that references the SnippetsFilter
```code
kubectl get httproute
```

Output should be similar to
```code
NAME     HOSTNAMES              AGE
coffee   ["cafe.example.com"]   4s
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc gateway-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

Access the application once
```code
curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Wed, 08 Oct 2025 08:43:48 GMT
Content-Type: text/plain
Content-Length: 155
Connection: keep-alive
Expires: Wed, 08 Oct 2025 08:43:47 GMT
Cache-Control: no-cache

Server address: 10.0.156.89:8080
Server name: coffee-56b44d4c55-t8lkr
Date: 08/Oct/2025:08:43:48 +0000
URI: /
Request ID: 5672062ef741e5b3a7ff786ae3fbdb5f
```

Access the application twice
```code
curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT;echo "---";curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Wed, 08 Oct 2025 08:45:33 GMT
Content-Type: text/plain
Content-Length: 155
Connection: keep-alive
Expires: Wed, 08 Oct 2025 08:45:32 GMT
Cache-Control: no-cache

Server address: 10.0.156.89:8080
Server name: coffee-56b44d4c55-t8lkr
Date: 08/Oct/2025:08:45:33 +0000
URI: /
Request ID: 7b61c81c0aceda518decbb3f194bfd18
---
HTTP/1.1 429 Too Many Requests
Server: nginx
Date: Wed, 08 Oct 2025 08:45:33 GMT
Content-Type: text/html
Content-Length: 162
Connection: keep-alive

<html>
<head><title>429 Too Many Requests</title></head>
<body>
<center><h1>429 Too Many Requests</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

Delete the lab

```code
kubectl delete -f .
```
