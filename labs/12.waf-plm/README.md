# F5 WAF for NGINX

This use case applies WAF protection to a sample application exposed through NGINX Gateway Fabric using [Policy Lifecycle Manager](https://docs.nginx.com/nginx-gateway-fabric/waf-integration/get-started-plm/)
The NGINX Gateway Fabric is deployed directly in this lab


`cd` into the lab directory
```bash
cd ~/NGINX-Gateway-Fabric-Lab/labs/12.waf-plm
```

## Deploy the test storage provider

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

```bash
kubectl get pods -n local-path-storage
```

Output should be similar to
```bash
NAME                                      READY   STATUS    RESTARTS   AGE
local-path-provisioner-79b7b99b5d-w69vk   1/1     Running   0          24s
```

Set the `storageclass` as default
```bash
kubectl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Check the storage class
```bash
kubectl get storageclass
```

Output should be similar to
```bash
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  17m
```

## Deploy Gateway API CRDs

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" | kubectl apply -f -
```

## Deploy cert-manager 

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.21.2 \
  --namespace cert-manager \  
  --create-namespace \
  --set "extraArgs={--enable-gateway-api}" \
  --set crds.enabled=true
```

Test cert-manager

```bash
kubectl apply -f 0.cert-manager-test.yaml
```

Check the status of the newly created certificate

```bash
kubectl describe certificate -n cert-manager-test
```

Output should be similar to

```bash
Name:         selfsigned-cert
Namespace:    cert-manager-test
Labels:       <none>
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Certificate
Metadata:
  Creation Timestamp:  2026-09-11T10:45:01Z
  Generation:          1
  Resource Version:    143626467
  UID:                 96ce0441-d494-49ca-a3f1-c70c7a49a78c
Spec:
  Dns Names:
    example.com
  Issuer Ref:
    Name:       test-selfsigned
  Secret Name:  selfsigned-cert-tls
Status:
  Conditions:
    Last Transition Time:  2026-09-11T10:45:01Z
    Message:               Certificate is up to date and has not expired
    Observed Generation:   1
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2026-12-10T10:45:01Z
  Not Before:              2026-09-11T10:45:01Z
  Renewal Time:            2026-11-10T10:45:01Z
  Revision:                1
Events:
  Type    Reason     Age   From                                       Message
  ----    ------     ----  ----                                       -------
  Normal  Issuing    3s    cert-manager-certificates-trigger          Issuing certificate as Secret does not exist
  Normal  Generated  3s    cert-manager-certificates-key-manager      Stored new private key in temporary Secret resource "selfsigned-cert-4jzgw"
  Normal  Requested  3s    cert-manager-certificates-request-manager  Created new CertificateRequest resource "selfsigned-cert-1"
  Normal  Issuing    3s    cert-manager-certificates-issuing          The certificate has been successfully issued
```

Remove test objects

```bash
kubectl delete -f 0.cert-manager-test.yaml
```


## Deploy Policy Lifecycle Manager

Create the `plm-system` namespace

```bash
kubectl create namespace plm-system
```

Create the authentication secrets
```bash
kubectl create secret generic jwt-reg-secret \
  --namespace plm-system \
  --from-file=license.jwt=<nginx-one-eval.jwt>

JWT=$(kubectl get secret jwt-reg-secret \
  --namespace plm-system \
  -o jsonpath='{.data.license\.jwt}' | base64 -d)

kubectl create secret docker-registry regcred \
  --namespace plm-system \
  --docker-server=private-registry.nginx.com \
  --docker-username="$JWT" \
  --docker-password=none \
  --dry-run=client --output yaml | kubectl apply -f -
```

Create Policy Lifecycle Manager test certificates
```bash
kubectl apply -f 1.plm-certs.yaml
```

Verify created certificates
```bash
kubectl get certificates -n plm-system
```

Output should be similar to
```bash
NAME               READY   SECRET                             AGE
seaweedfs-ca       True    plm-f5-waf-seaweedfs-ca-cert       7s
seaweedfs-client   True    plm-f5-waf-seaweedfs-client-cert   6s
seaweedfs-filer    True    plm-f5-waf-seaweedfs-filer-cert    6s
seaweedfs-master   True    plm-f5-waf-seaweedfs-master-cert   6s
seaweedfs-volume   True    plm-f5-waf-seaweedfs-volume-cert   6s
```

Base64-encode the NGINX licence certificate and key:

```bash
cat <nginx-one-eval.crt> | base64 -w0 # Base64-encode the NGINX certificate
cat <nginx-one-eval.key> | base64 -w0 # Base64-encode the NGINX key
```

Edit `artifacts/plm-values.yaml` and paste the base64-encoded certificate and key here:

```bash
securityUpdatesRepo:
  cert: "<BASE64_ENCODED_NGINX_CERTIFICATE>"
  key: "<BASE64_ENCODED_NGINX_CERTIFICATE_KEY>"
```

Deploy Policy Lifecycle Manager

```bash
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update nginx-stable

helm upgrade --install plm nginx-stable/f5-waf-policy-controller \
  --version 5.15.0 \
  --namespace plm-system \
  --values ./artifacts/plm-values.yaml
```

Verify the deployment

```bash
kubectl rollout status deployment/plm-seaweedfs-operator \
  --namespace plm-system --timeout=120s
```

Poll SeaweedFS until the pods appear and are ready

```bash
end=$((SECONDS + 300))
until kubectl wait pods \
    --selector app.kubernetes.io/name=seaweedfs \
    --for=condition=Ready \
    --namespace plm-system \
    --timeout=10s 2>/dev/null; do
  if [ $SECONDS -ge $end ]; then
    echo "Timed out waiting for SeaweedFS pods"
    exit 1
  fi
  sleep 5
done
```

Wait for the Policy Controller: this might take a while

```bash
kubectl rollout status deployment/plm-f5-waf-policy-controller \
  --namespace plm-system --timeout=180s
```

Check that everything is up and running. The pods may take a while to reach the `Running` state
```bash
kubectl get pods --namespace plm-system
```

Output should be similar to
```bash
NAME                                            READY   STATUS    RESTARTS   AGE
plm-f5-waf-compiler-service-5c7478b5b4-htc8x    1/1     Running   0          9m51s
plm-f5-waf-policy-controller-7b6f57994f-dzzwt   1/1     Running   0          9m51s
plm-f5-waf-seaweed-filer-0                      1/1     Running   0          9m8s
plm-f5-waf-seaweed-master-0                     1/1     Running   0          9m46s
plm-f5-waf-seaweed-volume-0                     1/1     Running   0          9m8s
plm-f5-waf-seaweed-volume-1                     1/1     Running   0          9m8s
plm-f5-waf-seaweed-volume-2                     1/1     Running   0          9m8s
plm-seaweedfs-operator-6789856b8b-s5qxz         1/1     Running   0          9m51s
```

Check the policy controller logs
```bash
kubectl logs --namespace plm-system deploy/plm-f5-waf-policy-controller -c policy-controller
```

Output should be similar to
```bash
INFO: security updates repo client certificates found.
INFO: HTTP client timeout configured: 5m0s
{"level":"info","ts":"2026-09-11T15:35:44Z","logger":"Policy main","msg":"Variables values","PolicyNamespace":"plm-system","FinalizerName":"appprotect.f5.com/finalizer"}
{"level":"info","ts":"2026-09-11T15:35:44Z","logger":"Policy main","msg":"WATCH_NAMESPACE not set, defaulting to all namespaces"}
{"level":"info","ts":"2026-09-11T15:35:44Z","logger":"Policy main","msg":"Watch scope: all namespaces"}
{"level":"info","ts":"2026-09-11T15:35:44Z","logger":"Policy main","msg":"Initializing S3 client for Policy Store","endpoint":"https://plm-f5-waf-seaweed-filer.plm-system.svc.cluster.local:9333","bucket":"plm-system"}
{"level":"info","ts":"2026-09-11T15:35:44Z","msg":"Creating S3 bucket (namespace)","bucket":"plm-system"}
{"level":"info","ts":"2026-09-11T15:35:44Z","msg":"S3 bucket created successfully","bucket":"plm-system"}
[...]
{"level":"info","ts":"2026-09-11T15:35:44Z","msg":"Found latest .deb file in repository","correlationID":"query-latest-bot-signatures-1789140944683339431","packageType":"app-protect-bot-signatures","distro":"jammy","latestFile":"app-protect-bot-signatures_2026.09.09-1~jammy_amd64.deb","totalMatches":175}
{"level":"info","ts":"2026-09-11T15:35:45Z","msg":"Found latest .deb file in repository","correlationID":"query-latest-threat-campaigns-1789140944836721626","packageType":"app-protect-threat-campaigns","distro":"jammy","latestFile":"app-protect-threat-campaigns_2026.09.10-1~jammy_amd64.deb","totalMatches":165}
{"level":"info","ts":"2026-09-11T15:35:45Z","msg":"Status updated successfully","attempt":1}
{"level":"info","ts":"2026-09-11T15:35:45Z","msg":"No signature packages installed; skipping policy recompilation","correlationID":"apsignatures-1789140944-937024","workKey":"plm-system/apsignatures"}
```

Confirm the WAF CRDs are present
```bash
kubectl get crd | grep appprotect.f5.com
```

Output should be similar to
```bash
aplogconfs.appprotect.f5.com                          2026-09-11T13:50:51Z
appolicies.appprotect.f5.com                          2026-09-11T13:50:51Z
apsignatures.appprotect.f5.com                        2026-09-11T15:34:41Z
apusersigs.appprotect.f5.com                          2026-09-11T13:50:51Z
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

Install NGINX Gateway Fabric through its Helm chart (set `nginx.image.tag` to the latest available NGINX Gateway Fabric version)
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
  --set nginxGateway.plmStorage.url="https://plm-f5-waf-seaweed-filer.plm-system.svc.cluster.local:9333" \
  --set nginxGateway.plmStorage.credentialsSecretName="plm-system/plm-f5-waf-seaweedfs-auth" \
  --set nginxGateway.plmStorage.tls.caSecretName="plm-system/plm-f5-waf-seaweedfs-ca-cert" \
  --set nginxGateway.plmStorage.tls.clientSSLSecretName="plm-system/plm-f5-waf-seaweedfs-client-cert" \
  --set nginxGateway.plmStorage.tls.insecureSkipVerify=true \
  -n nginx-gateway
```

Check NGINX Gateway Fabric pod status

```bash
kubectl get pods -n nginx-gateway
```

Pod should be in the `Running` state

```bash
NAME                                        READY   STATUS    RESTARTS   AGE
ngf-nginx-gateway-fabric-79b644c766-4hg2l   1/1     Running   0          31s
```

Check NGINX Gateway Fabric logs
```bash
kubectl logs -l app.kubernetes.io/instance=ngf -n nginx-gateway -c nginx-gateway
```

Output should be similar to
```bash
{"level":"info","ts":"2026-09-18T10:01:13Z","msg":"Starting the NGINX Gateway Fabric control plane","version":"2.7.2","commit":"580542620c2290118ba6dba5af7a612e6feaafbc","date":"2026-09-16T16:31:52Z","dirty":"true"}
{"level":"info","ts":"2026-09-18T10:01:13Z","msg":"Starting manager"}
{"level":"info","ts":"2026-09-18T10:01:13Z","logger":"controller-runtime.metrics","msg":"Starting metrics server"}
{"level":"info","ts":"2026-09-18T10:01:13Z","msg":"starting server","name":"health probe","addr":"[::]:8081"}
{"level":"info","ts":"2026-09-18T10:01:13Z","logger":"controller-runtime.metrics","msg":"Serving metrics server","bindAddress":":9113","secure":false}
{"level":"info","ts":"2026-09-18T10:01:13Z","msg":"Attempting to acquire leader lease...","lock":"nginx-gateway/ngf-nginx-gateway-fabric-leader-election"}
{"level":"info","ts":"2026-09-18T10:01:13Z","msg":"Successfully acquired lease","lock":"nginx-gateway/ngf-nginx-gateway-fabric-leader-election"}
{"level":"info","ts":"2026-09-18T10:01:13Z","logger":"telemetryJob","msg":"Starting cronjob"}
{"level":"info","ts":"2026-09-18T10:01:13Z","logger":"eventLoop.eventHandler","msg":"Reconfigured control plane.","batchID":23}
```

## Deploy the test application

Apply the application manifest
```bash
kubectl apply -f 7.webapp.yaml
```

Check that the application pod is `Running`
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                         READY   STATUS    RESTARTS   AGE
customers-856f7f8644-22vgp   1/1     Running   0          5s
orders-cccd9bb6d-jb6nv       1/1     Running   0          5s
```


## Deploy the syslog server

Apply the `syslog` manifest
```bash
kubectl apply -f 3.syslog.yaml
```

Check running pods
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                         READY   STATUS    RESTARTS   AGE
customers-856f7f8644-22vgp   1/1     Running   0          5s
orders-cccd9bb6d-jb6nv       1/1     Running   0          5s
syslog-794654b845-62w6m      1/1     Running   0          13m
```

## WAF policy configuration and bundles creation

Create the namespace to hold policies and log profiles

```bash
kubectl create namespace security
```

Create the WAF policy and log profile in the `security` namespace

```bash
kubectl apply -f 4.waf-resources.yaml
```

Wait for WAF policy compilation to complete and bundle to become available

```bash
kubectl wait --for=jsonpath='{.status.bundle.state}'=ready \
  appolicy/attack-signatures --namespace security --timeout=180s
```

Wait for log profile compilation to complete and bundle to become available

```bash
kubectl wait --for=jsonpath='{.status.bundle.state}'=ready \
  aplogconf/log-illegal --namespace security --timeout=180s
```

Check the Policy Lifecycle Manager internal storage location for the WAF policy bundle

```bash
kubectl get appolicy attack-signatures --namespace security \
  --output jsonpath='State: {.status.bundle.state}{"\n"}Location: {.status.bundle.location}{"\n"}'
```

Output should be similar to
```bash
State: ready
Location: s3://security/bundles/attack-signatures20260916160435-attack-signatures-1-1789574675095279200.tgz
```

Check the Policy Lifecycle Manager internal storage location for the WAF log profile bundle
```bash
kubectl get aplogconf log-illegal --namespace security \
  --output jsonpath='State: {.status.bundle.state}{"\n"}Location: {.status.bundle.location}{"\n"}'
```

Output should be similar to
```bash
State: ready
Location: s3://security/bundles/log-illegal20260916160435.tgz
```

The WAF policy and log profile are in the `security` namespace but the `WAFPolicy` about to be created targets a Gateway in the `default` namespace. Create the `ReferenceGrant` object in the `security` namespace
```bash
kubectl apply -f 5.referencegrant.yaml
```

## Deploy the Gateway

Deploy the NGINX Gateway
```bash
kubectl apply -f 6.gateway.yaml
```

Check the pod status
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                             READY   STATUS    RESTARTS   AGE
customers-856f7f8644-22vgp       1/1     Running   0          10m
gateway-nginx-67bb6b4c64-6p8zq   3/3     Running   0          17s
orders-cccd9bb6d-jb6nv           1/1     Running   0          10m
syslog-794654b845-62w6m          1/1     Running   0          23m
```

# Deploy a Gateway-level WAF policy

Create the `WAFPolicy` object
```bash
kubectl apply -f 7.gateway-policy.yaml
```

Check the `WAFPolicy` status
```bash
kubectl describe wafpolicy gateway-base-protection
```

Output should be similar to
```bash
Name:         gateway-base-protection
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         WAFPolicy
Metadata:
  Creation Timestamp:  2026-09-18T14:22:10Z
  Generation:          1
  Resource Version:    146188038
  UID:                 f641ec00-7ce0-4d5a-a2c5-590edcc10aa9
Spec:
  Policy Ref:
    Ap Policy Ref:
      Name:       attack-signatures
      Namespace:  security
  Security Logs:
    Destination:
      Syslog:
        Server:  syslog-svc.default.svc.cluster.local:514
      Type:      syslog
    Log Ref:
      Ap Log Conf Ref:
        Name:       log-illegal
        Namespace:  security
  Target Refs:
    Group:  gateway.networking.k8s.io
    Kind:   Gateway
    Name:   gateway
  Type:     PLM
Status:
  Ancestors:
    Ancestor Ref:
      Group:      gateway.networking.k8s.io
      Kind:       Gateway
      Name:       gateway
      Namespace:  default
    Conditions:
      Last Transition Time:  2026-09-18T14:22:14Z
      Message:               The Policy is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
      Last Transition Time:  2026-09-18T14:22:14Z
      Message:               All references are resolved
      Observed Generation:   1
      Reason:                ResolvedRefs
      Status:                True
      Type:                  ResolvedRefs
      Last Transition Time:  2026-09-18T14:22:14Z
      Message:               Policy is programmed in the data plane
      Observed Generation:   1
      Reason:                Programmed
      Status:                True
      Type:                  Programmed
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
```

Publish the application through NGINX Gateway Fabric creating `HTTPRoute` objects
```bash
kubectl apply -f 8.httproute.yaml
```

List available `HTTPRoute` objects
```bash
kubectl get httproute
```

Output should be similar to
```bash
NAME        HOSTNAMES                AGE
customers   ["webapp.example.com"]   10s
orders      ["webapp.example.com"]   10s
```

Confirm the `APPolicy` and `APLogConf` bundles compiled successfully
```
kubectl get appolicy attack-signatures -n security -o jsonpath='{.status.bundle.state}{"\n"}'
kubectl get aplogconf log-illegal -n security -o jsonpath='{.status.bundle.state}{"\n"}'
```

Both commands should print `ready`

Because the `WAFPolicy` targets the `Gateway`, the `HTTPRoute` inherits WAF protection automatically

WAF policy and log profile are enforced on NGINX Ingress Controller: both bundles are made available to NGINX Ingress Controller
```bash
NGF_POD=$(kubectl get pods \
  --selector app.kubernetes.io/instance=ngf \
  --output jsonpath='{.items[0].metadata.name}')

kubectl exec $NGF_POD --container nginx -- ls -ltr /etc/app_protect/bundles/
```

Output should be similar to
```bash
-rw-r--r-- 1 nginx nginx    1654 Sep 18 14:22 log_security_log-illegal.tgz
-rw-r--r-- 1 nginx nginx 2369813 Sep 18 14:22 security_attack-signatures.tgz
```

Get NGINX Ingress Controller IP and port

```bash
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export NGF_HTTP_PORT=`kubectl get svc gateway-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
echo -e "NGF address: $NGF_IP\nHTTP port  : $NGF_HTTP_PORT"
```

Test application access sending a legitimate request
```bash
curl --resolve webapp.example.com:$NGF_HTTP_PORT:$NGF_IP \
  http://webapp.example.com:$NGF_HTTP_PORT/customers
```

Output should be similar to
```bash
Customer List:

Name: John Doe
Credit Card: 4111-1111-1111-1111
SSN: 123-45-6789
```

Test application access sending a malicious request
```bash
curl --resolve webapp.example.com:$NGF_HTTP_PORT:$NGF_IP \
  "http://webapp.example.com:$NGF_HTTP_PORT/customers?q=<script>alert();</script>"
```

Output should be similar to
```bash
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Connection: close
Cache-Control: no-cache
Pragma: no-cache
Content-Length: 246

<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 2579221527538077499<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

Check WAF violation logs as received by the `syslog` pod
```bash
export SYSLOG_POD_NAME=`kubectl get pods -l app=syslog -o jsonpath='{.items[0].metadata.name}'`
kubectl exec -it $SYSLOG_POD_NAME -- cat /var/log/messages
```

Unpublish the test application through the `Ingress` resource
```bash
kubectl delete -f 6.webapp-ingress.yaml
```

Publish the test application using the `VirtualServer` Custom Resource
```bash
kubectl apply -f 7.webapp-virtualserver.yaml
```

Check the `VirtualServer` object state
```bash
kubectl describe vs webapp
```

Output should be similar to
```bash
Name:         webapp
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  k8s.nginx.org/v1
Kind:         VirtualServer
Metadata:
  Creation Timestamp:  2026-09-11T14:11:14Z
  Generation:          1
  Resource Version:    143667848
  UID:                 efd71aec-6d78-4ffe-a1f9-223471cf7fb2
Spec:
  Host:  webapp.example.com
  Policies:
    Name:  waf-policy
  Routes:
    Action:
      Pass:  webapp
    Path:    /
  Upstreams:
    Name:     webapp
    Port:     80
    Service:  webapp-svc
Status:
  Message:  Configuration for default/webapp was added or updated 
  Reason:   AddedOrUpdated
  State:    Valid
Events:
  Type    Reason          Age   From                      Message
  ----    ------          ----  ----                      -------
  Normal  AddedOrUpdated  1s    nginx-ingress-controller  Configuration for default/webapp was added or updated
```

Test application access sending a legitimate request
```bash
curl --resolve webapp.example.com:$IC_HTTP_PORT:$IC_IP \
  http://webapp.example.com:$IC_HTTP_PORT/test
```

Output should be similar to
```bash
Server address: 10.0.86.1:8080
Server name: webapp-558ff5c8f6-z9khj
Date: 11/Sep/2026:12:53:39 +0000
URI: /test
Request ID: cdaa7ba80b314000f0042b5d07eafda9
```

Test application access sending a malicious request
```bash
curl -i --resolve webapp.example.com:$IC_HTTP_PORT:$IC_IP \
  "http://webapp.example.com:$IC_HTTP_PORT/test?q=<script>alert();</script>"
```

Output should be similar to
```bash
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Connection: close
Cache-Control: no-cache
Pragma: no-cache
Content-Length: 246

<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 7559188820450840156<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

Check WAF violation logs as received by the `syslog` pod
```bash
export SYSLOG_POD_NAME=`kubectl get pods -l app=syslog -o jsonpath='{.items[0].metadata.name}'`
kubectl exec -it $SYSLOG_POD_NAME -- cat /var/log/messages
```

## Apply an HTTPRoute-level WAF policy

Create a dataguard WAF policy
```bash
kubectl apply -f 9.dataguard-policy.yaml
```

Wait for policy compilation to complete
```bash
kubectl wait --for=jsonpath='{.status.bundle.state}'=ready appolicy/dataguard-blocking -n security --timeout=60s
```

Apply the policy to the `HTTPRoute`
```bash
kubectl apply -f 10.httproute-policy.yaml
```

Wait for the policy to be `Programmed`
```bash
kubectl wait --for=jsonpath='{.status.ancestors[0].conditions[?(@.type=="Programmed")].status}'=True wafpolicy/customers-strict-protection --timeout=60s
```

Send an application request
```bash
curl --resolve webapp.example.com:$NGF_HTTP_PORT:$NGF_IP \
  http://webapp.example.com:$NGF_HTTP_PORT/customers
```

Output should be similar to
```bash
Customer List:

Name: John Doe
Credit Card: ***************1111
SSN: *******6789
```

Check WAF violation logs as received by the `syslog` pod
```bash
export SYSLOG_POD_NAME=`kubectl get pods -l app=syslog -o jsonpath='{.items[0].metadata.name}'`
kubectl exec -it $SYSLOG_POD_NAME -- cat /var/log/messages
```

The WAF now masks the credit card number and SSN in the response

## Delete the lab

```bash
kubectl delete \
  -f 10.httproute-policy.yaml -f 9.dataguard-policy.yaml -f 8.httproute.yaml \
  -f 7.gateway-policy.yaml -f 6.gateway.yaml -f 5.referencegrant.yaml \
  -f 4.waf-resources.yaml -f 3.syslog.yaml -f 2.webapp.yaml

helm uninstall ngf -n nginx-gateway
kubectl delete ns nginx-gateway

helm uninstall plm -n plm-system
kubectl delete ns plm-system

kubectl delete ns security

helm uninstall cert-manager -n cert-manager
kubectl delete ns cert-manager

kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```
