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
pod/headers-67f468496f-ncf8s   1/1     Running   0          18s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/headers      ClusterIP   10.105.244.169   <none>        80/TCP    18s
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   268d

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/headers   1/1     1            1           18s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/headers-67f468496f   1         1         1       18s
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
NAME                            READY   STATUS    RESTARTS   AGE
gateway-nginx-c9bcdf4d4-j9pw5   1/1     Running   0          49s
headers-67f468496f-ncf8s        1/1     Running   0          92s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS         PROGRAMMED   AGE
gateway   nginx   192.168.2.210   True         7s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
gateway-nginx   LoadBalancer   10.98.93.28      192.168.2.210   80:32198/TCP   16s
headers         ClusterIP      10.108.232.188   <none>          80/TCP         16s
kubernetes      ClusterIP      10.96.0.1        <none>          443/TCP        402d
```

Create the HTTP routes
```code
kubectl apply -f 2.httproute.yaml
```

Check the HTTP routes
```code
kubectl get httproute
```

Output should be similar to
```code
NAME      HOSTNAMES              AGE
headers   ["echo.example.com"]   3s
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get svc gateway-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
export HTTP_PORT=`kubectl get svc gateway-nginx -o jsonpath='{.spec.ports[0].targetPort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

Access the test application
```code
curl -i --resolve echo.example.com:$HTTP_PORT:$NGF_IP http://echo.example.com:$HTTP_PORT/nofilter -H "My-Cool-Header:my-client-value" -H "My-Overwrite-Header:dont-see-this" 
```
Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 18 Sep 2025 21:42:45 GMT
Content-Type: text/plain
Content-Length: 450
Connection: keep-alive

Headers:
  header 'Host' is 'echo.example.com:30177'
  header 'X-Forwarded-For' is '10.1.1.8'
  header 'X-Real-IP' is '10.1.1.8'
  header 'X-Forwarded-Proto' is 'http'
  header 'X-Forwarded-Host' is 'echo.example.com'
  header 'X-Forwarded-Port' is '80'
  header 'Connection' is 'close'
  header 'User-Agent' is 'curl/7.81.0'
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
curl -i --resolve echo.example.com:$HTTP_PORT:$NGF_IP http://echo.example.com:$HTTP_PORT/headers -H "My-Cool-Header:my-client-value" -H "My-Overwrite-Header:dont-see-this" 
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 12 Jun 2025 11:09:02 GMT
Content-Type: text/plain
Content-Length: 495
Connection: keep-alive
X-Header-Add: this-is-the-appended-value
X-Header-Set: overwritten-value

Headers:
  header 'Accept-Encoding' is 'compress'
  header 'My-cool-header' is 'my-client-value,this-is-an-appended-value'
  header 'My-Overwrite-Header' is 'this-is-the-only-value'
  header 'Host' is 'echo.example.com:30344'
  header 'X-Forwarded-For' is '192.168.2.26'
  header 'X-Real-IP' is '192.168.2.26'
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
