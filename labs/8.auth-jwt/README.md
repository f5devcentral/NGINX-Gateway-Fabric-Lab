# Enforcing JWT authentication using SnippetsFilter

This use case shows how to enforce JWT authentication through SnippetsFilter

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/8.auth-jwt
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

Set AWS annotations to make the Network Load Balancer external and Internet-facing
```
kubectl annotate svc gateway-nginx service.beta.kubernetes.io/aws-load-balancer-type=external --overwrite
kubectl annotate svc gateway-nginx service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing --overwrite
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-56678b747f-rrx4d` is the NGINX Gateway Fabric dataplane pod
```
NAME                             READY   STATUS    RESTARTS   AGE
coffee-56b44d4c55-g9gtj          1/1     Running   0          37s
gateway-nginx-56678b747f-rrx4d   1/1     Running   0          13s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS         PROGRAMMED   AGE
gateway   nginx   192.168.2.210   True         19s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
coffee          ClusterIP      10.105.103.134   <none>          80/TCP         34s
gateway-nginx   LoadBalancer   10.107.231.13    192.168.2.210   80:31588/TCP   34s
kubernetes      ClusterIP      10.96.0.1        <none>          443/TCP        402d
```

Create the SnippetsFilter to set up the FastCGI configuration snippets
```code
kubectl apply -f 2.snippetsfilter-jwtauth.yaml
```

Check the SnippetsFilter
```code
kubectl describe snippetsfilter auth-jwt
```

Output should be similar to
```code
Name:         auth-jwt
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         SnippetsFilter
Metadata:
  Creation Timestamp:  2025-10-07T11:41:02Z
  Generation:          1
  Resource Version:    66576310
  UID:                 e7ff7827-3ea8-42e8-8166-e758ddd6bc40
Spec:
  Snippets:
    Context:  http.server
    Value:    location = /_auth/_jwks_uri { internal;return 200 '{"keys":[{"k":"ZmFudGFzdGljand0","kty":"oct","kid":"0001"}]}'; }
    Context:  http.server.location
    Value:    auth_jwt "JWT token required";auth_jwt_type signed;auth_jwt_key_request /_auth/_jwks_uri;
Status:
  Controllers:
    Conditions:
      Last Transition Time:  2025-10-07T11:41:02Z
      Message:               SnippetsFilter is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
```

Create the HTTP route that references the SnippetsFilter
```code
kubectl apply -f 3.httproute.yaml
```

Check the HTTP route
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
export NGF_IP=`kubectl get svc gateway-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`
export HTTP_PORT=`kubectl get svc gateway-nginx -o jsonpath='{.spec.ports[0].targetPort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

Access the application without providing an authentication token
```code
curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT
```

Output should be similar to
```code
HTTP/1.1 401 Unauthorized
Server: nginx
Date: Tue, 07 Oct 2025 11:43:46 GMT
Content-Type: text/html
Content-Length: 172
Connection: keep-alive
WWW-Authenticate: Bearer realm="JWT token required"

<html>
<head><title>401 Authorization Required</title></head>
<body>
<center><h1>401 Authorization Required</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

Access the application again sending a valid JWT token
```code
curl -i --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT -H "Authorization: Bearer `cat token.jwt`"
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Tue, 07 Oct 2025 11:45:36 GMT
Content-Type: text/plain
Content-Length: 156
Connection: keep-alive
Expires: Tue, 07 Oct 2025 11:45:35 GMT
Cache-Control: no-cache

Server address: 10.0.156.110:8080
Server name: coffee-56b44d4c55-g9gtj
Date: 07/Oct/2025:11:45:36 +0000
URI: /
Request ID: 5afec06d5432b68456477e806cf8a52e
```

Delete the lab

```code
kubectl delete -f .
```
