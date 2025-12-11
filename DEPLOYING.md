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

4. List available NGINX Gateway Fabric docker images

```code
curl -s https://private-registry.nginx.com/v2/nginx-gateway-fabric/nginx-plus/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

Note: `<nginx-one-eval.key>` and `<nginx-one-eval.key>` are the path and filename of your `nginx-one-eval.crt` and `nginx-one-eval.crt` files respectively

Pick the latest version (`2.2.2` at the time of writing)

5. Apply NGINX Gateway Fabric custom resources (make sure `ref=` the latest available NGINX Gateway Fabric version)

```code
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.2.2" | kubectl apply -f -
```

6. Install NGINX Gateway Fabric through its Helm chart (set `nginx.image.tag` to the latest available NGINX Gateway Fabric version)

```code
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus \
  --set nginx.image.tag=2.2.2 \
  --set nginx.plus=true \
  --set serviceAccount.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.usage.secretName=nplus-license \
  --set nginx.service.type=NodePort \
  --set nginxGateway.snippetsFilters.enable=true \
  -n nginx-gateway
```

7. Check NGINX Gateway Fabric pod status

```code
kubectl get pods -n nginx-gateway
```

Pod should be in the `Running` state

```code
NAME                                            READY   STATUS      RESTARTS   AGE
ngf-nginx-gateway-fabric-bb7b4c469-85lpz        1/1     Running     0          6s
```

8. Check NGINX Gateway Fabric logs

```code
kubectl logs -l app.kubernetes.io/instance=ngf -n nginx-gateway -c nginx-gateway
```

Output should be similar to

```code
{"level":"info","ts":"2025-12-11T08:58:50Z","msg":"Starting the NGINX Gateway Fabric control plane","version":"2.2.2","commit":"17f4b9dddc6e715ea4d697fe39c761424d5b4ef8","date":"2025-12-10T19:37:46Z","dirty":"true"}
{"level":"info","ts":"2025-12-11T08:58:50Z","msg":"Starting manager"}
{"level":"info","ts":"2025-12-11T08:58:50Z","logger":"controller-runtime.metrics","msg":"Starting metrics server"}
{"level":"info","ts":"2025-12-11T08:58:50Z","msg":"starting server","name":"health probe","addr":"[::]:8081"}
{"level":"info","ts":"2025-12-11T08:58:50Z","logger":"controller-runtime.metrics","msg":"Serving metrics server","bindAddress":":9113","secure":false}
{"level":"info","ts":"2025-12-11T08:58:50Z","msg":"attempting to acquire leader lease nginx-gateway/ngf-nginx-gateway-fabric-leader-election..."}
{"level":"info","ts":"2025-12-11T08:58:50Z","msg":"successfully acquired lease nginx-gateway/ngf-nginx-gateway-fabric-leader-election"}
{"level":"info","ts":"2025-12-11T08:58:50Z","logger":"telemetryJob","msg":"Starting cronjob"}
{"level":"info","ts":"2025-12-11T08:58:50Z","logger":"eventLoop.eventHandler","msg":"Reconfigured control plane.","batchID":2}
```

9. Check Kubernetes service status

```code
kubectl get svc -n nginx-gateway
```

NGINX Gateway Fabric control plane should be listening on TCP port 443

```code
NAME                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
ngf-nginx-gateway-fabric   ClusterIP   10.100.138.150   <none>        443/TCP   55s
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

1. Uninstall NGINX Gateway Fabric through its Helm chart

```code
helm uninstall ngf -n nginx-gateway
```

2. Delete the namespace

```code
kubectl delete namespace nginx-gateway
```

3. Remove all CRDs

```code
kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.2.2/deploy/crds.yaml
```

4. Remove the Gateway API resources

```code
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.2.2" | kubectl delete -f -
```
