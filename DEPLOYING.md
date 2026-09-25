# Lab deployment

See the [prerequisites](/README.md#getting-started)

## Installing

1. Create NGINX Gateway Fabric namespace

```bash
kubectl create namespace nginx-gateway
```

2. Create Kubernetes secret to pull images from NGINX private registry

```bash
kubectl create secret docker-registry nginx-plus-registry-secret --docker-server=private-registry.nginx.com --docker-username=`cat <nginx-one-eval.jwt>` --docker-password=none -n nginx-gateway
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

3. Create Kubernetes secret holding the NGINX Plus license

```bash
kubectl create secret generic nplus-license --from-file license.jwt=<nginx-one-eval.jwt> -n nginx-gateway
```

Note: `<nginx-one-eval.jwt>` is the path and filename of your `nginx-one-eval.jwt` file

4. List available NGINX Gateway Fabric docker images

```bash
curl -s https://private-registry.nginx.com/v2/nginx-gateway-fabric/nginx-plus/tags/list --key <nginx-one-eval.key> --cert <nginx-one-eval.crt> | jq
```

Note: `<nginx-one-eval.key>` and `<nginx-one-eval.key>` are the path and filename of your `nginx-one-eval.crt` and `nginx-one-eval.crt` files respectively

Pick the latest version (`2.7.2` at the time of writing)

5. Apply NGINX Gateway Fabric custom resources (make sure `ref=` the latest available NGINX Gateway Fabric version)

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" | kubectl apply -f -
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/inference-extension/?ref=v2.7.2" | kubectl apply -f -
```

6. Install NGINX Gateway Fabric through its Helm chart (set `nginx.image.tag` to the latest available NGINX Gateway Fabric version)

```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus-f5waf \
  --set nginx.image.tag=2.7.2 \
  --set nginx.plus=true \
  --set nginx.config.waf.enable=true \
  --set serviceAccount.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.usage.secretName=nplus-license \
  --set nginx.service.type=NodePort \
  --set nginxGateway.snippets.enable=true \
  --set nginxGateway.gwAPIInferenceExtension.enable=true \
  -n nginx-gateway
```

7. Check NGINX Gateway Fabric pod status

```bash
kubectl get pods -n nginx-gateway
```

Pod should be in the `Running` state

```bash
NAME                                        READY   STATUS    RESTARTS   AGE
ngf-nginx-gateway-fabric-5689b6b654-tqrrh   1/1     Running   0          71s
```

8. Check NGINX Gateway Fabric logs

```bash
kubectl logs -l app.kubernetes.io/instance=ngf -n nginx-gateway -c nginx-gateway
```

Output should be similar to

```bash
{"level":"info","ts":"2026-09-18T15:30:07Z","msg":"Starting the NGINX Gateway Fabric control plane","version":"2.7.2","commit":"580542620c2290118ba6dba5af7a612e6feaafbc","date":"2026-09-16T16:31:52Z","dirty":"true"}
{"level":"info","ts":"2026-09-18T15:30:07Z","msg":"Starting manager"}
{"level":"info","ts":"2026-09-18T15:30:07Z","logger":"controller-runtime.metrics","msg":"Starting metrics server"}
{"level":"info","ts":"2026-09-18T15:30:07Z","msg":"starting server","name":"health probe","addr":"[::]:8081"}
{"level":"info","ts":"2026-09-18T15:30:07Z","logger":"controller-runtime.metrics","msg":"Serving metrics server","bindAddress":":9113","secure":false}
{"level":"info","ts":"2026-09-18T15:30:07Z","msg":"Attempting to acquire leader lease...","lock":"nginx-gateway/ngf-nginx-gateway-fabric-leader-election"}
{"level":"info","ts":"2026-09-18T15:30:07Z","msg":"Successfully acquired lease","lock":"nginx-gateway/ngf-nginx-gateway-fabric-leader-election"}
{"level":"info","ts":"2026-09-18T15:30:08Z","logger":"telemetryJob","msg":"Starting cronjob"}
{"level":"info","ts":"2026-09-18T15:30:08Z","logger":"eventLoop.eventHandler","msg":"Reconfigured control plane.","batchID":23}
```

9. Check Kubernetes service status

```bash
kubectl get svc -n nginx-gateway
```

NGINX Gateway Fabric control plane should be listening on TCP port 443

```bash
NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)            AGE
ngf-nginx-gateway-fabric   ClusterIP   10.107.95.131   <none>        443/TCP,9113/TCP   100s
```

10. Check the `gatewayclass`

```bash
kubectl get gatewayclass
```

The `nginx` gatewayclass should have been accepted correctly

```bash
NAME    CONTROLLER                                   ACCEPTED   AGE
nginx   gateway.nginx.org/nginx-gateway-controller   True       114s
```

## Uninstalling

1. Uninstall NGINX Gateway Fabric through its Helm chart

```bash
helm uninstall ngf -n nginx-gateway
```

2. Delete the namespace

```bash
kubectl delete namespace nginx-gateway
```

3. Remove all CRDs

```bash
kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/crds.yaml
```

4. Remove the Gateway API resources

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" | kubectl delete -f -
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/inference-extension/?ref=v2.7.2" | kubectl delete -f -
```
