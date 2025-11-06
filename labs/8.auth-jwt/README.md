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
pod/coffee-676c9f8944-dhtlr   1/1     Running   0          5s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.100.80.201   <none>        80/TCP    6s
service/kubernetes   ClusterIP   10.100.0.1      <none>        443/TCP   23h

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   1/1     1            1           6s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-676c9f8944   1         1         1       6s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-67fb4cdf89-gw27h` is the NGINX Gateway Fabric dataplane pod
```
NAME                             READY   STATUS    RESTARTS   AGE
coffee-676c9f8944-dhtlr          1/1     Running   0          4m15s
gateway-nginx-67fb4cdf89-gw27h   1/1     Running   0          3m56s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS                                                                        PROGRAMMED   AGE
gateway   nginx   k8s-default-gatewayn-df30d9faa1-6e0a7b315da6c9fa.elb.us-west-2.amazonaws.com   True         4m13s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
coffee          ClusterIP      10.100.80.201    <none>                                                                         80/TCP         4m41s
gateway-nginx   LoadBalancer   10.100.215.119   k8s-default-gatewayn-df30d9faa1-6e0a7b315da6c9fa.elb.us-west-2.amazonaws.com   80:32652/TCP   4m21s
kubernetes      ClusterIP      10.100.0.1       <none>                                                                         443/TCP        23h
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
  Creation Timestamp:  2025-11-06T11:30:46Z
  Generation:          1
  Resource Version:    470527
  UID:                 99515966-9bcc-4ecb-871a-2fd43dbf8cb7
Spec:
  Snippets:
    Context:  http.server
    Value:    location = /_auth/_jwks_uri { internal;return 200 '{"keys":[{"k":"ZmFudGFzdGljand0","kty":"oct","kid":"0001"}]}'; }
    Context:  http.server.location
    Value:    auth_jwt "JWT token required";auth_jwt_type signed;auth_jwt_key_request /_auth/_jwks_uri;
Status:
  Controllers:
    Conditions:
      Last Transition Time:  2025-11-06T11:30:46Z
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

Access the application without providing an authentication token
```code
curl -i -H "Host: cafe.example.com" http://$NGF_DNS
```

Output should be similar to
```code
HTTP/1.1 401 Unauthorized
Server: nginx
Date: Thu, 06 Nov 2025 11:32:43 GMT
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
curl -i -H "Host: cafe.example.com" http://$NGF_DNS -H "Authorization: Bearer `cat token.jwt`"
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 06 Nov 2025 11:33:03 GMT
Content-Type: text/plain
Content-Length: 159
Connection: keep-alive
Expires: Thu, 06 Nov 2025 11:33:02 GMT
Cache-Control: no-cache

Server address: 192.168.120.146:8080
Server name: coffee-676c9f8944-dhtlr
Date: 06/Nov/2025:11:33:03 +0000
URI: /
Request ID: 3c2cc9a94eab4d2b3ac8b364053642d9
```

Delete the lab

```code
kubectl delete -f .
```
