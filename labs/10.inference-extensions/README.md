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
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api-inference-extension/refs/tags/v1.5.0/config/manifests/vllm/sim-deployment.yaml
```

Verify that all pods are in the `Running` state
```code
kubectl get pods
```

Output should be similar to
```code
NAME                              READY   STATUS    RESTARTS   AGE
vllm-qwen3-32b-7955b44454-4hbrr   1/1     Running   0          16s
vllm-qwen3-32b-7955b44454-gshsv   1/1     Running   0          16s
vllm-qwen3-32b-7955b44454-rmdkw   1/1     Running   0          16s
```

Deploy the InferencePool and Endpoint Picker Extension
```code
export IGW_CHART_VERSION=v1.5.0
helm install vllm-qwen3-32b \
  --dependency-update \
  --set inferencePool.modelServers.matchLabels.app=vllm-qwen3-32b \
  --version $IGW_CHART_VERSION \
  --set inferenceExtension.resources.requests.cpu=100m \
  --set inferenceExtension.resources.requests.memory=512Mi \
  --set inferenceExtension.resources.limits.memory=2Gi \
  oci://registry.k8s.io/gateway-api-inference-extension/charts/inferencepool
```

Verify that all pods are in the `Running` state
```code
kubectl get pods
```

Output should be similar to
```code
NAME                                  READY   STATUS    RESTARTS   AGE
vllm-qwen3-32b-7955b44454-4hbrr       1/1     Running   0          7m6s
vllm-qwen3-32b-7955b44454-gshsv       1/1     Running   0          7m6s
vllm-qwen3-32b-7955b44454-rmdkw       1/1     Running   0          7m6s
vllm-qwen3-32b-epp-789599f8c4-777lv   1/1     Running   0          14s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 0.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```code
kubectl get pods
```

`inference-gateway-nginx-57c68597df-bkht2` is the NGINX Gateway Fabric dataplane pod
```code
NAME                                       READY   STATUS    RESTARTS   AGE
inference-gateway-nginx-57c68597df-bkht2   4/4     Running   0          69s
vllm-qwen3-32b-7955b44454-4hbrr            1/1     Running   0          8m29s
vllm-qwen3-32b-7955b44454-gshsv            1/1     Running   0          8m29s
vllm-qwen3-32b-7955b44454-rmdkw            1/1     Running   0          8m29s
vllm-qwen3-32b-epp-789599f8c4-777lv        1/1     Running   0          97s
```

Check the gateway
```code
kubectl get gateway
```
Output should be similar to
```code
NAME                CLASS   ADDRESS          PROGRAMMED   AGE
inference-gateway   nginx   10.105.218.210   True         81s
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
  Creation Timestamp:  2026-09-03T07:22:43Z
  Generation:          1
  Resource Version:    225379189
  UID:                 fb97639d-9135-4965-983f-036743265ec4
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
    Type:                  IPAddress
    Value:                 10.105.218.210
  Attached Listener Sets:  0
  Conditions:
    Last Transition Time:  2026-09-03T07:22:43Z
    Message:               The Gateway is accepted
    Observed Generation:   1
    Reason:                Accepted
    Status:                True
    Type:                  Accepted
    Last Transition Time:  2026-09-03T07:22:43Z
    Message:               The Gateway is programmed
    Observed Generation:   1
    Reason:                Programmed
    Status:                True
    Type:                  Programmed
  Listeners:
    Attached Routes:  0
    Conditions:
      Last Transition Time:  2026-09-03T07:22:43Z
      Message:               The Listener is programmed
      Observed Generation:   1
      Reason:                Programmed
      Status:                True
      Type:                  Programmed
      Last Transition Time:  2026-09-03T07:22:43Z
      Message:               The Listener is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
      Last Transition Time:  2026-09-03T07:22:43Z
      Message:               All references are resolved
      Observed Generation:   1
      Reason:                ResolvedRefs
      Status:                True
      Type:                  ResolvedRefs
      Last Transition Time:  2026-09-03T07:22:43Z
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
llm-route               3s
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
Date: Thu, 03 Sep 2026 07:27:15 GMT
Content-Type: application/json
Content-Length: 521
Connection: keep-alive
X-Inference-Pod: vllm-qwen3-32b-7955b44454-4hbrr
X-Inference-Port: 8000

{"id":"cmpl-bac9dfef-d7ca-54ef-bafb-cf3e05941206","created":1788420435,"model":"food-review-1","usage":{"prompt_tokens":10,"completion_tokens":50,"total_tokens":60},"object":"text_completion","kv_transfer_params":null,"choices":[{"index":0,"finish_reason":"stop","text":"The rest is silence. Today is a nice sunny day. The temperature here is twenty-five degrees centigrade. The temperature here is twenty-five degrees centigrade. The rest is silence. The temperature here is twenty-five degrees centigrade. To be or "}]}
```

Delete the lab

```code
kubectl delete -f .
helm uninstall vllm-qwen3-32b
kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api-inference-extension/refs/tags/v1.5.0/config/manifests/vllm/sim-deployment.yaml
```
