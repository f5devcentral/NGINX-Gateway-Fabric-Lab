# Traffic splitting

This use case shows how to split traffic between two versions of the same application

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
cd ~/NGINX-Gateway-Fabric-Lab/labs/5.traffic-splitting
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
gateway   nginx             True         5s
```

Deploy the sample application: two versions will be run
```code
kubectl apply -f 1.cafe.yaml
```

Verify that all pods are in the `Running` state

```code
kubectl get all
```

Output should be similar to

```code
NAME                             READY   STATUS    RESTARTS   AGE
pod/coffee-v1-c48b96b65-9ljmf    1/1     Running   0          4s
pod/coffee-v2-685fd9bb65-2xn82   1/1     Running   0          4s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/coffee-v1    ClusterIP   10.104.247.76    <none>        80/TCP    4s
service/coffee-v2    ClusterIP   10.100.234.209   <none>        80/TCP    4s
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   39d

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee-v1   1/1     1            1           4s
deployment.apps/coffee-v2   1/1     1            1           4s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-v1-c48b96b65    1         1         1       4s
replicaset.apps/coffee-v2-685fd9bb65   1         1         1       4s
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
cafe-route   ["cafe.example.com"]   17s
```

Access the application
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to either
```code
Server address: 192.168.169.132:8080
Server name: coffee-v1-c48b96b65-9ljmf
Date: 25/Mar/2025:23:52:35 +0000
URI: /coffee
Request ID: 1e7f59dcfee8d62d070028b8884753fc
```

or
```code
Server address: 192.168.169.133:8080
Server name: coffee-v2-685fd9bb65-2xn82
Date: 25/Mar/2025:23:52:47 +0000
URI: /coffee
Request ID: cab8a4840e3ac542b9486200373e9bed
```

Run the test script to send 100 requests
```code
. ./test.sh
```

Output should be similar to
```code
....................................................................................................
Summary of responses:
Coffee v1: 59 times
Coffee v2: 41 times
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
Coffee v1: 82 times
Coffee v2: 18 times
```

Delete the lab

```code
kubectl delete -f .
```
