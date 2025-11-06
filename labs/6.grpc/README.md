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
NAME                                         READY   STATUS    RESTARTS   AGE
pod/grpc-infra-backend-v1-688b5bfbd8-ltqxf   1/1     Running   0          14s
pod/grpc-infra-backend-v2-6d9fbc7878-mglcn   1/1     Running   0          14s

NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/grpc-infra-backend-v1   ClusterIP   10.100.140.200   <none>        8080/TCP   14s
service/grpc-infra-backend-v2   ClusterIP   10.100.82.44     <none>        8080/TCP   14s
service/kubernetes              ClusterIP   10.100.0.1       <none>        443/TCP    23h

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/grpc-infra-backend-v1   1/1     1            1           14s
deployment.apps/grpc-infra-backend-v2   1/1     1            1           14s

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/grpc-infra-backend-v1-688b5bfbd8   1         1         1       15s
replicaset.apps/grpc-infra-backend-v2-6d9fbc7878   1         1         1       15s
```

Create the gateway object and gRPC route based on exact method matching. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.grpcroute-exactmethod.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`same-namespace-nginx-575c9879df-cdhwk` is the NGINX Gateway Fabric dataplane
```
NAME                                     READY   STATUS    RESTARTS   AGE
grpc-infra-backend-v1-688b5bfbd8-ltqxf   1/1     Running   0          2m24s
grpc-infra-backend-v2-6d9fbc7878-mglcn   1/1     Running   0          2m24s
same-namespace-nginx-575c9879df-cdhwk    1/1     Running   0          14s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME             CLASS   ADDRESS                                                                        PROGRAMMED   AGE
same-namespace   nginx   k8s-default-samename-cda6677b89-e2322a979b39561b.elb.us-west-2.amazonaws.com   True         27s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`same-namespace-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME                    TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
grpc-infra-backend-v1   ClusterIP      10.100.140.200   <none>                                                                         8080/TCP       2m47s
grpc-infra-backend-v2   ClusterIP      10.100.82.44     <none>                                                                         8080/TCP       2m47s
kubernetes              ClusterIP      10.100.0.1       <none>                                                                         443/TCP        23h
same-namespace-nginx    LoadBalancer   10.100.219.64    k8s-default-samename-cda6677b89-e2322a979b39561b.elb.us-west-2.amazonaws.com   80:31786/TCP   37s
```

Check the gRPC routes
```code
kubectl get grpcroutes
```

Output should be similar to
```code
NAME             HOSTNAMES   AGE
exact-matching               47s
```

Get NGINX Gateway Fabric dataplane loadbalancer DNS
```code
export NGF_DNS=`kubectl get svc same-namespace-nginx -o json|jq '.status.loadBalancer.ingress[0].hostname' -r`
```

AWS Elastic Load Balancer takes some minutes to register targets. Wait for it using
```code
aws elbv2 wait load-balancer-available --load-balancer-arns $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?DNSName==`'"$NGF_DNS"'`].LoadBalancerArn' --output text)
```

Check NGINX Gateway Fabric dataplane loadbalancer DNS
```code
echo -e "NGF address: $NGF_DNS"
```

Install gRPCurl command-line interface command
```code
sudo yum -y install https://github.com/fullstorydev/grpcurl/releases/download/v1.9.3/grpcurl_1.9.3_linux_amd64.rpm
```

Test the application
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "exact"}' $NGF_DNS:80 helloworld.Greeter/SayHello
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

Get NGINX Gateway Fabric dataplane loadbalancer DNS
```code
export NGF_DNS=`kubectl get svc grpcroute-listener-hostname-matching-nginx -o json|jq '.status.loadBalancer.ingress[0].hostname' -r`
```

AWS Elastic Load Balancer takes some minutes to register targets. Wait for it using
```code
aws elbv2 wait load-balancer-available --load-balancer-arns $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?DNSName==`'"$NGF_DNS"'`].LoadBalancerArn' --output text)
```

Check NGINX Gateway Fabric dataplane loadbalancer DNS
```code
echo -e "NGF address: $NGF_DNS"
```

Test the application sending a request to `bar.com`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "bar server"}' $NGF_DNS:80 helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v1`
```code
kubectl logs -l app=grpc-infra-backend-v1
```

Output should be similar to
```code
2025/11/06 10:47:20 server listening at [::]:50051
2025/11/06 10:55:01 Received: exact
2025/11/06 11:00:30 Received: bar server
```

Test the application sending a request to `foo.bar.com`
```code
grpcurl -plaintext -proto grpc.proto -authority foo.bar.com -d '{"name": "bar server"}' $NGF_DNS:80 helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v2`
```code
kubectl logs -l app=grpc-infra-backend-v2
```

Output should be similar to
```code
2025/11/06 10:47:20 server listening at [::]:50051
2025/11/06 11:00:54 Received: bar server
```

Remove the hostname-based gRPC route
```code
kubectl delete -f 2.grpcroute-hostname.yaml
```

Create the headers-based gRPC route
```code
kubectl apply -f 3.grpcroute-header.yaml
```

Get NGINX Gateway Fabric dataplane loadbalancer DNS
```code
export NGF_DNS=`kubectl get svc same-namespace-nginx -o json|jq '.status.loadBalancer.ingress[0].hostname' -r`
```

AWS Elastic Load Balancer takes some minutes to register targets. Wait for it using
```code
aws elbv2 wait load-balancer-available --load-balancer-arns $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?DNSName==`'"$NGF_DNS"'`].LoadBalancerArn' --output text)
```

Check NGINX Gateway Fabric dataplane loadbalancer DNS
```code
echo -e "NGF address: $NGF_DNS"
```

Test the application sending a request with HTTP header `version: one`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "version one"}' -H 'version: one' $NGF_DNS:80 helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v1`
```code
kubectl logs -l app=grpc-infra-backend-v1
```

Output should be similar to
```code
2025/11/06 10:47:20 server listening at [::]:50051
2025/11/06 10:55:01 Received: exact
2025/11/06 11:00:30 Received: bar server
2025/11/06 11:04:28 Received: version one
```

Test the application sending a request with HTTP header `version: two`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "version two"}' -H 'version: two' $NGF_DNS:80 helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v2`
```code
kubectl logs -l app=grpc-infra-backend-v2
```

Output should be similar to
```code
2025/11/06 10:47:20 server listening at [::]:50051
2025/11/06 11:00:54 Received: bar server
2025/11/06 11:05:28 Received: version two
```

Test the application sending a request with HTTP header `regexHeader: grpc-header-a`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "grpc-header-a"}' -H 'grpcRegex: grpc-header-a' $NGF_DNS:80 helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-2`
```code
kubectl logs -l app=grpc-infra-backend-v2
```

Output should be similar to
```code
2025/09/18 22:24:44 server listening at [::]:50051
2025/09/18 22:28:45 Received: bar server
2025/09/18 22:29:53 Received: version two
2025/09/18 22:34:08 Received: grpc-header-a
```

Test the application sending a request with HTTP header `color: blue`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "blue 1"}' -H 'color: blue' $NGF_DNS:80 helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v1`
```code
kubectl logs -l app=grpc-infra-backend-v1
```

Output should be similar to
```code
2025/11/06 10:47:20 server listening at [::]:50051
2025/11/06 10:55:01 Received: exact
2025/11/06 11:00:30 Received: bar server
2025/11/06 11:04:28 Received: version one
2025/11/06 11:06:55 Received: blue 1
```


Test the application sending a request with HTTP header `color: red`
```code
grpcurl -plaintext -proto grpc.proto -authority bar.com -d '{"name": "red 2"}' -H 'color: red' $NGF_DNS:80 helloworld.Greeter/SayHello
```

The request has been routed to pod `grpc-infra-backend-v2`
```code
kubectl logs -l app=grpc-infra-backend-v2
```

Output should be similar to
```code
2025/11/06 10:47:20 server listening at [::]:50051
2025/11/06 11:00:54 Received: bar server
2025/11/06 11:05:28 Received: version two
2025/11/06 11:07:29 Received: red 2
```

Delete the lab

```code
kubectl delete -f .
```
