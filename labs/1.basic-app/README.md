# Basic URI-based routing

This use case shows how to publish two sample applications using URI-based routing

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/1.basic-app
```

Deploy two sample web applications
```code
kubectl apply -f 0.cafe.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                          READY   STATUS    RESTARTS   AGE
pod/coffee-56b44d4c55-nm5rx   1/1     Running   0          8m39s
pod/tea-596697966f-lk2gp      1/1     Running   0          8m39s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.102.183.198   <none>        80/TCP    8m39s
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   38d
service/tea          ClusterIP   10.111.232.2     <none>        80/TCP    8m39s

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee   1/1     1            1           8m39s
deployment.apps/tea      1/1     1            1           8m39s

NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-56b44d4c55   1         1         1       8m39s
replicaset.apps/tea-596697966f      1         1         1       8m39s
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

The `gateway-nginx-c9bcdf4d4-4hl7c` pod is the NGINX Gateway Fabric dataplane
```
NAME                            READY   STATUS    RESTARTS   AGE
coffee-56b44d4c55-6drv2         1/1     Running   0          47s
gateway-nginx-c9bcdf4d4-4hl7c   1/1     Running   0          24s
tea-596697966f-fwf2r            1/1     Running   0          47s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS         PROGRAMMED   AGE
gateway   nginx   192.168.2.210   True         42s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
coffee          ClusterIP      10.103.44.183    <none>                                                                         80/TCP         45s
gateway-nginx   LoadBalancer   10.110.110.185   k8s-default-gatewayn-b5a9df2a22-3ac3031604d6c961.elb.us-west-2.amazonaws.com   80:30554/TCP   33s
kubernetes      ClusterIP      10.96.0.1        <none>                                                                         443/TCP        402d
tea             ClusterIP      10.110.43.4      <none>                                                                         80/TCP         45s
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
NAME     HOSTNAMES              AGE
coffee   ["cafe.example.com"]   8s
tea      ["cafe.example.com"]   8s
```

Get NGINX Gateway Fabric dataplane instance public-facing hostname
```code
export NGF_IP=`kubectl get svc gateway-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`
```

Check NGINX Gateway Fabric dataplane instance public-facing hostname
```code
echo -e "NGF address: $NGF_IP"
```

Test application access: to access `coffee`
```code
curl -H "Host: cafe.example.com" http://$NGF_IP/coffee
```

Output should be similar to
```code
Server address: 10.0.156.91:8080
Server name: coffee-56b44d4c55-58pbv
Date: 24/Oct/2025:15:18:05 +0000
URI: /coffee
Request ID: 0f8b2359841d4076c7793115618032be
```

To access `tea`
```code
curl -H "Host: cafe.example.com" http://$NGF_IP/tea
```

Output should be similar to
```code
Server address: 10.0.156.90:8080
Server name: tea-596697966f-ngz25
Date: 24/Oct/2025:15:18:09 +0000
URI: /tea
Request ID: 945cbd55c9d3f9672c26b1ae6b5bafdb
```

Delete the lab

```code
kubectl delete -f .
```
