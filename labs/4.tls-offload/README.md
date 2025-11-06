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
pod/coffee-676c9f8944-rk4rb   1/1     Running   0          25s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.100.170.45   <none>        80/TCP    25s
service/kubernetes   ClusterIP   10.100.0.1      <none>        443/TCP   5h1m

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   1/1     1            1           25s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-676c9f8944   1         1         1       25s
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
cafe-nginx-556b6f55cd-q7p2m   0/1     Running   0          7s
coffee-676c9f8944-rk4rb       1/1     Running   0          2m23s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME   CLASS   ADDRESS                                                                        PROGRAMMED   AGE
cafe   nginx   k8s-default-cafengin-4cdfc6c098-7ce79469e7c9a664.elb.us-west-2.amazonaws.com   True         23s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`cafe-nginx` is the NGINX Gateway Fabric dataplane service
```
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)                      AGE
cafe-nginx   LoadBalancer   10.100.176.207   k8s-default-cafengin-4cdfc6c098-7ce79469e7c9a664.elb.us-west-2.amazonaws.com   80:31968/TCP,443:30636/TCP   42s
coffee       ClusterIP      10.100.170.45    <none>                                                                         80/TCP                       2m58s
kubernetes   ClusterIP      10.100.0.1       <none>                                                                         443/TCP                      5h3m
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

Get NGINX Gateway Fabric dataplane loadbalancer DNS
```code
export NGF_DNS=`kubectl get svc cafe-nginx -o json|jq '.status.loadBalancer.ingress[0].hostname' -r`
```

AWS Elastic Load Balancer takes some minutes to register targets. Wait for it using
```code
aws elbv2 wait load-balancer-available --load-balancer-arns $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?DNSName==`'"$NGF_DNS"'`].LoadBalancerArn' --output text)
```

Check NGINX Gateway Fabric dataplane loadbalancer DNS
```code
echo -e "NGF address: $NGF_DNS"
```

Access `coffee` using `HTTP`
```code
curl -H "Host: cafe.example.com" -i http://$NGF_DNS/coffee
```

Output should be similar to
```code
HTTP/1.1 302 Moved Temporarily
Server: nginx
Date: Wed, 05 Nov 2025 16:54:38 GMT
Content-Type: text/html
Content-Length: 138
Connection: keep-alive
Location: https://k8s-default-cafengin-4cdfc6c098-7ce79469e7c9a664.elb.us-west-2.amazonaws.com/coffee

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
curl -H "Host: cafe.example.com" -i -k https://$NGF_DNS/coffee
```

Output should be similar to
```code
HTTP/2 200 
server: nginx
date: Wed, 05 Nov 2025 16:55:24 GMT
content-type: text/plain
content-length: 165
expires: Wed, 05 Nov 2025 16:55:23 GMT
cache-control: no-cache

Server address: 192.168.120.147:8080
Server name: coffee-676c9f8944-rk4rb
Date: 05/Nov/2025:16:55:24 +0000
URI: /coffee
Request ID: e2dd2ac7da2898e06ebd4d5c4195c052
```

Delete the lab

```code
kubectl delete -f .
```
