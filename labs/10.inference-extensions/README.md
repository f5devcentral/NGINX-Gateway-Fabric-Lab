# Gateway API Inference Extension

This use case shows how to optimize traffic routing to self-hosting Generative AI Models on Kubernetes

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/10.inference-extensions
```

Deploy a sample model server

> [!NOTE]
> The vLLM simulator model server does not use GPUs and is ideal for test/development environments. This sample is configured to simulate the meta-llama/LLama-3.1-8B-Instruct model.

```code
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/release-1.1/config/manifests/vllm/sim-deployment.yaml
```

Verify that all pods are in the `Running` state
```code
kubectl get pods
```

Output should be similar to
```code
NAME                                       READY   STATUS    RESTARTS   AGE
vllm-llama3-8b-instruct-5d4fd78fd5-8tfwh   1/1     Running   0          57s
vllm-llama3-8b-instruct-5d4fd78fd5-c7sn6   1/1     Running   0          57s
vllm-llama3-8b-instruct-5d4fd78fd5-mjf4d   1/1     Running   0          57s
```

Deploy the InferencePool and Endpoint Picker Extension
```code
export IGW_CHART_VERSION=v1.1.0
helm install vllm-llama3-8b-instruct \
  --set inferencePool.modelServers.matchLabels.app=vllm-llama3-8b-instruct \
  --version $IGW_CHART_VERSION \
  oci://registry.k8s.io/gateway-api-inference-extension/charts/inferencepool
```

Verify that all pods are in the `Running` state
```code
kubectl get pods
```

Output should be similar to
```code
NAME                                           READY   STATUS    RESTARTS   AGE
vllm-llama3-8b-instruct-5d4fd78fd5-8tfwh       1/1     Running   0          76s
vllm-llama3-8b-instruct-5d4fd78fd5-c7sn6       1/1     Running   0          76s
vllm-llama3-8b-instruct-5d4fd78fd5-mjf4d       1/1     Running   0          76s
vllm-llama3-8b-instruct-epp-7d945bdcb5-ltbfr   1/1     Running   0          8s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 0.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```code
kubectl get pods
```

`inference-gateway-nginx-5d65c94dcf-vwr6x` is the NGINX Gateway Fabric dataplane pod
```code
NAME                                           READY   STATUS    RESTARTS   AGE
inference-gateway-nginx-5d65c94dcf-vwr6x       2/2     Running   0          17s
vllm-llama3-8b-instruct-5d4fd78fd5-8tfwh       1/1     Running   0          112s
vllm-llama3-8b-instruct-5d4fd78fd5-c7sn6       1/1     Running   0          112s
vllm-llama3-8b-instruct-5d4fd78fd5-mjf4d       1/1     Running   0          112s
vllm-llama3-8b-instruct-epp-7d945bdcb5-ltbfr   1/1     Running   0          44s
```

Check the gateway
```code
kubectl get gateway
```
Output should be similar to
```code
NAME                CLASS   ADDRESS        PROGRAMMED   AGE
inference-gateway   nginx   10.98.96.164   True         26s
```

Describe the gateway
```code
kubectl describe gateways.gateway.networking.k8s.io inference-gateway
```

Output should be similar to
```code
Name:         inference-gateway
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.networking.k8s.io/v1
Kind:         Gateway
Metadata:
  Creation Timestamp:  2026-04-13T13:11:21Z
  Generation:          1
  Resource Version:    109744819
  UID:                 be75068b-501b-4b03-816c-540a0163ca16
Spec:
  Gateway Class Name:  nginx
  Listeners:
    Allowed Routes:
      Namespaces:
        From:  Same
    Name:      http
    Port:      80
    Protocol:  HTTP
Status:
  Addresses:
    Type:   IPAddress
    Value:  10.98.96.164
  Conditions:
    Last Transition Time:  2026-04-13T13:11:21Z
    Message:               The Gateway is accepted
    Observed Generation:   1
    Reason:                Accepted
    Status:                True
    Type:                  Accepted
    Last Transition Time:  2026-04-13T13:11:21Z
    Message:               The Gateway is programmed
    Observed Generation:   1
    Reason:                Programmed
    Status:                True
    Type:                  Programmed
  Listeners:
    Attached Routes:  0
    Conditions:
      Last Transition Time:  2026-04-13T13:11:21Z
      Message:               The Listener is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
      Last Transition Time:  2026-04-13T13:11:21Z
      Message:               The Listener is programmed
      Observed Generation:   1
      Reason:                Programmed
      Status:                True
      Type:                  Programmed
      Last Transition Time:  2026-04-13T13:11:21Z
      Message:               All references are resolved
      Observed Generation:   1
      Reason:                ResolvedRefs
      Status:                True
      Type:                  ResolvedRefs
      Last Transition Time:  2026-04-13T13:11:21Z
      Message:               No conflicts
      Observed Generation:   1
      Reason:                NoConflicts
      Status:                False
      Type:                  Conflicted
    Name:                    http
    Supported Kinds:
      Group:  gateway.networking.k8s.io
      Kind:   HTTPRoute
      Group:  gateway.networking.k8s.io
      Kind:   GRPCRoute
Events:       <none>
```

Create the HTTP route
```code
kubectl apply -f 1.httproute.yaml
```

Check the HTTP route
```code
kubectl get httproute
```

Output should be similar to
```code
NAME        HOSTNAMES   AGE
llm-route               4s
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc inference-gateway-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

Send a prompt to the gateway
```code
curl -i $NGF_IP:$HTTP_PORT/v1/completions -H 'Content-Type: application/json' -d '{
"model": "food-review-1",
"prompt": "Write as if you were a critic: San Francisco",
"max_tokens": 100,
"temperature": 0
}'
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Mon, 13 Apr 2026 13:15:36 GMT
Content-Type: application/json
Content-Length: 392
Connection: keep-alive
X-Inference-Pod: vllm-llama3-8b-instruct-5d4fd78fd5-8tfwh

{"id":"chatcmpl-6682e848-a556-4390-8f17-5765193d9bbf","created":1776086136,"model":"food-review-1","usage":{"prompt_tokens":10,"completion_tokens":3,"total_tokens":13},"object":"text_completion","do_remote_decode":false,"do_remote_prefill":false,"remote_block_ids":null,"remote_engine_id":"","remote_host":"","remote_port":0,"choices":[{"index":0,"finish_reason":"stop","text":"I am your "}]}
```

Delete the lab

```code
kubectl delete -f .
helm uninstall vllm-llama3-8b-instruct
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/release-1.1/config/manifests/vllm/sim-deployment.yaml
```
