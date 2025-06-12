# gRPC support

This use case shows how to manage gRPC traffic through NGINX Gateway Fabric

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
pod/grpc-infra-backend-v1-bc4bc48dc-jkwfx   1/1     Running   0          26s
pod/grpc-infra-backend-v2-67fd996d5-qn4sp   1/1     Running   0          26s

NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/grpc-infra-backend-v1   ClusterIP   10.109.98.121   <none>        8080/TCP   27s
service/grpc-infra-backend-v2   ClusterIP   10.108.28.155   <none>        8080/TCP   26s
service/kubernetes              ClusterIP   10.96.0.1       <none>        443/TCP    268d

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/grpc-infra-backend-v1   1/1     1            1           27s
deployment.apps/grpc-infra-backend-v2   1/1     1            1           26s

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/grpc-infra-backend-v1-bc4bc48dc   1         1         1       26s
replicaset.apps/grpc-infra-backend-v2-67fd996d5   1         1         1       26s
```

Create the gateway object and gRPC route based on exact method matching. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.grpcroute-exactmethod.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`same-namespace-nginx-8c55bff94-mxmpx` pod is the NGINX Gateway Fabric dataplane
```
NAME                                    READY   STATUS    RESTARTS   AGE
grpc-infra-backend-v1-bc4bc48dc-jkwfx   1/1     Running   0          75s
grpc-infra-backend-v2-67fd996d5-qn4sp   1/1     Running   0          75s
same-namespace-nginx-8c55bff94-mxmpx    1/1     Running   0          9s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME             CLASS   ADDRESS          PROGRAMMED   AGE
same-namespace   nginx   10.110.235.199   True         63s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`same-namespace-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
grpc-infra-backend-v1   ClusterIP   10.109.98.121    <none>        8080/TCP       2m21s
grpc-infra-backend-v2   ClusterIP   10.108.28.155    <none>        8080/TCP       2m20s
kubernetes              ClusterIP   10.96.0.1        <none>        443/TCP        268d
same-namespace-nginx    NodePort    10.110.235.199   <none>        80:32081/TCP   75s
```

Check the gRPC routes
```code
kubectl get grpcroutes
```

Output should be similar to
```code
NAME             HOSTNAMES   AGE
exact-matching               2m41s
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc same-namespace-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
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
C```code
kubectl delete -f 1.grpcroute-exactmethod.yaml
```

Create the hostname-based gRPC route
```code
kubectl apply -f 2.grpcroute-hostname.yaml
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc grpcroute-listener-hostname-matching-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
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
2025/06/12 11:27:59 server listening at [::]:50051
2025/06/12 11:37:05 Received: exact
2025/06/12 11:39:48 Received: bar server
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
2025/06/12 11:28:02 server listening at [::]:50051
2025/06/12 11:40:13 Received: bar server
```

Remove the hostname-based gRPC route
```code
kubectl delete -f 2.grpcroute-hostname.yaml
```

Create the headers-based gRPC route
```code
kubectl apply -f 3.grpcroute-header.yaml
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc same-namespace-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```
 
Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
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
2025/06/12 11:27:59 server listening at [::]:50051
2025/06/12 11:37:05 Received: exact
2025/06/12 11:39:48 Received: bar server
2025/06/12 11:41:52 Received: version one
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
2025/06/12 11:28:02 server listening at [::]:50051
2025/06/12 11:40:13 Received: bar server
2025/06/12 11:42:12 Received: version two
```

Delete the lab

```code
kubectl delete -f .
```
