# Modify HTTP request and response headers

This use case shows how to modify HTTP headers

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
cd ~/NGINX-Gateway-Fabric-Lab/labs/3.http-headers
```

Create the gateway object
```code
kubectl apply -f 0.gateway.yaml
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS   PROGRAMMED   AGE
gateway   nginx             True         4s
```

Deploy the sample application
```code
kubectl apply -f 1.app.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                           READY   STATUS    RESTARTS   AGE
pod/headers-67f468496f-x6hlj   1/1     Running   0          3s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/headers      ClusterIP   10.108.186.184   <none>        80/TCP    3s
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   38d

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/headers   1/1     1            1           3s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/headers-67f468496f   1         1         1       3s
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

Access the test application
```code
curl -i --resolve echo.example.com:$HTTP_PORT:$NGF_IP http://echo.example.com:$HTTP_PORT/headers -H "My-Cool-Header:my-client-value" -H "My-Overwrite-Header:dont-see-this" 
```


Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Mon, 24 Mar 2025 22:22:10 GMT
Content-Type: text/plain
Content-Length: 487
Connection: keep-alive
X-Header-Add: this-is-the-appended-value
X-Header-Set: overwritten-value

Headers:
  header 'Accept-Encoding' is 'compress'
  header 'My-cool-header' is 'my-client-value,this-is-an-appended-value'
  header 'My-Overwrite-Header' is 'this-is-the-only-value'
  header 'Host' is 'echo.example.com:31651'
  header 'X-Forwarded-For' is '10.1.1.8'
  header 'X-Real-IP' is '10.1.1.8'
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
