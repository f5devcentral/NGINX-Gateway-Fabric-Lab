# Modify HTTP request and response headers

This use case shows how to modify HTTP headers

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/3.http-headers
```

Deploy the sample application
```code
kubectl apply -f 0.app.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                           READY   STATUS    RESTARTS   AGE
pod/headers-85c697d5fb-f9ld7   1/1     Running   0          6s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/headers      ClusterIP   10.100.169.23   <none>        80/TCP    6s
service/kubernetes   ClusterIP   10.100.0.1      <none>        443/TCP   4h32m

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/headers   1/1     1            1           6s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/headers-85c697d5fb   1         1         1       6s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-c9bcdf4d4-j9pw5` pod is the NGINX Gateway Fabric dataplane
```code
NAME                             READY   STATUS    RESTARTS   AGE
gateway-nginx-67fb4cdf89-tn957   1/1     Running   0          15s
headers-85c697d5fb-789xs         1/1     Running   0          27s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS                                                                        PROGRAMMED   AGE
gateway   nginx   k8s-default-gatewayn-3f1e234d08-581a2f8bb7a5a6ce.elb.us-west-2.amazonaws.com   True         28s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
gateway-nginx   LoadBalancer   10.100.254.177   k8s-default-gatewayn-3f1e234d08-581a2f8bb7a5a6ce.elb.us-west-2.amazonaws.com   80:32692/TCP   40s
headers         ClusterIP      10.100.148.132   <none>                                                                         80/TCP         52s
kubernetes      ClusterIP      10.100.0.1       <none>                                                                         443/TCP        22h
```

Create the HTTP routes
```code
kubectl apply -f 2.httproute.yaml
```

Check the HTTP routes
```code
kubectl get httproute
```

Output should be similar to (empty value on HOSTNAME means the routes are not filtering by it)
```code
NAME      HOSTNAMES              AGE
headers   ["echo.example.com"]   5s
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

Access the test application
```code
curl -H "Host: echo.example.com" -i http://$NGF_DNS/nofilter -H "My-Cool-Header:my-client-value" -H "My-Overwrite-Header:dont-see-this"
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 06 Nov 2025 10:44:27 GMT
Content-Type: text/plain
Content-Length: 454
Connection: keep-alive

Headers:
  header 'Host' is 'echo.example.com'
  header 'X-Forwarded-For' is '192.168.8.127'
  header 'X-Real-IP' is '192.168.8.127'
  header 'X-Forwarded-Proto' is 'http'
  header 'X-Forwarded-Host' is 'echo.example.com'
  header 'X-Forwarded-Port' is '80'
  header 'Connection' is 'close'
  header 'User-Agent' is 'curl/8.11.1'
  header 'Accept' is '*/*'
  header 'My-Cool-Header' is 'my-client-value'
  header 'My-Overwrite-Header' is 'dont-see-this'
```

Request headers of note:

- User-Agent header is present.
- The header My-Cool-header has its single my-client-value value.
- The header My-Overwrite-Header has its single dont-see-this value.
- Accept-encoding header is not present.

Response Headers `X-Header-Set` and `X-Header-Add` are not present.


Access the test application via filters route
```code
curl -H "Host: echo.example.com" -i http://$NGF_DNS/headers -H "My-Cool-Header:my-client-value" -H "My-Overwrite-Header:dont-see-this"
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 06 Nov 2025 10:44:59 GMT
Content-Type: text/plain
Content-Length: 491
Connection: keep-alive
X-Header-Add: this-is-the-appended-value
X-Header-Set: overwritten-value

Headers:
  header 'Accept-Encoding' is 'compress'
  header 'My-cool-header' is 'my-client-value,this-is-an-appended-value'
  header 'My-Overwrite-Header' is 'this-is-the-only-value'
  header 'Host' is 'echo.example.com'
  header 'X-Forwarded-For' is '192.168.8.127'
  header 'X-Real-IP' is '192.168.8.127'
  header 'X-Forwarded-Proto' is 'http'
  header 'X-Forwarded-Host' is 'echo.example.com'
  header 'X-Forwarded-Port' is '80'
  header 'Connection' is 'close'
  header 'Accept' is '*/*'
```

Request headers have been modified:

- User-Agent header is absent.
- The header My-Cool-header gets appended with the new value my-client-value.
- The header My-Overwrite-Header gets overwritten from dont-see-this to this-is-the-only-value.
- The header Accept-encoding remains unchanged as we did not modify it in the curl request sent.

Response headers have been modified:

- Header `X-Header-Set` set to `overwritten-value`
- Value `this-is-the-appended-value` appended to the `X-Header-Add` header
- `X-Header-Remove` removed

Delete the lab

```code
kubectl delete -f .
```
