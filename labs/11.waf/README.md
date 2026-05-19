# F5 WAF for NGINX

This use case shows how to use F5 WAF for NGINX to protect applications published through NGINX Gateway Fabric

`cd` into the lab directory
```bash
cd ~/NGINX-Gateway-Fabric-Lab/labs/11.waf
```

Deploy two sample applications
```bash
kubectl apply -f 0.apps.yaml
```

Verify that all pods are in the `Running` state
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                         READY   STATUS    RESTARTS   AGE
customers-856f7f8644-rmzf8   1/1     Running   0          10s
tea-75bc9f4b6d-8bh4v         1/1     Running   0          10s
```

Deploy the syslog service to receive F5 WAF for NGINX security violations logs
```bash
kubectl apply -f 1.syslog.yaml
```

Check the syslog pod status
```bash
kubectl get pods
```

Output should be similar to
```bash
NAME                             READY   STATUS    RESTARTS   AGE
customers-856f7f8644-rmzf8       1/1     Running   0          155m
syslog-5fb46bc5c-xll4h           1/1     Running   0          29s
tea-75bc9f4b6d-8bh4v             1/1     Running   0          155m
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace, with WAF enabled
```bash
kubectl apply -f 2.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

The `gateway-nginx-65d8cf589b-8kf8h` pod is the NGINX Gateway Fabric dataplane
```bash
NAME                           READY   STATUS    RESTARTS   AGE
customers-856f7f8644-rmzf8     1/1     Running   0          35s
gateway-nginx-cddb6676-6dwwk   3/4     Running   0          12s
syslog-5fb46bc5c-xll4h         1/1     Running   0          29s
tea-75bc9f4b6d-8bh4v           1/1     Running   0          35s
```

Check the gateway
```bash
kubectl get gateway
```

Output should be similar to
```bash
NAME      CLASS   ADDRESS          PROGRAMMED   AGE
gateway   nginx   10.105.125.233   True         19s
```

Check the NGINX Gateway Fabric Service
```bash
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```bash
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
customers       ClusterIP   10.101.30.11     <none>        80/TCP         52s
gateway-nginx   NodePort    10.105.125.233   <none>        80:32281/TCP   29s
kubernetes      ClusterIP   10.96.0.1        <none>        443/TCP        609d
tea             ClusterIP   10.101.32.95     <none>        80/TCP         52s
```

Create the HTTP routes
```bash
kubectl apply -f 3.httproute.yaml
```

Check the HTTP routes
```bash
kubectl get httproute
```

Output should be similar to
```bash
NAME        HOSTNAMES              AGE
customers   ["cafe.example.com"]   3s
tea         ["cafe.example.com"]   3s
```

Create the WAF policy definitions `ConfigMap`. Two policies are defined:

* `attack-signatures-blocking` blocks common attack signatures such as cross-site scripting (XSS) and SQL injection
* `dataguard-blocking` masks sensitive data such as credit card numbers and Social Security numbers in response bodies

The bundle server will compile these into `.tgz` bundles at startup.
```bash
kubectl apply -f 4.policies.yaml
```

Deploy the WAF policy bundle server: it compiles both policies and serves them over HTTP
```bash
kubectl apply -f 5.bundleserver.yaml
```

Wait for deployment and policy compilation to complete
```bash
kubectl wait --for=condition=Available deployment/bundle-server --timeout=120s
```

Check bundle server status
```
kubectl get pods
```

The `bundle-server-6849977c89-hz6ff` pod is responsible for policy compilation into `.tgz` bundles
```bash
NAME                             READY   STATUS    RESTARTS   AGE
bundle-server-6849977c89-hz6ff   1/1     Running   0          3m53s
customers-856f7f8644-rmzf8       1/1     Running   0          5m25s
gateway-nginx-cddb6676-6dwwk     4/4     Running   0          5m2s
syslog-5fb46bc5c-xll4h           1/1     Running   0          5m10s
tea-75bc9f4b6d-8bh4v             1/1     Running   0          5m25s
```

Apply the `attack-signatures-blocking` WAF policy at the `Gateway` level. This policy blocks common attack signatures such as cross-site scripting (XSS) and SQL injection
```bash
kubectl apply -f 6.applywaf.yaml
```

Verify the WAF policy has been accepted and programmed
```bash
kubectl describe wafpolicy gateway-base-protection
```

All conditions should be set to `True` and output should be similar to
```bash
Name:         gateway-base-protection
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         WAFPolicy
Metadata:
  Creation Timestamp:  2026-05-19T09:11:16Z
  Generation:          1
  Resource Version:    117468134
  UID:                 c2be9a18-e7f0-4d10-8be3-b47f7ebaef36
Spec:
  Policy Source:
    Http Source:
      URL:           http://bundle-server.default.svc.cluster.local/attack-signatures-blocking.tgz
    Retry Attempts:  3
  Security Logs:
    Destination:
      Type:  stderr
    Log Source:
      Default Profile:  log_blocked
      Retry Attempts:   3
  Target Refs:
    Group:  gateway.networking.k8s.io
    Kind:   Gateway
    Name:   gateway
  Type:     HTTP
Status:
  Ancestors:
    Ancestor Ref:
      Group:      gateway.networking.k8s.io
      Kind:       Gateway
      Name:       gateway
      Namespace:  default
    Conditions:
      Last Transition Time:  2026-05-19T09:11:21Z
      Message:               The Policy is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
      Last Transition Time:  2026-05-19T09:11:21Z
      Message:               All references are resolved
      Observed Generation:   1
      Reason:                ResolvedRefs
      Status:                True
      Type:                  ResolvedRefs
      Last Transition Time:  2026-05-19T09:11:21Z
      Message:               Policy is programmed in the data plane
      Observed Generation:   1
      Reason:                Programmed
      Status:                True
      Type:                  Programmed
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```bash
export NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -o json|jq '.items[0].status.hostIP' -r`
export HTTP_PORT=`kubectl get svc gateway-nginx -o jsonpath='{.spec.ports[0].nodePort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```bash
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

In a separate shell display the syslog output
```bash
kubectl exec -it "$(kubectl get pod -l app=syslog -o jsonpath='{.items[0].metadata.name}')" -- tail -f /var/log/messages
```

Test application access
```bash
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/customers
```

Output should be similar to
```bash
Customer List:

Name: John Doe
Credit Card: 4111-1111-1111-1111
SSN: 123-45-6789
```

The sensitive data passes through because the gateway-level `attack-signatures-blocking` policy only inspects inbound requests for attack patterns: it does not mask outbound response data.

Verify attacks are blocked. Send a request with a cross-site scripting (XSS) payload
```bash
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP "http://cafe.example.com:$HTTP_PORT/customers?x=</script>"
```

Output should be similar to
```bash
<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 14384284410244417109<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

`syslog` should show the security violation being logged, similar to
```bash
May 19 15:59:59 gateway-nginx-cddb6676-dz668 ASM:attack_type="Non-browser Client,Abuse of Functionality,Cross Site Scripting (XSS),Other Application Activity",blocking_exception_reason="N/A",date_time="2026-05-19 15:59:58",dest_port="80",[...]
```

Since the `attack-signatures-blocking` policy is applied at the gateway level, all routes are protected by default
```bash
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP "http://cafe.example.com:$HTTP_PORT/tea?x=</script>"
```

Output should be similar to
```bash
<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 3293264971173386843<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

`syslog` should show the security violation being logged

Apply a route-level override using the `dataguard-blocking` WAF policy
```bash
kubectl apply -f 7.routewafoverride.yaml
```

Wait for the policy to get to the `Programmed` state
```bash
kubectl wait --for=jsonpath='{.status.ancestors[0].conditions[?(@.type=="Programmed")].status}'=True wafpolicy/customers-strict-protection --timeout=60s
```

Send the initial request again
```bash
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/customers
```

Output should be similar to
```bash
Customer List:

Name: John Doe
Credit Card: ***************1111
SSN: *******6789
```

`syslog` should show the security violation being logged, similar to


Delete the lab

```bash
kubectl delete -f .
```
