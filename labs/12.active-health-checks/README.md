# Active Health Checks with NGINX Plus

This use case demonstrates **active health checks** — an NGINX Plus feature that allows the data plane to detect and route around failed upstream pods independently of the Kubernetes control plane. This is particularly valuable during rolling deployments, where a delay in the NGF control plane updating the NGINX configuration can cause traffic to reach pods that are no longer running.

## Why active health checks matter

Without active health checks, NGINX only learns about a dead pod when the NGF controller reconciles the EndpointSlice update and pushes a new configuration. Under load, this can take minutes. With active health checks, NGINX Plus probes each upstream pod directly on a 5-second interval — completely independently of the control plane — and stops routing to any pod that fails within a single probe cycle.

> [!NOTE]
> Active health checks require **NGINX Plus**. This lab will not work with the OSS NGINX data plane.

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/12.active-health-checks
```

Deploy the sample applications. Coffee runs 3 replicas and tea runs 2 replicas to give enough pods to demonstrate failover
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
pod/coffee-56b44d4c55-4xkzp   1/1     Running   0          15s
pod/coffee-56b44d4c55-9mnt2   1/1     Running   0          15s
pod/coffee-56b44d4c55-xp7vl   1/1     Running   0          15s
pod/tea-596697966f-j2kxq      1/1     Running   0          15s
pod/tea-596697966f-r8pqn      1/1     Running   0          15s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/coffee       ClusterIP   10.102.183.22   <none>        80/TCP    15s
service/kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP   268d
service/tea          ClusterIP   10.111.232.55   <none>        80/TCP    15s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```code
kubectl get pods
```

`gateway-nginx-c9bcdf4d4-4hl7c` is the NGINX Gateway Fabric dataplane pod
```
NAME                            READY   STATUS    RESTARTS   AGE
coffee-56b44d4c55-4xkzp         1/1     Running   0          30s
coffee-56b44d4c55-9mnt2         1/1     Running   0          30s
coffee-56b44d4c55-xp7vl         1/1     Running   0          30s
gateway-nginx-c9bcdf4d4-4hl7c   4/4     Running   0          10s
tea-596697966f-j2kxq            1/1     Running   0          30s
tea-596697966f-r8pqn            1/1     Running   0          30s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS        PROGRAMMED   AGE
gateway   nginx   10.102.76.40   True         20s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
coffee          ClusterIP   10.102.183.22   <none>        80/TCP         45s
gateway-nginx   NodePort    10.100.81.10    <none>        80:32604/TCP   20s
kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP        268d
tea             ClusterIP   10.111.232.55   <none>        80/TCP         45s
```

Create the HTTP routes (without health checks)
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
coffee   ["cafe.example.com"]   5s
tea      ["cafe.example.com"]   5s
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc gateway-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

Test application access
```code
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee
```

Output should be similar to
```code
Server address: 10.244.1.5:8080
Server name: coffee-56b44d4c55-4xkzp
Date: 05/Jun/2026:10:00:00 +0000
URI: /coffee
Request ID: 4d8d719e95063303e290ad74ecd7339f
```

## Demonstrate the problem — errors without health checks

Scale coffee down to simulate a pod failure during a deployment
```code
kubectl scale deployment coffee --replicas=1
```

Send 20 rapid requests and observe the response codes
```code
for i in $(seq 1 20); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    --resolve cafe.example.com:$HTTP_PORT:$NGF_IP \
    http://cafe.example.com:$HTTP_PORT/coffee
  sleep 0.3
done
```

Output will contain a mix of `200` and `502` responses. NGINX continues routing to the removed pods until the NGF control plane reconciles and pushes an updated configuration
```
200
200
502
502
200
502
```

Scale back up for the next step
```code
kubectl scale deployment coffee --replicas=3
kubectl wait --for=condition=ready pod -l app=coffee --timeout=60s
```

## Enable active health checks

Create the `SnippetsFilter` that injects the `health_check` directive into NGINX configuration
```code
kubectl apply -f 3.snippetsfilter.yaml
```

Check the SnippetsFilter
```code
kubectl describe snippetsfilter active-health-check
```

Output should be similar to
```code
Name:         active-health-check
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         SnippetsFilter
Spec:
  Snippets:
    Context:  http.server.location
    Value:    health_check;
Events:       <none>
```

Update the HTTP routes to reference the `SnippetsFilter`
```code
kubectl apply -f 4.httproute-healthcheck.yaml
```

## Verify health checks are active

Get the NGINX Gateway Fabric dataplane pod name
```code
export NGINX_POD=`kubectl get pod -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}'`
echo "NGINX pod: $NGINX_POD"
```

Confirm the `health_check` directive is present in the generated NGINX configuration
```code
kubectl exec $NGINX_POD -c nginx -- nginx -T 2>/dev/null | grep health_check
```

Output should be
```code
        health_check;
```

Forward the NGINX Plus API port to verify upstream health status
```code
kubectl port-forward $NGINX_POD 8765:8765 &
sleep 2
```

Query the NGINX Plus upstream API
```code
curl -s http://localhost:8765/api/9/http/upstreams | python3 -m json.tool
```

Each upstream server entry will now include a `health_checks` block
```code
{
    "server": "10.244.1.5:8080",
    "state": "up",
    "health_checks": {
        "checks": 4,
        "fails": 0,
        "unhealthy": 0,
        "last_passed": true
    }
}
```

Stop the port-forward
```code
kill %1
```

## Demonstrate active health check protection

Scale coffee down again — this time with health checks active
```code
kubectl scale deployment coffee --replicas=1
```

Send 30 rapid requests immediately after scaling
```code
for i in $(seq 1 30); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    --resolve cafe.example.com:$HTTP_PORT:$NGF_IP \
    http://cafe.example.com:$HTTP_PORT/coffee
  sleep 0.3
done
```

All responses should now be `200`. NGINX Plus detected the removed pods via health checks within 5 seconds and stopped routing to them before any live traffic could reach them
```
200
200
200
200
200
200
```

Verify the removed pod IPs show as `unhealthy` in the NGINX Plus API
```code
kubectl port-forward $NGINX_POD 8765:8765 &
sleep 2
curl -s http://localhost:8765/api/9/http/upstreams | python3 -m json.tool | grep -A4 '"state"'
kill %1
```

Output should show the removed pods as `"state": "unhealthy"` and the surviving pod as `"state": "up"`
```code
    "state": "unhealthy",
    ...
    "state": "unhealthy",
    ...
    "state": "up",
```

Scale coffee back up and watch the pods rejoin the active pool automatically after passing their health checks
```code
kubectl scale deployment coffee --replicas=3
kubectl wait --for=condition=ready pod -l app=coffee --timeout=60s
sleep 10
```

Query the API again — all pods should now show `"state": "up"` and `"last_passed": true`
```code
kubectl port-forward $NGINX_POD 8765:8765 &
sleep 2
curl -s http://localhost:8765/api/9/http/upstreams | python3 -m json.tool | grep -A6 '"health_checks"'
kill %1
```

## Advanced health check parameters

The basic `health_check;` uses NGINX Plus defaults. Apply tuned parameters for finer control
```code
kubectl apply -f 5.snippetsfilter-advanced.yaml
```

Confirm the updated directive in the NGINX configuration
```code
kubectl exec $NGINX_POD -c nginx -- nginx -T 2>/dev/null | grep health_check
```

Output should be
```code
        health_check interval=5s fails=2 passes=2 uri=/;
```

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `interval` | `5s` | Probe each upstream every 5 seconds |
| `fails` | `2` | 2 consecutive failures mark the server unhealthy |
| `passes` | `2` | 2 consecutive successes mark the server healthy again |
| `uri` | `/` | Path to probe — change to your app's health endpoint e.g. `/healthz` |

## Mandatory health checks for rolling deployments

The `mandatory` parameter is the most important production setting. Without it, NGINX Plus adds a newly started pod to the live pool immediately — before its first health check has run. With `mandatory`, the pod is held in a `checking` state and only receives traffic after its first successful health check

Apply the mandatory health check configuration
```code
kubectl apply -f 6.snippetsfilter-mandatory.yaml
```

Trigger a rolling deployment to observe the difference
```code
kubectl rollout restart deployment/coffee
```

Watch pods and send continuous traffic in parallel

In one terminal, watch the pod rollout
```code
kubectl get pods -l app=coffee -w
```

In another terminal, send continuous traffic
```code
while true; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    --resolve cafe.example.com:$HTTP_PORT:$NGF_IP \
    http://cafe.example.com:$HTTP_PORT/coffee
  sleep 0.5
done
```

With `mandatory` enabled, all responses remain `200` throughout the rolling restart. New pods appear briefly as `checking` in the NGINX Plus API before transitioning to `up`

```code
kubectl port-forward $NGINX_POD 8765:8765 &
sleep 2
curl -s http://localhost:8765/api/9/http/upstreams | python3 -m json.tool | grep '"state"'
kill %1
```

New pods will show `"state": "checking"` briefly during the rollout
```code
    "state": "checking",
    "state": "up",
    "state": "up",
```

Delete the lab
```code
kubectl delete -f .
```
