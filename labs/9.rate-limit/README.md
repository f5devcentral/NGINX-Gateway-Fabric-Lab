# Enforcing Rate Limiting

This use case shows how to set rate limits for HTTP and gRPC routes

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/9.rate-limit
```

Deploy the sample applications
```code
kubectl apply -f 0.apps.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                                READY   STATUS    RESTARTS   AGE
pod/coffee-56b44d4c55-gdxkc         1/1     Running   0          41s
pod/grpc-backend-68ff5cb6c9-c565t   1/1     Running   0          40s

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
service/coffee         ClusterIP   10.97.137.125   <none>        80/TCP            41s
service/grpc-backend   ClusterIP   10.109.137.38   <none>        8080/TCP          40s
service/kubernetes     ClusterIP   10.96.0.1       <none>        443/TCP           506d
service/nginx-svc      ClusterIP   10.101.127.99   <none>        80/TCP,8080/TCP   13d

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee         1/1     1            1           41s
deployment.apps/grpc-backend   1/1     1            1           40s

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-56b44d4c55         1         1         1       41s
replicaset.apps/grpc-backend-68ff5cb6c9   1         1         1       40s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace and a `RateLimitPolicy`
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```code
kubectl get pods
```

`gateway-nginx-7b79d89c-p8v8v` is the NGINX Gateway Fabric dataplane pod
```code
NAME                            READY   STATUS    RESTARTS   AGE
coffee-56b44d4c55-gdxkc         1/1     Running   0          89s
gateway-nginx-7b79d89c-p8v8v    1/1     Running   0          14s
grpc-backend-68ff5cb6c9-c565t   1/1     Running   0          88s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS       PROGRAMMED   AGE
gateway   nginx   10.97.59.36   True         31s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
coffee          ClusterIP   10.97.137.125   <none>        80/TCP            13m
gateway-nginx   NodePort    10.97.59.36     <none>        80:32700/TCP      12m
grpc-backend    ClusterIP   10.109.137.38   <none>        8080/TCP          13m
kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP           506d
nginx-svc       ClusterIP   10.101.127.99   <none>        80/TCP,8080/TCP   13d
```

Check the rate limit policy set at the gateway level
```code
kubectl get ratelimitpolicy
```

Output should be similar to
```code
NAME                 AGE
gateway-rate-limit   107s
```

Describe the `RateLimitPolicy`: it enforces a rate limit of 10 requests per second at the gateway level
```code
kubectl describe RateLimitPolicy gateway-rate-limit
```

Output should be similar to
```code
Name:         gateway-rate-limit
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         RateLimitPolicy
Metadata:
  Creation Timestamp:  2026-02-05T17:27:25Z
  Generation:          1
  Resource Version:    94045758
  UID:                 dadb9661-dde0-429f-986a-67b797e4f97a
Spec:
  Rate Limit:
    Local:
      Rules:
        Key:        $binary_remote_addr
        Rate:       10r/s
        Zone Size:  10m
  Target Refs:
    Group:  gateway.networking.k8s.io
    Kind:   Gateway
    Name:   gateway
Status:
  Ancestors:
    Ancestor Ref:
      Group:      gateway.networking.k8s.io
      Kind:       Gateway
      Name:       gateway
      Namespace:  default
    Conditions:
      Last Transition Time:  2026-02-05T17:27:26Z
      Message:               The Policy is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
```

Create the HTTP and gRPC routes
```code
kubectl apply -f 2.routes.yaml
```

Check the HTTP route
```code
kubectl get httproute
```

Output should be similar to
```code
NAME     HOSTNAMES              AGE
coffee   ["cafe.example.com"]   82s
```

Check the gRPC route

```code
kubectl get grpcroute
```

Output should be similar to
```code
NAME         HOSTNAMES              AGE
grpc-route   ["grpc.example.com"]   113s
```

Create the `RateLimitPolicy` attached to the coffee `HTTPRoute` and the grpc-route `GRPCRoute`
```code
kubectl apply -f 3.route-ratelimit.yaml
```

Check all rate limit policies
```code
kubectl get ratelimitpolicy
```

Output should be similar to
```code
NAME                 AGE
gateway-rate-limit   8m24s
route-rate-limit     81s
```

Describe the `RateLimitPolicy` applied at the `HTTPRoute` and `GRPCRoute` level
```code
kubectl describe ratelimitpolicy route-rate-limit
```

Output should be similar to
```code
Name:         route-rate-limit
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         RateLimitPolicy
Metadata:
  Creation Timestamp:  2026-02-05T17:34:28Z
  Generation:          1
  Resource Version:    94046926
  UID:                 2edd598e-fdc2-4c67-8742-13d409c8137d
Spec:
  Rate Limit:
    Local:
      Rules:
        Burst:      0
        Key:        $binary_remote_addr
        Rate:       1r/s
        Zone Size:  10m
  Target Refs:
    Group:  gateway.networking.k8s.io
    Kind:   HTTPRoute
    Name:   coffee
    Group:  gateway.networking.k8s.io
    Kind:   GRPCRoute
    Name:   grpc-route
Status:
  Ancestors:
    Ancestor Ref:
      Group:      gateway.networking.k8s.io
      Kind:       HTTPRoute
      Name:       coffee
      Namespace:  default
    Conditions:
      Last Transition Time:  2026-02-05T17:34:29Z
      Message:               The Policy is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
    Ancestor Ref:
      Group:      gateway.networking.k8s.io
      Kind:       GRPCRoute
      Name:       grpc-route
      Namespace:  default
    Conditions:
      Last Transition Time:  2026-02-05T17:34:29Z
      Message:               The Policy is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
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

Access the HTTP application once
```code
curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 05 Feb 2026 17:41:00 GMT
Content-Type: text/plain
Content-Length: 162
Connection: keep-alive
Expires: Thu, 05 Feb 2026 17:40:59 GMT
Cache-Control: no-cache

Server address: 10.0.156.109:8080
Server name: coffee-56b44d4c55-gdxkc
Date: 05/Feb/2026:17:41:00 +0000
URI: /coffee
Request ID: 03f15068dc0890cc33ac117322041ecc
```

Access the application twice
```code
curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee;echo "---";curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 05 Feb 2026 17:42:10 GMT
Content-Type: text/plain
Content-Length: 162
Connection: keep-alive
Expires: Thu, 05 Feb 2026 17:42:09 GMT
Cache-Control: no-cache

Server address: 10.0.156.109:8080
Server name: coffee-56b44d4c55-gdxkc
Date: 05/Feb/2026:17:42:10 +0000
URI: /coffee
Request ID: 19f252331dad133413ca1c7a395ab630
---
HTTP/1.1 429 Too Many Requests
Server: nginx
Date: Thu, 05 Feb 2026 17:42:10 GMT
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

Access the gRPC application once
```code
grpcurl -plaintext -proto grpc.proto -authority grpc.example.com -d '{"name": "exact"}' $NGF_IP:$HTTP_PORT helloworld.Greeter/SayHello
```

Output should be similar to
```code
{
  "message": "Hello exact"
}
```

Access the gRPC application twice
```code
grpcurl -plaintext -proto grpc.proto -authority grpc.example.com -d '{"name": "exact"}' $NGF_IP:$HTTP_PORT helloworld.Greeter/SayHello;echo "---";grpcurl -plaintext -proto grpc.proto -authority grpc.example.com -d '{"name": "exact"}' $NGF_IP:$HTTP_PORT helloworld.Greeter/SayHello
```

Output should be similar to
```code
{
  "message": "Hello exact"
}
---
ERROR:
  Code: Unknown
  Message: unexpected HTTP status code received from server: 204 (No Content)
```

Delete the lab

```code
kubectl delete -f .
```
