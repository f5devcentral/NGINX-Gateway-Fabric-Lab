# Traffic splitting

This use case shows how to split traffic between two versions of the same application

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/5.traffic-splitting
```

Deploy the sample application: two versions will be run
```code
kubectl apply -f 0.cafe.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```code
NAME                             READY   STATUS    RESTARTS   AGE
pod/coffee-v1-767764946-7jhfp    1/1     Running   0          6s
pod/coffee-v2-677787799d-kpmtg   1/1     Running   0          6s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/coffee-v1    ClusterIP   10.100.94.39     <none>        80/TCP    6s
service/coffee-v2    ClusterIP   10.100.235.108   <none>        80/TCP    6s
service/kubernetes   ClusterIP   10.100.0.1       <none>        443/TCP   22h

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee-v1   1/1     1            1           6s
deployment.apps/coffee-v2   1/1     1            1           6s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-v1-767764946    1         1         1       6s
replicaset.apps/coffee-v2-677787799d   1         1         1       6s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-67fb4cdf89-b2fdn` pod is the NGINX Gateway Fabric dataplane
```
NAME                             READY   STATUS    RESTARTS   AGE
coffee-v1-767764946-7jhfp        1/1     Running   0          34s
coffee-v2-677787799d-kpmtg       1/1     Running   0          34s
gateway-nginx-67fb4cdf89-b2fdn   0/1     Running   0          7s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS                                                                        PROGRAMMED   AGE
gateway   nginx   k8s-default-gatewayn-2a78c4a4f4-ffded1fc8191491b.elb.us-west-2.amazonaws.com   True         27s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
coffee-v1       ClusterIP      10.100.94.39     <none>                                                                         80/TCP         71s
coffee-v2       ClusterIP      10.100.235.108   <none>                                                                         80/TCP         71s
gateway-nginx   LoadBalancer   10.100.66.106    k8s-default-gatewayn-2a78c4a4f4-ffded1fc8191491b.elb.us-west-2.amazonaws.com   80:31740/TCP   44s
kubernetes      ClusterIP      10.100.0.1       <none>                                                                         443/TCP        22h
```

Create the HTTP route that splits traffic evenly across the two application versions
```code
kubectl apply -f 2.route-80-80.yaml
```

Check the HTTP routes
```code
kubectl get httproute
```

Output should be similar to
```code
NAME         HOSTNAMES              AGE
cafe-route   ["cafe.example.com"]   5s
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

Access the application
```code
curl -H "Host: cafe.example.com" http://$NGF_DNS/coffee
```

Output should be similar to either
```code
Server address: 192.168.120.144:8080
Server name: coffee-v1-767764946-7jhfp
Date: 06/Nov/2025:10:20:48 +0000
URI: /coffee
Request ID: 3f83c5035b92be163f930beb3bae810a
```

or

```code
Server address: 192.168.120.145:8080
Server name: coffee-v2-677787799d-kpmtg
Date: 06/Nov/2025:10:21:05 +0000
URI: /coffee
Request ID: 66f4fcd5dac8cf26a69bcc6029b3fe99
```

Run the test script to send 100 requests
```code
. ./test.sh
```

Output should be similar to
```code
....................................................................................................
Summary of responses:
Coffee v1: 47 times
Coffee v2: 53 times
```

Update the HTTP Route to split traffic based on 80-20 ratio
```code
kubectl apply -f 3.route-80-20.yaml
```

Run the test script to send 100 requests
```code
. ./test.sh
```

Output should be similar to
```code
....................................................................................................
Summary of responses:
Coffee v1: 83 times
Coffee v2: 17 times
```

Delete the lab

```code
kubectl delete -f .
```
