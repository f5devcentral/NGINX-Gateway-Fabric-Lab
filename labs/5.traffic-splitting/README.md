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
pod/coffee-v1-c48b96b65-gqkxr    1/1     Running   0          4s
pod/coffee-v2-685fd9bb65-wl56z   1/1     Running   0          4s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/coffee-v1    ClusterIP   10.103.1.92     <none>        80/TCP    4s
service/coffee-v2    ClusterIP   10.109.14.146   <none>        80/TCP    4s
service/kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   268d

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coffee-v1   1/1     1            1           4s
deployment.apps/coffee-v2   1/1     1            1           4s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/coffee-v1-c48b96b65    1         1         1       4s
replicaset.apps/coffee-v2-685fd9bb65   1         1         1       4s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-c9bcdf4d4-j7bbg` pod is the NGINX Gateway Fabric dataplane
```
NAME                            READY   STATUS    RESTARTS   AGE
coffee-v1-c48b96b65-gqkxr       1/1     Running   0          47s
coffee-v2-685fd9bb65-wl56z      1/1     Running   0          47s
gateway-nginx-c9bcdf4d4-j7bbg   1/1     Running   0          10s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS         PROGRAMMED   AGE
gateway   nginx   192.168.2.211   True         8s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
coffee-v1       ClusterIP      10.107.57.4      <none>          80/TCP         109s
coffee-v2       ClusterIP      10.106.160.153   <none>          80/TCP         109s
gateway-nginx   LoadBalancer   10.101.104.28    192.168.2.211   80:31855/TCP   109s
kubernetes      ClusterIP      10.96.0.1        <none>          443/TCP        402d
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

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get svc gateway-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
export HTTP_PORT=`kubectl get svc gateway-nginx -o jsonpath='{.spec.ports[0].targetPort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

Access the application
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to either
```code
Server address: 10.0.156.127:8080
Server name: coffee-v1-c48b96b65-gqkxr
Date: 12/Jun/2025:11:24:59 +0000
URI: /coffee
Request ID: e5992510df47c30e1e8a232263db5341
```

or

```code
Server address: 10.0.156.67:8080
Server name: coffee-v2-685fd9bb65-wl56z
Date: 12/Jun/2025:11:24:43 +0000
URI: /coffee
Request ID: 995d20405a70bd5d5468a696e4b95e54
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
