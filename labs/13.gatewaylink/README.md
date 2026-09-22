# Using an F5 BIG-IP system as the external load balancer for NGINX Gateway Fabric Gateway

The `GatewayLink` object integrates NGINX Gateway Fabric with [F5 BIG-IP Container Ingress Services](https://clouddocs.f5.com/containers/latest/)
to configure an [F5 BIG-IP system as the external load balancer for a Gateway](https://docs.nginx.com/nginx-gateway-fabric/external-loadbalancers/big-ip/quickstart/)

The desired BIG-IP configuration is defined through the `ExternalLoadBalancer` custom resource

In this lab, the [F5 IPAM Controller](https://clouddocs.f5.com/containers/latest/userguide/ipam/) allocates the address that BIG-IP listens on,
and an iRule preserves the original client address by forwarding it to NGINX using the PROXY protocol

Prerequisites:

* A Kubernetes cluster
* An F5 BIG-IP system running version 17.1.0.3 or later, and an account on it with administrator privileges
* Network access from the cluster to the BIG-IP system, and from BIG-IP to the cluster node addresses
* Python 3.14 or later


The NGINX Gateway Fabric is deployed directly in this lab

`cd` into the lab directory
```bash
cd ~/NGINX-Gateway-Fabric-Lab/labs/13.ingresslink
```

## Set BIG-IP configuration variables

```bash
export BIGIP_ADDRESS="<BIGIP_MGMT_ADDRESS:443>"
export BIGIP_USERNAME="admin"
export BIGIP_PASSWORD="<BIGIP_ADMIN_PASSWORD>"
export IPAM_ADDRESS_RANGE="<BIGIP_LTM_VS_ADDRESS RANGE>"

# Example
export BIGIP_ADDRESS="bigip1.nginx.lab:443"
export BIGIP_USERNAME="admin"
export BIGIP_PASSWORD="myPassword"
export IPAM_ADDRESS_RANGE="192.168.2.180-192.168.2.185"
```

## Install AS3 on BIG-IP

F5 Container Ingress Services configures BIG-IP by posting AS3 declarations, so AS3 must be installed before anything else
Follow Downloading and installing the BIG-IP AS3 package in the [F5 documentation](https://clouddocs.f5.com/products/extensions/f5-appsvcs-extension/latest/userguide/installation.html), then return here

## Create BIG-IP partition

Create the `k8s` user partition F5 Container Ingress Services owns on the F5 BIG-IP system
```bash
curl -sku "$BIGIP_USERNAME:$BIGIP_PASSWORD" -X POST "https://$BIGIP_ADDRESS/mgmt/tm/auth/partition" \
  -H "Content-Type: application/json" -d '{"name":"k8s"}'
```

Output should be similar to
```bash
{
    "name": "k8s",
    "fullPath": "k8s",
    "defaultRouteDomain": 0
}
```

## Create Proxy protocol iRule

Create the F5 BIG-IP iRule that takes care of adding the PROXY protocol header. This carries the original client address, so NGINX can report it instead of the BIG-IP self-IP address
```bash
curl -sku "$BIGIP_USERNAME:$BIGIP_PASSWORD" -X POST "https://$BIGIP_ADDRESS/mgmt/tm/ltm/rule" \
  -H "Content-Type: application/json" -d '{
    "name": "Proxy_Protocol_iRule",
    "apiAnonymous": "when SERVER_CONNECTED {\n  TCP::respond \"PROXY TCP[IP::version] [IP::client_addr] [clientside {IP::local_addr}] [TCP::client_port] [clientside {TCP::local_port}]\\r\\n\"\n}"
  }'
```

Output should be similar to
```bash
{
    "name": "Proxy_Protocol_iRule",
    "fullPath": "/Common/Proxy_Protocol_iRule",
    "apiAnonymous": "when SERVER_CONNECTED { ... }"
}
```

## Deploy F5 IPAM Controller

Deploy the `ipams.fic.f5.com` custom resource
```bash
kubectl apply -f 0.cis.yaml

curl -sku "$BIGIP_USERNAME:$BIGIP_PASSWORD" "https://$BIGIP_ADDRESS/mgmt/tm/net/self" \
  | python3 -c 'import sys,json;[print(x["name"],x["address"]) for x in json.load(sys.stdin)["items"]]'
```

Deploy the F5 IPAM Controller using the Helm chart
```bash
helm repo add f5-ipam-stable https://f5networks.github.io/f5-ipam-controller/helm-charts/stable --force-update
helm repo update

helm install f5-ipam-controller f5-ipam-stable/f5-ipam-controller \
  --namespace kube-system \
  --set image.version=0.1.13 \
  --set namespace=kube-system \
  --set rbac.create=true \
  --set serviceAccount.create=true \
  --set args.log_level=DEBUG \
  --set pvc.create=true \
  --set pvc.storage=100Mi \
  --set pvc.storageClassName=nfs-client \
  --set-string 'args.ip_range=\{"production":"'"$IPAM_ADDRESS_RANGE"'"\}' \
  --wait
```

Check the F5 IPAM Controller pod status
```bash
kubectl get pods -n kube-system | grep ipam
```

Pod should be in the `Running` state
```bash
f5-ipam-controller-5f6b96644d-mzkg7        1/1     Running   0              12d
```

Check the F5 IPAM Controller logs
```bash
kubectl logs -l app=f5-ipam-controller -n kube-system -f
```

Output should be similar to
```bash
2026/09/07 12:31:33 [DEBUG] [STORE] 192.168.2.184 1 production 479f0e4e-9e68-40
2026/09/07 12:31:33 [DEBUG] [STORE] 192.168.2.185 1 production 9ced70a8-7190-42
2026/09/07 12:31:33 [INFO] [CORE] Controller started
2026/09/07 12:31:33 [INFO] Starting IPAMClient Informer
2026/09/07 12:31:33 [DEBUG] [PROV] Provider Initialised
I0907 12:31:33.363516       1 shared_informer.go:240] Waiting for caches to sync for F5 IPAMClient Controller
I0907 12:31:33.463961       1 shared_informer.go:247] Caches are synced for F5 IPAMClient Controller 
2026/09/07 12:31:33 [DEBUG] K8S Orchestrator Started
2026/09/07 12:31:33 [DEBUG] Starting Response Worker
2026/09/07 12:31:33 [DEBUG] Starting Custom Resource Worker
```

## Deploy F5 BIG-IP Container Ingress Services

Apply F5 BIG-IP Container Ingress Services custom resources
```bash
kubectl apply -f https://raw.githubusercontent.com/F5Networks/k8s-bigip-ctlr/v2.20.4/docs/config_examples/customResourceDefinitions/customresourcedefinitions.yml
```

Check configured custom resources
```bash
kubectl get crd | grep cis.f5.com
```

Output should be similar to
```bash
externaldnses.cis.f5.com                              2026-09-07T13:16:09Z
ingresslinks.cis.f5.com                               2026-09-07T13:16:09Z
policies.cis.f5.com                                   2026-09-07T13:16:09Z
tlsprofiles.cis.f5.com                                2026-09-07T13:16:09Z
transportservers.cis.f5.com                           2026-09-07T13:16:09Z
virtualservers.cis.f5.com                             2026-09-07T13:16:09Z
```

Deploy F5 BIG-IP Container Ingress Services using the Helm chart
```bash
helm repo add f5-stable https://f5networks.github.io/charts/stable
helm repo update

helm install f5-cis f5-stable/f5-bigip-ctlr -n kube-system \
  --set bigip_secret.create=true \
  --set bigip_secret.username="$BIGIP_USERNAME" \
  --set bigip_secret.password="$BIGIP_PASSWORD" \
  --set rbac.create=true \
  --set serviceAccount.create=true \
  --set namespace=kube-system \
  --set args.bigip_url="$BIGIP_ADDRESS" \
  --set args.bigip_partition=k8s \
  --set args.pool_member_type=nodeport \
  --set args.custom_resource_mode=true \
  --set args.insecure=true \
  --set args.log_level=DEBUG \
  --set args.log-as3-response=true \
  --set args.ipam=true
```

Check the F5 BIG-IP Container Ingress Services pod status
```bash
kubectl get pods -n kube-system|grep cis
```

Pod should be in the `Running` state
```bash
f5-cis-f5-bigip-ctlr-545f7cbbd4-nrlcl      1/1     Running   0              12d
```

Check F5 BIG-IP Container Ingress Services pod logs
```bash
kubectl logs -n kube-system deploy/f5-cis-f5-bigip-ctlr | grep "authn/login"
```

When the pod starts it authenticates against the F5 BIG-IP system: a successful login is logged as a `200` response
```bash
2026/09/21 09:56:38 [DEBUG] [2026-09-21 09:56:38,146 urllib3.connectionpool DEBUG] https://bigip1.nginx.lab:443 "POST /mgmt/shared/authn/login HTTP/1.1" 200 723
2026/09/21 09:56:39 [DEBUG] [2026-09-21 09:56:39,494 urllib3.connectionpool DEBUG] https://bigip1.nginx.lab:443 "POST /mgmt/shared/authn/login HTTP/1.1" 200 723
```

## Deploy NGINX Gateway Fabric

Create NGINX Gateway Fabric namespace

```bash
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
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" | kubectl apply -f -
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/inference-extension/?ref=v2.7.2" | kubectl apply -f -
```

Install NGINX Gateway Fabric through its Helm chart
```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus \
  --set nginx.image.tag=2.7.2 \
  --set nginx.plus=true \
  --set serviceAccount.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.usage.secretName=nplus-license \
  --set nginx.service.type=LoadBalancer \
  --set nginxGateway.externalLoadBalancer.enable=true \
  --set nginxGateway.snippets.enable=true \
  -n nginx-gateway

kubectl logs -l app.kubernetes.io/instance=ngf -n nginx-gateway -c nginx-gateway
```

Check NGINX Gateway Fabric pod status

```bash
kubectl get pods -n nginx-gateway
```

Pod should be in the `Running` state
```bash
NAME                                        READY   STATUS    RESTARTS   AGE
ngf-nginx-gateway-fabric-584d85664f-skrcs   1/1     Running   0          61m
```

Check NGINX Gateway Fabric logs
```bash
kubectl logs -l app.kubernetes.io/instance=ngf -n nginx-gateway -c nginx-gateway
```

Output should be similar to
```bash
{"level":"info","ts":"2026-09-21T10:00:33Z","msg":"Starting the NGINX Gateway Fabric control plane","version":"2.7.2","commit":"580542620c2290118ba6dba5af7a612e6feaafbc","date":"2026-09-16T16:31:52Z","dirty":"true"}
{"level":"info","ts":"2026-09-21T10:00:33Z","msg":"Starting manager"}
{"level":"info","ts":"2026-09-21T10:00:33Z","logger":"controller-runtime.metrics","msg":"Starting metrics server"}
{"level":"info","ts":"2026-09-21T10:00:33Z","msg":"starting server","name":"health probe","addr":"[::]:8081"}
{"level":"info","ts":"2026-09-21T10:00:33Z","logger":"controller-runtime.metrics","msg":"Serving metrics server","bindAddress":":9113","secure":false}
{"level":"info","ts":"2026-09-21T10:00:33Z","msg":"Attempting to acquire leader lease...","lock":"nginx-gateway/ngf-nginx-gateway-fabric-leader-election"}
{"level":"info","ts":"2026-09-21T10:00:34Z","logger":"eventLoop.eventHandler","msg":"Reconfigured control plane.","batchID":33}
```

## Deploy the gateway

Create the `NginxProxy` object that configures the Gateway that references it with the settings BIG-IP depends on:

* `rewriteClientIP.mode`: `ProxyProtocol` reads the client address from the PROXY protocol header the iRule adds.
* `service.type` sets the type of the Gateway’s Service, and must match the F5 Container Ingress Services `pool_member_type` (see the `helm install f5-cis` command above).
* `readinessProbe.expose` puts the readiness port on the Service, and `readinessProbe.path` sets the path the generated health monitor requests. NGINX Gateway Fabric serves its readiness endpoint at /readyz by default, while the monitor generated by F5 Container Ingress Services requests `/nginx-ready`, so setting the path here makes the two agree.
* `rewriteClientIP.trustedAddresses` lists the addresses NGINX accepts a client address from.

```bash
kubectl apply -f 1.nginxproxy.yaml
```

Create the gateway
```bash
kubectl apply -f 2.gateway.yaml
```

Check the gateway pod status
```bash
kubectl get pods
```

Pod should be in the `Running` state
```bash
NAME                            READY   STATUS    RESTARTS   AGE
gateway-nginx-f8766b867-qm74n   1/1     Running   0          53s
```

Check the gateway status
```bash
kubectl describe gateways.gateway.networking.k8s.io gateway
```

Output should be similar to
```bash
Name:         gateway
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.networking.k8s.io/v1
Kind:         Gateway
Metadata:
  Creation Timestamp:  2026-09-21T10:16:51Z
  Generation:          1
  Resource Version:    229710936
  UID:                 5a34aee4-d265-4588-8514-3584b902da2f
Spec:
  Gateway Class Name:  nginx
  Infrastructure:
    Parameters Ref:
      Group:  gateway.nginx.org
      Kind:   NginxProxy
      Name:   gatewaylink-proxy
  Listeners:
    Allowed Routes:
      Namespaces:
        From:  Same
    Hostname:  cafe.example.com
    Name:      http
    Port:      80
    Protocol:  HTTP
Status:
  Addresses:
    Type:                  IPAddress
    Value:                 10.101.7.178
  Attached Listener Sets:  0
  Conditions:
    Last Transition Time:  2026-09-21T10:16:51Z
    Message:               The Gateway is accepted
    Observed Generation:   1
    Reason:                Accepted
    Status:                True
    Type:                  Accepted
    Last Transition Time:  2026-09-21T10:16:51Z
    Message:               The Gateway is programmed
    Observed Generation:   1
    Reason:                Programmed
    Status:                True
    Type:                  Programmed
    Last Transition Time:  2026-09-21T10:16:51Z
    Message:               The referenced resources are resolved
    Observed Generation:   1
    Reason:                ResolvedRefs
    Status:                True
    Type:                  ResolvedRefs
  Listeners:
    Attached Routes:  0
    Conditions:
      Last Transition Time:  2026-09-21T10:16:51Z
      Message:               The Listener is programmed
      Observed Generation:   1
      Reason:                Programmed
      Status:                True
      Type:                  Programmed
      Last Transition Time:  2026-09-21T10:16:51Z
      Message:               The Listener is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
      Last Transition Time:  2026-09-21T10:16:51Z
      Message:               All references are resolved
      Observed Generation:   1
      Reason:                ResolvedRefs
      Status:                True
      Type:                  ResolvedRefs
      Last Transition Time:  2026-09-21T10:16:51Z
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

## Deploy the test application

Apply the application manifest
```bash
kubectl apply -f 3.coffee.yaml
```

Check that the application pod is `Running`
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                            READY   STATUS    RESTARTS   AGE
coffee-654ddf664b-v2vwm         1/1     Running   0          8s
gateway-nginx-f8766b867-qm74n   1/1     Running   0          2m23s
```

Publish the application through NGINX Gateway Fabric creating `HTTPRoute` objects
```bash
kubectl apply -f 4.httproute.yaml
```

List available `HTTPRoute` objects
```bash
kubectl get httproute
```

Output should be similar to
```bash
NAME     HOSTNAMES              AGE
coffee   ["cafe.example.com"]   18s
```

## Create the external load balancer

Create an `ExternalLoadBalancer` resource
The `.spec.gatewayLink.ipamLabel` field tells the F5 IPAM Controller which address range to allocate from. The value must match a pool name in the `args.ip_range` map used when installing the F5 IPAM Controller
```bash
kubectl apply -f 5.externalLB.yaml
```

Verify the `ExternalLoadBalancer` status is `Accepted`

```bash
kubectl describe externalloadbalancers.gateway.nginx.org gateway-elb
```

Output should be similar to
```bash
Name:         gateway-elb
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         ExternalLoadBalancer
Metadata:
  Creation Timestamp:  2026-09-21T10:22:39Z
  Generation:          1
  Resource Version:    229711975
  UID:                 24cea505-093d-492b-aaf3-03257d864eb2
Spec:
  Gateway Link:
    I Rules:
      /Common/Proxy_Protocol_iRule
    Ipam Label:  production
    Partition:   k8s
  Target Refs:
    Group:  gateway.networking.k8s.io
    Kind:   Gateway
    Name:   gateway
Status:
  Controllers:
    Conditions:
      Last Transition Time:  2026-09-21T10:22:39Z
      Message:               The ExternalLoadBalancer is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
```

Check the `ingresslink` object
```bash
kubectl get ingresslink
```

Output should be similar to
```bash
NAME            IPAMVSADDRESS   AGE
gateway-nginx   192.168.2.180   54s
```

## F5 BIG-IP configuration check

The F5 BIG-IP system should show the LTM Virtual Server correctly configured in the `k8s` user partition

![BIG-IP](/labs/13.ingresslink/bigip.png)

## Application access test

Retrieve the F5 BIG-IP LTM Virtual Server IP address
```bash
VS_ADDRESS=`kubectl get ingresslink gateway-nginx -o jsonpath='{.status.vsAddress}'`
```

Send a test request to the F5 BIG-IP LTM Virtual Server
```bash
curl --resolve cafe.example.com:80:$VS_ADDRESS http://cafe.example.com/coffee
```

## Remove setup

```bash
kubectl delete -f 5.externalLB.yaml
kubectl delete -f 4.httproute.yaml
kubectl delete -f 3.coffee.yaml
kubectl delete -f 2.gateway.yaml
kubectl delete -f 1.nginxproxy.yaml

helm uninstall ngf -n nginx-gateway
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" | kubectl delete -f -
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/inference-extension/?ref=v2.7.2" | kubectl delete -f -
kubectl delete ns nginx-gateway

helm uninstall f5-cis -n kube-system
kubectl delete -f https://raw.githubusercontent.com/F5Networks/k8s-bigip-ctlr/v2.20.4/docs/config_examples/customResourceDefinitions/customresourcedefinitions.yml
helm uninstall f5-ipam-controller -n kube-system
kubectl delete -f 0.cis.yaml
```
