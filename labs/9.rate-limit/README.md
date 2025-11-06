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
pod/coffee-676c9f8944-5xsfh   1/1     Running   0          3s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.100.251.237   <none>        80/TCP    3s
service/kubernetes   ClusterIP   10.100.0.1       <none>        443/TCP   24h

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   1/1     1            1           3s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-676c9f8944   1         1         1       3s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-67fb4cdf89-z9crl` is the NGINX Gateway Fabric dataplane pod
```
NAME                             READY   STATUS    RESTARTS   AGE
coffee-676c9f8944-5xsfh          1/1     Running   0          25s
gateway-nginx-67fb4cdf89-z9crl   0/1     Running   0          8s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS                                                                        PROGRAMMED   AGE
gateway   nginx   k8s-default-gatewayn-58be3b1053-5aa88d168e186302.elb.us-west-2.amazonaws.com   True         20s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
coffee          ClusterIP      10.100.251.237   <none>                                                                         80/TCP         52s
gateway-nginx   LoadBalancer   10.100.225.218   k8s-default-gatewayn-58be3b1053-5aa88d168e186302.elb.us-west-2.amazonaws.com   80:32760/TCP   35s
kubernetes      ClusterIP      10.100.0.1       <none>                                                                         443/TCP        24h
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
  Creation Timestamp:  2025-11-06T11:49:17Z
  Generation:          1
  Resource Version:    477282
  UID:                 bf9802ce-bc25-4d23-a4e9-6a5b287b5ea1
Spec:
  Snippets:
    Context:  http
    Value:    limit_req_zone \$binary_remote_addr zone=rate-limiting-sf:10m rate=2r/s;
    Context:  http.server.location
    Value:    limit_req zone=rate-limiting-sf nodelay;limit_req_status 429;
Status:
  Controllers:
    Conditions:
      Last Transition Time:  2025-11-06T11:49:17Z
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

Get NGINX Gateway Fabric dataplane loadbalancer DNS
```code
export NGF_DNS=`kubectl get svc gateway-nginx -o json|jq '.status.loadBalancer.ingress[0].hostname' -r`
```

AWS Elastic Load Balancer takes some minutes to register targets. Wait for it using
```code
aws elbv2 wait load-balancer-available --load-balancer-arns $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?DNSName==`'"$NGF_DNS"'`].LoadBalancerArn' --output text)
```

Check NGINX Gateway Fabric dataplane loadbalancer DNS
```code
echo -e "NGF address: $NGF_DNS"
```

Access the application once
```code
curl -i -H "Host: cafe.example.com" http://$NGF_DNS
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 06 Nov 2025 11:51:33 GMT
Content-Type: text/plain
Content-Length: 159
Connection: keep-alive
Expires: Thu, 06 Nov 2025 11:51:32 GMT
Cache-Control: no-cache

Server address: 192.168.120.146:8080
Server name: coffee-676c9f8944-5xsfh
Date: 06/Nov/2025:11:51:33 +0000
URI: /
Request ID: 83eecf4a040ef0b6252513917239c24a
```

Access the application twice
```code
curl -i -H "Host: cafe.example.com" http://$NGF_DNS; echo "---"; curl -i -H "Host: cafe.example.com" http://$NGF_DNS
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 06 Nov 2025 11:52:33 GMT
Content-Type: text/plain
Content-Length: 159
Connection: keep-alive
Expires: Thu, 06 Nov 2025 11:52:32 GMT
Cache-Control: no-cache

Server address: 192.168.120.146:8080
Server name: coffee-676c9f8944-5xsfh
Date: 06/Nov/2025:11:52:33 +0000
URI: /
Request ID: 8789c395f5c9af07fc6e74176d8a4459
---
HTTP/1.1 429 Too Many Requests
Server: nginx
Date: Thu, 06 Nov 2025 11:52:33 GMT
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
