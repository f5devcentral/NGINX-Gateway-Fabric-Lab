# NGINX Gateway Fabric and F5 AI Guardrails to secure LLM traffic

This lab demonstrates how to use NGINX Gateway Fabric with F5 AI Guardrails to inspect large language model (LLM) traffic and block disallowed content before it reaches the model or the client.

The NGINX Gateway Fabric is deployed directly in this lab.
A working F5 AI Guardrails authentication token is needed

## Architecture and Traffic Flow

The following diagram illustrates the architecture and traffic flow for this lab:

![Traffic Flow](15-ai.guardrails.png)

F5 AI Guardrails can inspect LLM traffic on two independent paths:

* **Prompts** — the client’s input is inspected before it reaches the LLM. A block returns `403` with `error.type: invalid_request_error`
* **Responses** — the model’s output is inspected before it reaches the client. A block returns `403` with `error.type: api_error`
* **Oversized prompts** — a prompt too large to inspect in memory is blocked before it reaches the LLM. A block returns `403` with `error.type: request_too_large` (`code: request_body_too_large`).

To connect NGINX Gateway Fabric with your configured F5 AI Guardrails, use the `PayloadProcessor` policy, an inherited policy that can target an `HTTPRoute` or a `Gateway`. The `PayloadProcessor` configures NGINX to offload traffic to F5 AI Guardrails to inspect.

`cd` into the lab directory
```bash
cd ~/NGINX-Gateway-Fabric-Lab/labs/15.ai-guardrails
```

## Deploy an LLM backend

The following example uses the [vLLM simulator](https://github.com/llm-d/llm-d-inference-sim/tree/main), which serves canned responses from a dataset rather than running a real model, making it suitable for test and development environments. The simulator loads its dataset from a ConfigMap.

Download the dataset file, then create the ConfigMap from it
```bash
curl -sL -o inference-sim-dataset.sqlite3 \
  https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.9.0/examples/guardrails/inference-sim-dataset.sqlite3

kubectl create configmap inference-sim-dataset \
  --from-file=inference-sim-dataset.sqlite3=./inference-sim-dataset.sqlite3
```

Deploy the LLM Deployment and Service
```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.9.0/examples/guardrails/llm.yaml
```

Check pod status
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                              READY   STATUS    RESTARTS   AGE
vllm-qwen3-32b-7486f7978d-cgf2s   1/1     Running   0          39s
```

## Configure F5 AI Guardrails

Get an [F5 AI Guardrails](https://www.f5.com/products/ai-guardrails) authentication token and replace it in `0.ai-guardrails-secret.yaml`. The example shows
```bash
  token: "<YOUR_API_TOKEN>"
```

Create the authentication token `Secret`. The `Secret` must live in the same namespace as the `PayloadProcessor` 
```bash
kubectl apply -f 0.ai-guardrails-secret.yaml
```

Configure the F5 AI Guardrails backend `Service`. Replace the placeholder `externalName` in `1.ai-guardrails-svc.yaml` with the F5 AI Guardrails API hostname. The example shows
```bash
  externalName: <GUARDRAILS_API_HOSTNAME>
```

Apply the `Service`: the `NginxProxy` resource defines the DNS resolver so NGINX can resolve the external hostname at request time.
```bash
kubectl apply -f 1.ai-guardarails-svc.yaml
```

## Deploy NGINX Gateway Fabric

Create NGINX Gateway Fabric namespace
```code
kubectl create namespace nginx-gateway
```

Create Kubernetes secret to pull images from NGINX private registry
```bash
kubectl create secret docker-registry nginx-plus-registry-secret --docker-server=private-registry.nginx.com --docker-username=`cat <nginx-one-eval.jwt>` --docker-password=none -n nginx-gateway
```

Create Kubernetes secret holding the NGINX Plus license
```bash
kubectl create secret generic nplus-license --from-file license.jwt=<nginx-one-eval.jwt> -n nginx-gateway
```

Apply NGINX Gateway Fabric custom resources
```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.9.0" | kubectl apply -f -
```

Install NGINX Gateway Fabric through its Helm chart
```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version 2.9.0 \
  --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus \
  --set nginx.image.tag=2.9.0 \
  --set nginx.plus=true \
  --set serviceAccount.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.usage.secretName=nplus-license \
  --set nginx.service.type=NodePort \
  --set nginxGateway.payloadProcessor.enable=true \
  -n nginx-gateway
```

Check NGINX Gateway Fabric pod status

```bash
kubectl get pods -n nginx-gateway
```

Pod should be in the `Running` state

```bash
NAME                                        READY   STATUS    RESTARTS   AGE
ngf-nginx-gateway-fabric-6bb9d6b4cf-9nrqf   1/1     Running   0          48s
```

Update the `ClusterRole` RBAC to add `payloadprocessors`

```bash
kubectl patch clusterrole ngf-nginx-gateway-fabric --type='json' -p='
[
  {
    "op": "add",
    "path": "/rules/-",
    "value": {
      "apiGroups": [
        "gateway.nginx.org"
      ],
      "resources": [
        "payloadprocessors"
      ],
      "verbs": [
        "get",
        "list",
        "watch"
      ]
    }
  },
  {
    "op": "add",
    "path": "/rules/-",
    "value": {
      "apiGroups": [
        "gateway.nginx.org"
      ],
      "resources": [
        "payloadprocessors/status"
      ],
      "verbs": [
        "update"
      ]
    }
  }
]'
```

## Create a Gateway

Create a gateway that will use F5 AI Guardrails to secure LLM traffic

```bash
kubectl apply -f 2.gateway.yaml
```

Check pod status
```bash
kubectl get pods
```

The Gateway pod should be in rhe `Running` status
```bash
NAME                                       READY   STATUS    RESTARTS   AGE
inference-gateway-nginx-67c64bbbb4-8w8gp   1/1     Running   0          16s
vllm-qwen3-32b-7486f7978d-cgf2s            1/1     Running   0          31m
```

Confirm that the Gateway was assigned an IP address and reports a `Programmed=True` status
```bash
kubectl describe gateways.gateway.networking.k8s.io inference-gateway
```

Output should be similar to
```bash
Name:         inference-gateway
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.networking.k8s.io/v1
Kind:         Gateway
Metadata:
  Creation Timestamp:  2026-11-24T09:56:53Z
  Generation:          1
  Resource Version:    157342208
  UID:                 786d653b-0a29-4cb7-8609-9fcb9a6a1816
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
    Value:                 10.103.78.8
  Attached Listener Sets:  0
  Conditions:
    Last Transition Time:  2026-11-24T09:56:53Z
    Message:               The Gateway is accepted
    Observed Generation:   1
    Reason:                Accepted
    Status:                True
    Type:                  Accepted
    Last Transition Time:  2026-11-24T09:56:53Z
    Message:               The Gateway is programmed
    Observed Generation:   1
    Reason:                Programmed
    Status:                True
    Type:                  Programmed
  Listeners:
    Attached Routes:  0
    Conditions:
      Last Transition Time:  2026-11-24T09:56:53Z
      Message:               The Listener is programmed
      Observed Generation:   1
      Reason:                Programmed
      Status:                True
      Type:                  Programmed
      Last Transition Time:  2026-11-24T09:56:53Z
      Message:               The Listener is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
      Last Transition Time:  2026-11-24T09:56:53Z
      Message:               All references are resolved
      Observed Generation:   1
      Reason:                ResolvedRefs
      Status:                True
      Type:                  ResolvedRefs
      Last Transition Time:  2026-11-24T09:56:53Z
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

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```bash
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc inference-gateway-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```bash
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

# Publish the test LLM through the Gateway

Create the `HTTPRoute`
```bash
kubectl apply -f 3.httproute.yaml
```

Confirm the `HTTPRoute` status conditions include `Accepted=True` and `ResolvedRefs=True`
```bash
kubectl describe httproute llm-route
```

Output should be similar to
```bash
Name:         llm-route
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.networking.k8s.io/v1
Kind:         HTTPRoute
Metadata:
  Creation Timestamp:  2026-11-24T12:19:37Z
  Generation:          1
  Resource Version:    157360445
  UID:                 e667865f-f129-4293-aab3-bf00476a982e
Spec:
  Parent Refs:
    Group:  gateway.networking.k8s.io
    Kind:   Gateway
    Name:   inference-gateway
  Rules:
    Backend Refs:
      Group:   
      Kind:    Service
      Name:    vllm-qwen3-32b
      Port:    8000
      Weight:  1
    Matches:
      Path:
        Type:   PathPrefix
        Value:  /
Status:
  Parents:
    Conditions:
      Last Transition Time:  2026-11-24T12:19:38Z
      Message:               The Route is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
      Last Transition Time:  2026-11-24T12:19:38Z
      Message:               All references are resolved
      Observed Generation:   1
      Reason:                ResolvedRefs
      Status:                True
      Type:                  ResolvedRefs
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
    Parent Ref:
      Group:         gateway.networking.k8s.io
      Kind:          Gateway
      Name:          inference-gateway
      Namespace:     default
      Section Name:  http
Events:              <none>
```

Attach the `PayloadProcessor` policy
```bash
kubectl apply -f 4.payloadprocessor.yaml
```

Confirm the `PayloadProcessor` policy was accepted: the status conditions shoud report `Accepted=True`
```bash
kubectl describe payloadprocessor llm-guardrails
```

Output should be similar to
```bash
Name:         llm-guardrails
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         PayloadProcessor
Metadata:
  Creation Timestamp:  2026-11-24T12:27:00Z
  Generation:          1
  Resource Version:    157361546
  UID:                 003ef1f9-0bf3-48df-a17c-d158620edd31
Spec:
  Processors:
    Ext Process:
      Auth Token Ref:
        Name:  guardrails-token
      Backend Ref:
        Group:     
        Kind:      Service
        Name:      guardrails-api
        Port:      443
    Failure Mode:  FailClosed
    Type:          ExtProcess
  Target Ref:
    Group:  gateway.networking.k8s.io
    Kind:   HTTPRoute
    Name:   llm-route
Status:
  Ancestors:
    Ancestor Ref:
      Group:      gateway.networking.k8s.io
      Kind:       HTTPRoute
      Name:       llm-route
      Namespace:  default
    Conditions:
      Last Transition Time:  2026-11-24T12:27:01Z
      Message:               The Policy is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
      Last Transition Time:  2026-11-24T12:27:01Z
      Message:               Policy is programmed in the data plane
      Observed Generation:   1
      Reason:                Programmed
      Status:                True
      Type:                  Programmed
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
```

## Test F5 AI Guardrails

Send a test prompt
```bash
curl -i http://$NGF_IP:$HTTP_PORT/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"meta-llama/Llama-3.1-8B-Instruct","stream":false,"max_tokens":128,"prompt":"What is NGINX?"}'
```

A prompt that doesn't trigger any guardrails will be replied with a payload similar to
```bash
HTTP/1.1 200 OK
Server: nginx
Date: Tue, 24 Nov 2026 12:31:01 GMT
Content-Type: application/json
Content-Length: 627
Connection: keep-alive
X-Inference-Pod: vllm-qwen3-32b-7486f7978d-cgf2s
X-Inference-Port: 8000

{"id":"cmpl-7d1cb305-ab7e-534b-9fc3-3b04941c8e38-0","model":"meta-llama/Llama-3.1-8B-Instruct","object":"text_completion","created":1795523461,"usage":{"prompt_tokens":4,"completion_tokens":62,"total_tokens":66,"prompt_tokens_details":{"cached_tokens":0}},"choices":[{"index":0,"finish_reason":"stop","text":"NGINX (pronounced \"engine-x\") is an open-source, high-performance web server. It functions primarily as an HTTP web server, reverse proxy, load balancer, and HTTP cache.Designed to handle thousands of concurrent connections with minimal memory usage, NGINX is an essential component of modern web infrastructure."}]}
```

Enable the `SSN guardrail` on the F5 AI Guardrails management console

![F5 AI Guardrails](https://raw.githubusercontent.com/f5devcentral/NGINX-Gateway-Fabric-Lab/refs/heads/main/labs/15.ai-guardrailsq/ai.guardrails-ssn.png)


Setting guardrails to block SSN numbers will trigger an `HTTP/403` response
```bash
curl -i http://$NGF_IP:$HTTP_PORT/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"meta-llama/Llama-3.1-8B-Instruct","stream":false,"max_tokens":128,"prompt":"My SSN is 123-45-6789"}'
```

Output for a prompt hitting guardrails will be similar to
```bash
HTTP/1.1 403 Forbidden
Server: nginx
Date: Tue, 24 Nov 2026 12:33:12 GMT
Content-Type: application/json
Content-Length: 128
Connection: keep-alive
X-Inference-Pod: vllm-qwen3-32b-7486f7978d-cgf2s
X-Inference-Port: 8000

{"error":{"code":"content_policy_violation","message":"Response blocked by guardrails policy.","param":null,"type":"api_error"}}
```


## Delete the lab

```bash
kubectl delete -f .

kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.9.0/examples/guardrails/llm.yaml

helm uninstall ngf -n nginx-gateway

kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.9.0/deploy/crds.yaml
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.9.0" | kubectl delete -f -
```
