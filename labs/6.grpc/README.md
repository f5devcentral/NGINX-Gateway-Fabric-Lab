# gRPC support

This use case shows how to manage gRPC traffic through NGINX Gateway Fabric

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
cd ~/NGINX-Gateway-Fabric-Lab/labs/6.grpc
```

Deploy the sample application
```code
kubectl apply -f 0.helloworld.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```code
NAME                                        READY   STATUS    RESTARTS   AGE
pod/coffee-56b44d4c55-vpgbc                 1/1     Running   0          18m
pod/grpc-infra-backend-v1-bc4bc48dc-4zjfd   1/1     Running   0          9s
pod/grpc-infra-backend-v2-67fd996d5-5jn59   1/1     Running   0          9s

NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/coffee                  ClusterIP   10.105.208.61    <none>        80/TCP     18m
service/grpc-infra-backend-v1   ClusterIP   10.110.208.145   <none>        8080/TCP   9s
service/grpc-infra-backend-v2   ClusterIP   10.99.196.64     <none>        8080/TCP   9s
service/kubernetes              ClusterIP   10.96.0.1        <none>        443/TCP    38d

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee                  1/1     1            1           18m
deployment.apps/grpc-infra-backend-v1   1/1     1            1           9s
deployment.apps/grpc-infra-backend-v2   1/1     1            1           9s

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-56b44d4c55                 1         1         1       18m
replicaset.apps/grpc-infra-backend-v1-bc4bc48dc   1         1         1       9s
replicaset.apps/grpc-infra-backend-v2-67fd996d5   1         1         1       9s
```

Create the gateway object and gRPC route based on exact method matching
```code
kubectl apply -f 1.grpcroute-exactmethod.yaml
```

Test the application
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "exact"}' ${NGF_IP}:${HTTP_PORT} helloworld.Greeter/SayHello
```

Output should be
```code
{
  "message": "Hello exact"
}
```

Remove the exact method matching gRPC route
```code
kubectl delete -f 1.grpcroute-exactmethod.yaml
```

Create the hostname-based gRPC route
```code
kubectl apply -f 2.grpcroute-hostname.yaml
```

Test the application sending a request to `bar.com`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "bar server"}' ${NGF_IP}:${HTTP_PORT} helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v1`
```code
kubectl logs -l app=grpc-infra-backend-v1
```

Output should be similar to
```code
2025/03/24 23:16:06 server listening at [::]:50051
2025/03/24 23:19:08 Received: bar server
```

Test the application sending a request to `foo.bar.com`
```code
grpcurl -plaintext -proto grpc.proto -authority foo.bar.com -d '{"name": "bar server"}' ${NGF_IP}:${HTTP_PORT} helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v2`
```code
kubectl logs -l app=grpc-infra-backend-v2
```

Output should be similar to
```code
2025/03/24 23:16:08 server listening at [::]:50051
2025/03/24 23:24:15 Received: bar server
```

Remove the hostname-based gRPC route
```code
kubectl delete -f 2.grpcroute-hostname.yaml
```

Create the headers-based gRPC route
```code
kubectl apply -f 3.grpcroute-header.yaml
```

Test the application sending a request with HTTP header `version: one`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "version one"}' -H 'version: one' ${NGF_IP}:${HTTP_PORT} helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v1`
```code
kubectl logs -l app=grpc-infra-backend-v1
```

Output should be similar to
```code
2025/03/24 23:27:11 Received: version one
```

Test the application sending a request with HTTP header `version: two`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "version two"}' -H 'version: two' ${NGF_IP}:${HTTP_PORT} helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v2`
```code
kubectl logs -l app=grpc-infra-backend-v2
```

Output should be similar to
```code
2025/03/24 23:29:09 Received: version two
```

Delete the lab

```code
kubectl delete -f .
```
