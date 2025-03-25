# Lab deployment

See the [prerequisites](/README.md#getting-started)

## Installing

1. Create NGINX Gateway Fabric namespace

```code
kubectl create namespace nginx-gateway
```

2. Create Kubernetes secret to pull images from NGINX private registry

```code
kubectl create secret docker-registry nginx-plus-registry-secret --docker-server=private-registry.nginx.com --docker-username=`cat <nginx-one-eval.jwt>` --docker-password=none -n nginx-gateway
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

3. Create Kubernetes secret holding the NGINX Plus license

```code
kubectl create secret generic nplus-license --from-file license.jwt=<nginx-one-eval.jwt> -n nginx-gateway
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

4. List available NGINX Gateway Fabric releases

```code
curl -s https://private-registry.nginx.com/v2/nginx-gateway-fabric/nginx-plus/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

Note: `<nginx-one-eval.key>` and `<nginx-one-eval.key>` are the path and filename of your `nginx-one-eval.crt` and `nginx-one-eval.crt` files respectively

Pick the latest version (`1.6.2` at the time of writing)

5. Apply NGINX Gateway Fabric custom resources (make sure `ref=` the latest available NGINX Gateway Fabric version)

```code
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.6.2" | kubectl apply -f -
```

6. Install NGINX Gateway Fabric through its Helm chart (set `nginx.image.tag` to the latest available NGINX Gateway Fabric version)

```code
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus \
  --set nginx.image.tag=1.6.2 \
  --set nginx.plus=true \
  --set serviceAccount.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.usage.secretName=nplus-license \
  --set service.type=NodePort \
  -n nginx-gateway
```

7. Check NGINX Gateway Fabric pod status

```code
kubectl get pods -n nginx-gateway
```

Pod should be in the `Running` state

```code
NAME                                        READY   STATUS    RESTARTS   AGE
ngf-nginx-gateway-fabric-6d6454c589-m7hs4   2/2     Running   0          16s
```

8. Check NGINX Gateway Fabric logs

```code
kubectl logs -l app.kubernetes.io/instance=ngf -n nginx-gateway -c nginx-gateway
```

Output should be similar to

```code
{"level":"info","ts":"2025-03-24T09:24:06Z","logger":"controller-runtime.metrics","msg":"Serving metrics server","bindAddress":":9113","secure":false}
{"level":"info","ts":"2025-03-24T09:24:06Z","logger":"controller-runtime.healthz","msg":"healthz check failed","statuses":[{}]}
{"level":"info","ts":"2025-03-24T09:24:06Z","msg":"attempting to acquire leader lease nginx-gateway/ngf-nginx-gateway-fabric-leader-election..."}
{"level":"info","ts":"2025-03-24T09:24:06Z","msg":"successfully acquired lease nginx-gateway/ngf-nginx-gateway-fabric-leader-election"}
{"level":"info","ts":"2025-03-24T09:24:06Z","logger":"eventLoop.eventHandler","msg":"NGINX configuration was successfully updated","batchID":1}
{"level":"info","ts":"2025-03-24T09:24:06Z","logger":"telemetryJob","msg":"Starting cronjob"}
{"level":"info","ts":"2025-03-24T09:24:06Z","logger":"eventLoop.eventHandler","msg":"Reconfigured control plane.","batchID":2}
{"level":"info","ts":"2025-03-24T09:24:07Z","logger":"eventLoop.eventHandler","msg":"NGINX configuration was successfully updated","batchID":2}
{"level":"info","ts":"2025-03-24T09:24:07Z","logger":"eventLoop.eventHandler","msg":"Reconfigured control plane.","batchID":3}
{"level":"info","ts":"2025-03-24T09:24:07Z","logger":"eventLoop.eventHandler","msg":"Handling events didn't result into NGINX configuration changes","batchID":3}
```

9. Check Kubernetes service status

```code
kubectl get svc -n nginx-gateway
```

NGINX Gateway Fabric should be listening on TCP ports 80 and 443

```code
NAME                       TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ngf-nginx-gateway-fabric   NodePort   10.106.75.254   <none>        80:32621/TCP,443:30341/TCP   2m36s
```

10. Check the `gatewayclass`

```code
kubectl get gatewayclass
```

The `nginx` gatewayclass should have been accepted correctly

```code
NAME    CONTROLLER                                   ACCEPTED   AGE
nginx   gateway.nginx.org/nginx-gateway-controller   True       3h45m
```

## Uninstalling

* Uninstall NGINX Gateway Fabric through its Helm chart

```code
helm uninstall ngf -n nginx-gateway
```

* Delete the namespace

```code
kubectl delete namespace nginx-gateway
```
