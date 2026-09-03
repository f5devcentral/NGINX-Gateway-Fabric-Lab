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
customers-856f7f8644-fw2j2   1/1     Running   0          12s
tea-75bc9f4b6d-p24dj         1/1     Running   0          12s
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
NAME                         READY   STATUS    RESTARTS   AGE
customers-856f7f8644-fw2j2   1/1     Running   0          82s
syslog-b9db868b7-4trvp       1/1     Running   0          55s
tea-75bc9f4b6d-p24dj         1/1     Running   0          82s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace, with WAF enabled
```bash
kubectl apply -f 2.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

The `gateway-nginx-68d68854d7-4rfrf` pod is the NGINX Gateway Fabric dataplane
```bash
NAME                             READY   STATUS    RESTARTS   AGE
customers-856f7f8644-fw2j2       1/1     Running   0          2m27s
gateway-nginx-68d68854d7-4rfrf   4/4     Running   0          54s
syslog-b9db868b7-4trvp           1/1     Running   0          2m
tea-75bc9f4b6d-p24dj             1/1     Running   0          2m27s
```

Check the gateway
```bash
kubectl get gateway
```

Output should be similar to
```bash
NAME      CLASS   ADDRESS          PROGRAMMED   AGE
gateway   nginx   10.107.219.135   True         79s
```

Check the NGINX Gateway Fabric Service
```bash
kubectl get service
```

`gateway-nginx` is the NGINX Gateway Fabric dataplane service
```bash
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
customers       ClusterIP   10.97.227.71     <none>        80/TCP         3m1s
gateway-nginx   NodePort    10.107.219.135   <none>        80:31628/TCP   88s
kubernetes      ClusterIP   10.96.0.1        <none>        443/TCP        2y360d
syslog-svc      ClusterIP   10.102.58.80     <none>        514/TCP        2m34s
tea             ClusterIP   10.101.137.233   <none>        80/TCP         3m1s
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
customers   ["cafe.example.com"]   7s
tea         ["cafe.example.com"]   7s
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
bundle-server-64f4955f49-gs4sx   1/1     Running   0          111s
customers-856f7f8644-fw2j2       1/1     Running   0          5m25s
gateway-nginx-68d68854d7-4rfrf   4/4     Running   0          3m52s
syslog-b9db868b7-4trvp           1/1     Running   0          4m58s
tea-75bc9f4b6d-p24dj             1/1     Running   0          5m25s
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
  Creation Timestamp:  2026-09-03T07:38:48Z
  Generation:          1
  Resource Version:    225382186
  UID:                 c22dd9e5-90c1-453f-b6c3-2635fad5c8e3
Spec:
  Policy Source:
    Http Source:
      URL:           http://bundle-server.default.svc.cluster.local/attack-signatures-blocking.tgz
    Retry Attempts:  3
  Security Logs:
    Destination:
      Syslog:
        Server:  syslog-svc:514
      Type:      syslog
    Log Source:
      Default Profile:  log_blocked
      Retry Attempts:   3
  Target Refs:
    Group:  gateway.networking.k8s.io
    Kind:   Gateway
    Name:   gateway
  Type:     HTTP
Events:     <none>
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
<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 7582683759784056240<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
```

`syslog` should show the security violation being logged, similar to
```bash
Sep  3 07:39:40 gateway-nginx-68d68854d7-4rfrf ASM:attack_type="Non-browser Client,Abuse of Functionality,Cross Site Scripting (XSS),Other Application Activity",blocking_exception_reason="N/A",date_time="2026-09-03 07:39:40",dest_port="80",ip_client="192.168.2.26",is_truncated="false",method="GET",policy_name="attack-signatures-blocking",protocol="HTTP",request_status="blocked",response_code="0",severity="Critical",sig_cves="N/A,N/A",sig_ids="200001475,200000098",sig_names="XSS script tag end (Parameter) (2),XSS script tag (Parameter)",sig_set_names="{High Accuracy Signatures;Cross Site Scripting Signatures;All Signatures},{High Accuracy Signatures;Cross Site Scripting Signatures;All Signatures}",src_port="55426",sub_violations="N/A",support_id="7582683759784056240",threat_campaign_names="N/A",unit_hostname="gateway-nginx-68d68854d7-4rfrf",uri="/customers",violation_rating="5",vs_name="56-cafe.example.com:3-/customers",x_forwarded_for_header_value="N/A",outcome="REJECTED",outcome_reason="SECURITY_WAF_VIOLATION",violations="Illegal meta character in value,Attack signature detected,Violation Rating Threat detected,Bot Client Detected",json_log="{""id"":""7582683759784056240"",""violations"":[{""enforcementState"":{""isBlocked"":true,""isAlarmed"":true,""isInStaging"":false,""isLearned"":false,""isLikelyFalsePositive"":false,""attackType"":[{""name"":""Cross Site Scripting (XSS)""}]},""violation"":{""name"":""VIOL_ATTACK_SIGNATURE""},""signature"":{""name"":""XSS script tag end (Parameter) (2)"",""signatureId"":200001475,""accuracy"":""high"",""risk"":""high"",""hasCve"":false,""stagingCertificationDatetime"":""1970-01-01T00:00:00Z"",""lastUpdateTime"":""2025-01-08T16:57:22Z""},""snippet"":{""buffer"":""eD08L3NjcmlwdD4="",""offset"":4,""length"":7},""policyEntity"":{""parameters"":[{""name"":""*"",""level"":""global"",""type"":""wildcard""}]},""observedEntity"":{""name"":""eA=="",""value"":""PC9zY3JpcHQ+"",""location"":""query""}},{""enforcementState"":{""isBlocked"":true,""isAlarmed"":true,""isInStaging"":false,""isLearned"":false,""isLikelyFalsePositive"":false,""attackType"":[{""name"":""Cross Site Scripting (XSS)""}]},""violation"":{""name"":""VIOL_ATTACK_SIGNATURE""},""signature"":{""name"":""XSS script tag (Parameter)"",""signatureId"":200000098,""accuracy"":""high"",""risk"":""high"",""hasCve"":false,""stagingCertificationDatetime"":""1970-01-01T00:00:00Z"",""lastUpdateTime"":""2023-11-02T19:36:54Z""},""snippet"":{""buffer"":""eD08L3NjcmlwdD4="",""offset"":2,""length"":8},""policyEntity"":{""parameters"":[{""name"":""*"",""level"":""global"",""type"":""wildcard""}]},""observedEntity"":{""name"":""eA=="",""value"":""PC9zY3JpcHQ+"",""location"":""query""}},{""enforcementState"":{""isBlocked"":false,""isAlarmed"":true,""isLearned"":false,""attackType"":[{""name"":""Abuse of Functionality""}]},""violation"":{""name"":""VIOL_PARAMETER_VALUE_METACHAR""},""policyEntity"":{""parameters"":[{""name"":""*"",""level"":""global"",""type"":""wildcard""}]},""observedEntity"":{""name"":""eA=="",""value"":""PC9zY3JpcHQ+"",""location"":""query""},""metachar"":""0x3c"",""charsetType"":""parameter-value""},{""enforcementState"":{""isBlocked"":false,""isAlarmed"":true,""isLearned"":false,""attackType"":[{""name"":""Abuse of Functionality""}]},""violation"":{""name"":""VIOL_PARAMETER_VALUE_METACHAR""},""policyEntity"":{""parameters"":[{""name"":""*"",""level"":""global"",""type"":""wildcard""}]},""observedEntity"":{""name"":""eA=="",""value"":""PC9zY3JpcHQ+"",""location"":""query""},""metachar"":""0x3e"",""charsetType"":""parameter-value""},{""enforcementState"":{""isBlocked"":false,""isAlarmed"":true,""isLearned"":true,""attackType"":[{""name"":""Non-browser Client""}]},""violation"":{""name"":""VIOL_BOT_CLIENT""},""botSignature"":{""name"":""curl"",""category"":""HTTP Library"",""botClass"":""Untrusted Bot""}},{""enforcementState"":{""isBlocked"":true,""isAlarmed"":true,""attackType"":[{""name"":""Other Application Activity""}]},""violation"":{""name"":""VIOL_RATING_THREAT""}}],""enforcementAction"":""block"",""method"":""GET"",""clientPort"":55426,""clientIp"":""192.168.2.26"",""host"":""gateway-nginx-68d68854d7-4rfrf"",""responseCode"":0,""serverIp"":""0.0.0.0"",""serverPort"":80,""requestStatus"":""blocked"",""url"":""L2N1c3RvbWVycw=="",""virtualServerName"":""56-cafe.example.com:3-/customers"",""geolocationCountryCode"":""N/A"",""enforcementState"":{""isBlocked"":true,""isAlarmed"":true,""rating"":5,""attackType"":[{""name"":""Non-browser Client""},{""name"":""Abuse of Functionality""},{""name"":""Cross Site Scripting (XSS)""},{""name"":""Other Application Activity""}],""ratingIncludingViolationsInStaging"":5,""stagingCertificationDatetime"":""1970-01-01T00:00:00Z""},""requestDatetime"":""2026-09-03T07:39:40Z"",""rawRequest"":{""actualSize"":106,""httpRequest"":""R0VUIC9jdXN0b21lcnM/eD08L3NjcmlwdD4gSFRUUC8xLjENCkhvc3Q6IGNhZmUuZXhhbXBsZS5jb206MzE2MjgNClVzZXItQWdlbnQ6IGN1cmwvOC41LjANCkFjY2VwdDogKi8qDQoNCg=="",""isTruncated"":false},""requestPolicy"":{""fullPath"":""attack-signatures-blocking""}}",violation_details="<?xml version='1.0' encoding='UTF-8'?><BAD_MSG><violation_masks><block>414000000200c00-3a03030c30000072-8000000000000000-0</block><alarm>475f0ffcbbd0fea-befbf35cb000007e-f400000000000000-0</alarm><learn>0-0-0-0</learn><staging>0-0-0-0</staging></violation_masks><request-violations><violation><viol_index>42</viol_index><viol_name>VIOL_ATTACK_SIGNATURE</viol_name><context>parameter</context><parameter_data><value_error/><enforcement_level>global</enforcement_level><name>eA==</name><auto_detected_type>alpha-numeric</auto_detected_type><value>PC9zY3JpcHQ+</value><location>query</location><expected_location></expected_location><is_base64_decoded>false</is_base64_decoded><param_name_pattern>*</param_name_pattern><staging>0</staging></parameter_data><staging>0</staging><sig_data><sig_id>200001475</sig_id><blocking_mask>3</blocking_mask><kw_data><buffer>eD08L3NjcmlwdD4=</buffer><offset>4</offset><length>7</length></kw_data></sig_data><sig_data><sig_id>200000098</sig_id><blocking_mask>3</blocking_mask><kw_data><buffer>eD08L3NjcmlwdD4=</buffer><offset>2</offset><length>8</length></kw_data></sig_data></violation><violation><viol_index>24</viol_index><viol_name>VIOL_PARAMETER_VALUE_METACHAR</viol_name><parameter_data><value_error/><enforcement_level>global</enforcement_level><name>eA==</name><auto_detected_type>alpha-numeric</auto_detected_type><value>PC9zY3JpcHQ+</value><location>query</location><expected_location></expected_location><is_base64_decoded>false</is_base64_decoded></parameter_data><wildcard_entity>*</wildcard_entity><staging>0</staging><language_type>4</language_type><metachar_index>60</metachar_index><metachar_index>62</metachar_index></violation><violation><viol_index>122</viol_index><viol_name>VIOL_BOT_CLIENT</viol_name></violation><violation><viol_index>93</viol_index><viol_name>VIOL_RATING_THREAT</viol_name></violation></request-violations></BAD_MSG>",bot_signature_name="curl",bot_category="HTTP Library",bot_anomalies="N/A",enforced_bot_anomalies="N/A",client_class="Untrusted Bot",client_application="N/A",client_application_version="N/A",request="GET /customers?x=</script> HTTP/1.1\r\nHost: cafe.example.com:31628\r\nUser-Agent: curl/8.5.0\r\nAccept: */*\r\n\r\n",transport_protocol="HTTP/1.1"
```

Since the `attack-signatures-blocking` policy is applied at the gateway level, all routes are protected by default
```bash
curl --resolve cafe.example.com:$HTTP_PORT:$NGF_IP "http://cafe.example.com:$HTTP_PORT/tea?x=</script>"
```

Output should be similar to
```bash
<html><head><title>Request Rejected</title></head><body>The requested URL was rejected. Please consult with your administrator.<br><br>Your support ID is: 9497306853831215571<br><br><a href='javascript:history.back();'>[Go Back]</a></body></html>
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
```bash
Sep  3 07:41:14 gateway-nginx-68d68854d7-4rfrf ASM:attack_type="Non-browser Client,Information Leakage",blocking_exception_reason="N/A",date_time="2026-09-03 07:41:14",dest_port="80",ip_client="192.168.2.26",is_truncated="false",method="GET",policy_name="dataguard-blocking",protocol="HTTP",request_status="alerted",response_code="200",severity="Critical",sig_cves="N/A",sig_ids="N/A",sig_names="N/A",sig_set_names="N/A",src_port="42994",sub_violations="N/A",support_id="7624501502690286169",threat_campaign_names="N/A",unit_hostname="gateway-nginx-68d68854d7-4rfrf",uri="/customers",violation_rating="5",vs_name="56-cafe.example.com:3-/customers",x_forwarded_for_header_value="N/A",outcome="PASSED",outcome_reason="SECURITY_WAF_FLAGGED",violations="Data Guard: Information leakage detected,Bot Client Detected",json_log="{""id"":""7624501502690286169"",""violations"":[{""enforcementState"":{""isBlocked"":false,""isAlarmed"":true,""isLearned"":true,""attackType"":[{""name"":""Non-browser Client""}]},""violation"":{""name"":""VIOL_BOT_CLIENT""},""botSignature"":{""name"":""curl"",""category"":""HTTP Library"",""botClass"":""Untrusted Bot""}},{""enforcementState"":{""isBlocked"":false,""isAlarmed"":true,""attackType"":[{""name"":""Information Leakage""}]},""violation"":{""name"":""VIOL_DATA_GUARD""}}],""enforcementAction"":""none"",""method"":""GET"",""clientPort"":42994,""clientIp"":""192.168.2.26"",""host"":""gateway-nginx-68d68854d7-4rfrf"",""responseCode"":200,""serverIp"":""0.0.0.0"",""serverPort"":80,""requestStatus"":""alerted"",""url"":""L2N1c3RvbWVycw=="",""virtualServerName"":""56-cafe.example.com:3-/customers"",""geolocationCountryCode"":""N/A"",""enforcementState"":{""isBlocked"":false,""isAlarmed"":false,""rating"":5,""attackType"":[{""name"":""Non-browser Client""},{""name"":""Information Leakage""}],""ratingIncludingViolationsInStaging"":5,""stagingCertificationDatetime"":""1970-01-01T00:00:00Z""},""requestDatetime"":""2026-09-03T07:41:14Z"",""rawRequest"":{""actualSize"":94,""httpRequest"":""R0VUIC9jdXN0b21lcnMgSFRUUC8xLjENCkhvc3Q6IGNhZmUuZXhhbXBsZS5jb206MzE2MjgNClVzZXItQWdlbnQ6IGN1cmwvOC41LjANCkFjY2VwdDogKi8qDQoNCg=="",""isTruncated"":false},""requestPolicy"":{""fullPath"":""dataguard-blocking""}}",violation_details="<?xml version='1.0' encoding='UTF-8'?><BAD_MSG><violation_masks><block>414000000000c00-3a03030c30000072-8000000000000000-0</block><alarm>2475f0ffcb9d0fea-befbf35cb000007e-f400000000000000-0</alarm><learn>0-0-0-0</learn><staging>0-0-0-0</staging></violation_masks><request-violations><violation><viol_index>122</viol_index><viol_name>VIOL_BOT_CLIENT</viol_name></violation></request-violations><response_violations><violation><viol_index>2</viol_index><viol_name>VIOL_DATA_GUARD</viol_name><leakage_type>illegal_pattern</leakage_type><pattern_type>CCN</pattern_type><cfg_target>L2N1c3RvbWVycw==</cfg_target><string>YXJkOiAqKioqKgpTU046</string></violation><violation><viol_index>2</viol_index><viol_name>VIOL_DATA_GUARD</viol_name><leakage_type>illegal_pattern</leakage_type><pattern_type>SSN</pattern_type><cfg_target>L2N1c3RvbWVycw==</cfg_target><string>U1NOOiAqKioqKgoK</string></violation></response_violations></BAD_MSG>",bot_signature_name="curl",bot_category="HTTP Library",bot_anomalies="N/A",enforced_bot_anomalies="N/A",client_class="Untrusted Bot",client_application="N/A",client_application_version="N/A",request="GET /customers HTTP/1.1\r\nHost: cafe.example.com:31628\r\nUser-Agent: curl/8.5.0\r\nAccept: */*\r\n\r\n",transport_protocol="HTTP/1.1"
```

Delete the lab

```bash
kubectl delete -f .
```
