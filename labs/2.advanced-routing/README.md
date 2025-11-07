# Advanced routing using HTTP matching conditions

This use case shows how to publish two sample applications using HTTP matching conditions routing

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/2.advanced-routing
```

Deploy two sample web applications
```code
kubectl apply -f 0.coffee.yaml
kubectl apply -f 1.tea.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                             READY   STATUS    RESTARTS   AGE
pod/coffee-v1-767764946-qwrb2    1/1     Running   0          4s
pod/coffee-v2-677787799d-964xx   1/1     Running   0          4s
pod/coffee-v3-66d58645f4-mnzfr   1/1     Running   0          4s
pod/tea-6fbfdcb95d-p9kc2         1/1     Running   0          3s
pod/tea-post-ff7789454-7p89s     1/1     Running   0          3s

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/coffee-v1-svc   ClusterIP   10.100.72.158    <none>        80/TCP    4s
service/coffee-v2-svc   ClusterIP   10.100.113.238   <none>        80/TCP    4s
service/coffee-v3-svc   ClusterIP   10.100.17.24     <none>        80/TCP    4s
service/kubernetes      ClusterIP   10.100.0.1       <none>        443/TCP   4h25m
service/tea-post-svc    ClusterIP   10.100.203.198   <none>        80/TCP    3s
service/tea-svc         ClusterIP   10.100.128.93    <none>        80/TCP    3s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee-v1   1/1     1            1           4s
deployment.apps/coffee-v2   1/1     1            1           4s
deployment.apps/coffee-v3   1/1     1            1           4s
deployment.apps/tea         1/1     1            1           3s
deployment.apps/tea-post    1/1     1            1           3s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-v1-767764946    1         1         1       4s
replicaset.apps/coffee-v2-677787799d   1         1         1       4s
replicaset.apps/coffee-v3-66d58645f4   1         1         1       4s
replicaset.apps/tea-6fbfdcb95d         1         1         1       3s
replicaset.apps/tea-post-ff7789454     1         1         1       3s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 2.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`cafe-nginx-7444846d75-cgmms` pod is the NGINX Gateway Fabric dataplane
```
NAME                          READY   STATUS    RESTARTS   AGE
cafe-nginx-7444846d75-cgmms   1/1     Running   0          113s
coffee-v1-c48b96b65-5trnr     1/1     Running   0          113s
coffee-v2-685fd9bb65-dz5pp    1/1     Running   0          113s
coffee-v3-7fb98466f-478hw     1/1     Running   0          113s
tea-596697966f-hzjw5          1/1     Running   0          113s
tea-post-5647b8d885-5xxvf     1/1     Running   0          113s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME   CLASS   ADDRESS                                                                        PROGRAMMED   AGE
cafe   nginx   k8s-default-cafengin-000b9ca0ab-cc903b1c186b4036.elb.us-west-2.amazonaws.com   True         9s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`cafe-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
cafe-nginx      LoadBalancer   10.100.27.220    k8s-default-cafengin-000b9ca0ab-cc903b1c186b4036.elb.us-west-2.amazonaws.com   80:31790/TCP   37s
coffee-v1-svc   ClusterIP      10.100.201.15    <none>                                                                         80/TCP         69s
coffee-v2-svc   ClusterIP      10.100.22.22     <none>                                                                         80/TCP         69s
coffee-v3-svc   ClusterIP      10.100.230.239   <none>                                                                         80/TCP         69s
kubernetes      ClusterIP      10.100.0.1       <none>                                                                         443/TCP        4h16m
tea-post-svc    ClusterIP      10.100.128.103   <none>                                                                         80/TCP         68s
tea-svc         ClusterIP      10.100.99.3      <none>                                                                         80/TCP         68s
```

Create the HTTP routes
```code
kubectl apply -f 3.cafe-routes.yaml
```

Check the HTTP routes
```code
kubectl get httproute
```

Output should be similar to
```code
NAME     HOSTNAMES              AGE
coffee   ["cafe.example.com"]   8s
tea      ["cafe.example.com"]   8s
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

Access `coffee-v1`
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/coffee
```

Output should be similar to
```code
Server address: 192.168.120.145:8080
Server name: coffee-v1-767764946-dds5c
Date: 05/Nov/2025:16:06:51 +0000
URI: /coffee
Request ID: 785584c7d501c6e80e3dcc1b535e7348
```

Access `coffee-v2` using a query string
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/coffee?TEST=v2
```

Output should be similar to
```code
Server address: 192.168.120.152:8080
Server name: coffee-v2-677787799d-xp467
Date: 05/Nov/2025:16:07:14 +0000
URI: /coffee?TEST=v2
Request ID: 181bac50948c28314f1f07123139f378
```

Access `coffee-v2` using an HTTP header
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/coffee -H "version: v2"
```

Output should be similar to
```code
Server address: 192.168.120.152:8080
Server name: coffee-v2-677787799d-xp467
Date: 05/Nov/2025:16:07:41 +0000
URI: /coffee
Request ID: ebb42b305dc7f13fa30b9722526790d7
```

Access `coffee-v3` using a query string
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/coffee?queryRegex=query-a
```

Output should be similar to
```code
Server address: 192.168.120.144:8080
Server name: coffee-v3-66d58645f4-mtm4v
Date: 05/Nov/2025:16:08:04 +0000
URI: /coffee?queryRegex=query-a
Request ID: d3eaf0a377e55204e22957b9f848e29c
```

Access `coffee-v3` using an HTTP header
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/coffee -H "headerRegex: header-a"
```

Output should be similar to
```code
Server address: 192.168.120.144:8080
Server name: coffee-v3-66d58645f4-mtm4v
Date: 05/Nov/2025:16:08:31 +0000
URI: /coffee
Request ID: ca6b2f4c6a296892c21805ffb6525377
```

Access `tea` using `GET`
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/tea
```

Output should be similar to
```code
Server address: 192.168.120.147:8080
Server name: tea-6fbfdcb95d-9p5gn
Date: 05/Nov/2025:16:09:02 +0000
URI: /tea
Request ID: 761d865680b9ee8c6d3fef2f4cb9dc59
```

Access `tea` using `POST`
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/tea -X POST
```

Output should be similar to
```code
Server address: 192.168.120.146:8080
Server name: tea-post-ff7789454-hn5wn
Date: 05/Nov/2025:16:09:20 +0000
URI: /tea
Request ID: eff3e0a081cb447ff8cbff43fb3bc043
```

Delete the lab

```code
kubectl delete -f .
```
