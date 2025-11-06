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
NAME      CLASS   ADDRESS                                                                        PROGRAMMED   AGE
gateway   nginx   k8s-default-gatewayn-1ae4bba7bf-a0856a7194766114.elb.us-west-2.amazonaws.com   True         23m
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME              TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
coffee            ClusterIP      10.100.235.71    <none>                                                                         80/TCP         30m
gateway-nginx     LoadBalancer   10.100.164.37    k8s-default-gatewayn-1ae4bba7bf-a0856a7194766114.elb.us-west-2.amazonaws.com   80:32051/TCP   21m
kubernetes        ClusterIP      10.100.0.1       <none>                                                                         443/TCP        3h54m
tea               ClusterIP      10.100.138.239   <none>                                                                         80/TCP         30m
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

Test application access: to access `coffee`
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/coffee
```

Output should be similar to
```code
Server address: 192.168.120.151:8080
Server name: coffee-676c9f8944-cdkbf
Date: 05/Nov/2025:15:48:32 +0000
URI: /coffee
Request ID: 1eaef8a9cfbb20013066b620bdf28aa0
```

To access `tea`
```code
curl -H "Host: cafe.example.com"  http://$NGF_DNS/tea
```

Output should be similar to
```code
Server address: 192.168.120.147:8080
Server name: tea-6fbfdcb95d-djrhh
Date: 05/Nov/2025:15:48:44 +0000
URI: /tea
Request ID: 10fbfa2122d309a7d9a550f585ec07cd
```

Delete the lab

```code
kubectl delete -f .
```
