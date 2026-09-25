# NGINX Gateway Fabric and ExternalDNS integration

This lab demonstrates how to integrate NGINX Gateway Fabric with [ExternalDNS](https://kubernetes-sigs.github.io/external-dns/latest/) to automatically publish Gateway API route hostnames as DNS records in PowerDNS

The NGINX Gateway Fabric is deployed directly in this lab

`cd` into the lab directory
```bash
cd ~/NGINX-Gateway-Fabric-Lab/labs/14.externaldns

## Deploy MetalLB

> [!NOTE]
> MetalLB must be deployed only if the Kubernetes cluster has no `LoadBalancer` service type implementation

NGINX Gateway Fabric will be deployed in `LoadBalancer` mode and MetalLB is necessary to provide the service
MetalLB documentation is available [here](https://metallb.universe.tf/installation/)

If you’re using kube-proxy in IPVS mode, since Kubernetes v1.14.2 you have to enable strict ARP mode
Note, you don’t need this if you’re using kube-router as service-proxy because it is enabling strict ARP by default

Verify the changes that would be made
```bash
kubectl get configmap kube-proxy -n kube-system -o yaml | \
  sed -e "s/strictARP: false/strictARP: true/" | \
  kubectl diff -f - -n kube-system
```

Apply the changes
```bash
kubectl get configmap kube-proxy -n kube-system -o yaml | \
  sed -e "s/strictARP: false/strictARP: true/" | \
  kubectl apply -f - -n kube-system
```

Add the helm chart
```bash
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb
```

Deploy MetalLB
```bash
helm install metallb metallb/metallb -n metallb-system --create-namespace
```

Check MetalLB pods status
```bash
kubectl get pods -n metallb-system
```

Output should be similar to
```bash
NAME                                            READY   STATUS    RESTARTS   AGE
metallb-controller-55846b4849-94292             1/1     Running   0          5m16s
metallb-frr-k8s-r2b67                           5/5     Running   0          5m16s
metallb-frr-k8s-spzrk                           5/5     Running   0          5m15s
metallb-frr-k8s-statuscleaner-8bf664555-cxrlw   1/1     Running   0          5m16s
metallb-frr-k8s-vvnzk                           5/5     Running   0          5m15s
metallb-speaker-4nksb                           1/1     Running   0          5m15s
metallb-speaker-fkfvs                           1/1     Running   0          43s
metallb-speaker-k8xt8                           1/1     Running   0          5m15s
```

Create the IP Address pool MetalLB manages
```bash
kubectl apply -f 0.ipaddresspool.yaml 
```

Check the IP Address pool status
```bash
kubectl get ipaddresspool -A
```

Output should be similar to
```bash
NAMESPACE        NAME         AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
metallb-system   first-pool   true          false             ["192.168.2.200-192.168.2.205"]
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
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" | kubectl apply -f -
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/inference-extension/?ref=v2.7.2" | kubectl apply -f -
```

Install NGINX Gateway Fabric through its Helm chart
```bash
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --set nginx.image.repository=private-registry.nginx.com/nginx-gateway-fabric/nginx-plus-f5waf \
  --set nginx.image.tag=2.7.2 \
  --set nginx.plus=true \
  --set nginx.config.waf.enable=true \
  --set serviceAccount.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.imagePullSecret=nginx-plus-registry-secret \
  --set nginx.usage.secretName=nplus-license \
  --set nginx.service.type=LoadBalancer \
  --set nginxGateway.snippets.enable=true \
  --set nginxGateway.gwAPIInferenceExtension.enable=true \
  -n nginx-gateway
```

Check NGINX Gateway Fabric pod status

```bash
kubectl get pods -n nginx-gateway
```

Pod should be in the `Running` state

```bash
NAME                                            READY   STATUS      RESTARTS   AGE
ngf-nginx-gateway-fabric-984798446-f422t        1/1     Running     0          26s
```

## Deploy the storage provider

The storage provider is used by PowerDNS' backend PostgreSQL
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

Check the pod status
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

Output should be similar to
```bash
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  17m
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

## Deploy PowerDNS

Create the PowerDNS namespace
```bash
kubectl create namespace powerdns
```

Download the PowerDNS PostgreSQL backend schema
```bash
curl -fL \
  https://raw.githubusercontent.com/PowerDNS/pdns/rel/auth-5.1.x/modules/gpgsqlbackend/schema.pgsql.sql \
  -o artifacts/schema.pgsql.sql
```

Create a ConfigMap with the schema
```bash
kubectl -n powerdns create configmap powerdns-pgsql-schema \
  --from-file=artifacts/schema.pgsql.sql
```

Create the PowerDNS API and PostgreSQL database Secrets
```bash
kubectl -n powerdns create secret generic powerdns-api \
  --from-literal=api-key="SAMPLE-PDNS-API-SECRET"

kubectl -n powerdns create secret generic powerdns-postgres \
  --from-literal=POSTGRES_PASSWORD="SAMPLE_PSQL_PASSWORD"
```

Create the secret holding the PowerDNS configuration
```bash
kubectl -n powerdns create secret generic powerdns-config \
  --from-file=pdns.conf=artifacts/pdns.conf
```

Apply the PowerDNS manifests
```bash
kubectl apply -f 1.powerdns.yaml
```

Wait for PostgreSQL and PowerDNS to complete deployment
```bash
kubectl -n powerdns rollout status statefulset/postgres
kubectl -n powerdns rollout status statefulset/powerdns
```

Check running pods
```bash
kubectl -n powerdns get pods
```

Output should be similar to
```bash
NAME         READY   STATUS    RESTARTS   AGE
postgres-0   1/1     Running   0          15m
powerdns-0   1/1     Running   0          15m
```

Check PowerDNS logs
```bash
kubectl logs statefulset/powerdns -n powerdns -c powerdns
```

Output should be similar to
```bash
Sep 25 13:26:13 Loading '/usr/local/lib/pdns/libgpgsqlbackend.so'
Sep 25 13:26:13 This is a standalone pdns
Sep 25 13:26:13 Listening on controlsocket in '/var/run/pdns/pdns.controlsocket'
Sep 25 13:26:13 UDP server bound to 0.0.0.0:10053
Sep 25 13:26:13 TCP server bound to 0.0.0.0:10053
Sep 25 13:26:13 PowerDNS Authoritative Server 5.1.4 (C) PowerDNS.COM BV
Sep 25 13:26:13 Using 64-bits mode. Built using gcc 14.2.0 on Aug  5 2026 13:18:43 by root@localhost.
Sep 25 13:26:13 PowerDNS comes with ABSOLUTELY NO WARRANTY. This is free software, and you are welcome to redistribute it according to the terms of the GPL version 2.
Sep 25 13:26:13 [webserver] Listening for HTTP requests on 0.0.0.0:8081
Sep 25 13:26:13 Polled security status of version 5.1.4 at startup, no known issues reported: OK
Sep 25 13:26:13 Creating backend connection for TCP
Sep 25 13:26:13 About to create 3 backend threads for UDP
Sep 25 13:26:13 Done launching threads, ready to distribute questions
```

Test the API internally
```bash
kubectl -n powerdns port-forward svc/powerdns-api 8081:8081
```

In another terminal run
```bash
curl -sS -H "X-API-Key: SAMPLE-PDNS-API-SECRET" \
  http://127.0.0.1:8081/api/v1/servers/localhost | jq
```

Output should be similar to
```json
{
  "autoprimaries_url": "/api/v1/servers/localhost/autoprimaries{/autoprimary}",
  "config_url": "/api/v1/servers/localhost/config{/config_setting}",
  "daemon_type": "authoritative",
  "id": "localhost",
  "type": "Server",
  "url": "/api/v1/servers/localhost",
  "version": "5.1.4",
  "zones_url": "/api/v1/servers/localhost/zones{/zone}"
}
```

PowerDNS authenticates API requests using the `X-API-Key` header, and its API base path is `/api/v1`

Create the test `example.com` DNS zone: PowerDNS must have the zone before ExternalDNS can manage records within it
```bash
curl -sS -X POST \
  -H "X-API-Key: SAMPLE-PDNS-API-SECRET" \
  -H "Content-Type: application/json" \
  http://127.0.0.1:8081/api/v1/servers/localhost/zones \
  --data '{
    "name": "example.com.",
    "kind": "Native",
    "nameservers": [
      "ns1.example.com."
    ]
  }'
```

Output should be similar to
```json
{
  "account": "",
  "api_rectify": false,
  "catalog": "",
  "dnssec": false,
  "edited_serial": 2026092501,
  "id": "example.com.",
  "kind": "Native",
  "last_check": 0,
  "master_tsig_key_ids": [],
  "masters": [],
  "name": "example.com.",
  "notified_serial": 0,
  "nsec3narrow": false,
  "nsec3param": "",
  "rrsets": [
    {
      "comments": [],
      "name": "example.com.",
      "records": [
        {
          "content": "a.misconfigured.dns.server.invalid. hostmaster.example.com. 2026092501 10800 3600 604800 3600",
          "disabled": false
        }
      ],
      "ttl": 3600,
      "type": "SOA"
    },
    {
      "comments": [],
      "name": "example.com.",
      "records": [
        {
          "content": "ns1.example.com.",
          "disabled": false
        }
      ],
      "ttl": 3600,
      "type": "NS"
    }
  ],
  "serial": 2026092501,
  "slave_tsig_key_ids": [],
  "soa_edit": "",
  "soa_edit_api": "DEFAULT",
  "url": "/api/v1/servers/localhost/zones/example.com."
}
```

Check the `example.com` zone
```bash
curl -sS \
  -H "X-API-Key: SAMPLE-PDNS-API-SECRET" \
  http://127.0.0.1:8081/api/v1/servers/localhost/zones/example.com. | jq
```

Stop the `kubectl port-forward` command running in the other terminal

Test DNS resolution: get PowerDNS resolver port and IP address
```bash
export DNS_IP=`kubectl get nodes -o json |   jq -r 'first(.items[].status.addresses[] | select(.type == "InternalIP") | .address)'`
export DNS_PORT=`kubectl get svc powerdns-dns -n powerdns -o jsonpath='{.spec.ports[0].nodePort}'`
echo -e "DNS IP  : $DNS_IP\nDNS Port: $DNS_PORT"
```

Send a DNS `SOA` query
```bash
dig @$DNS_IP -p $DNS_PORT -t soa example.com
```

Output should be similar to
```bash
; <<>> DiG 9.18.39-0ubuntu0.24.04.7-Ubuntu <<>> @192.168.2.49 -p 31764 -t soa example.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 29943
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;example.com.                   IN      SOA

;; ANSWER SECTION:
example.com.            3600    IN      SOA     a.misconfigured.dns.server.invalid. hostmaster.example.com. 2026092501 10800 3600 604800 3600

;; Query time: 1 msec
;; SERVER: 192.168.2.49#31764(192.168.2.49) (UDP)
;; WHEN: Fri Sep 25 15:00:18 IST 2026
;; MSG SIZE  rcvd: 121
```

The zone `SOA` record is correctly resolved

## ExternalDNS deployment

Create the Kubernetes namespace and API-key Secret to access PowerDNS API
```bash
kubectl create namespace external-dns

kubectl -n external-dns create secret generic powerdns-api \
  --from-literal=api-key='SAMPLE-PDNS-API-SECRET'
```

Add helm repository
```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update
```

Deploy the ExternalDNS Helm chart
```bash
helm upgrade --install external-dns \
  external-dns/external-dns \
  --namespace external-dns \
  --create-namespace \
  --version 1.22.0 \
  -f artifacts/external-dns-values.yaml
```

Check the running pod
```bash
kubectl get pods -n external-dns
```

Output should be similar to
```bash
NAME                            READY   STATUS    RESTARTS   AGE
external-dns-64f7468cb4-g559l   1/1     Running   0          24s
```

Check the pod logs
```bash
EDNS_POD_NAME=`kubectl get pods -n external-dns -o jsonpath='{.items[0].metadata.name}'`
kubectl logs $EDNS_POD_NAME -n external-dns
```

Output should be similar to
```bash
time="2026-09-25T15:07:51Z" level=info msg="config: {APIServerURL: KubeConfig: RequestTimeout:30s KubeAPIRequestTimeout:30s KubeAPIQPS:5 KubeAPIBurst:10 DefaultTargets:[] GlooNamespaces:[gloo-system] SkipperRouteGroupVersion:zalando.org/v1 Sources:[service ingress gateway-httproute] Namespace: AnnotationFilter: AnnotationPrefix:external-dns.kubernetes.io/ LabelFilter: IngressClassNames:[] FQDNTemplate:[] TargetTemplate:[] FQDNTargetTemplate:[] CombineFQDNAndAnnotation:false IgnoreHostnameAnnotation:false IgnoreNonHostNetworkPods:false IgnoreIngressTLSSpec:false IgnoreIngressRulesSpec:false ListenEndpointEvents:false ExposeInternalIPV6:false GatewayName: GatewayNamespace: GatewayLabelFilter: GatewayListenerSets:false Compatibility: PodSourceDomain: PublishInternal:false PublishHostIP:false AlwaysPublishNotReadyAddresses:false ConnectorSourceServer:localhost:8080 Provider:pdns ProviderCacheTime:0s CreatePTR:false GoogleProject: GoogleBatchChangeSize:1000 GoogleBatchChangeInterval:1s GoogleZoneVisibility: DomainFilter:[example.com] DomainExclude:[] RegexDomainFilter: RegexDomainExclude: ZoneNameFilter:[] ZoneIDFilter:[] TargetNetFilter:[] ExcludeTargetNets:[] AlibabaCloudConfigFile:/etc/kubernetes/alibaba-cloud.json AlibabaCloudZoneType: AWSZoneType: AWSZoneTagFilter:[] AWSAssumeRole: AWSProfiles:[] AWSAssumeRoleExternalID: AWSBatchChangeSize:1000 AWSBatchChangeSizeBytes:32000 AWSBatchChangeSizeValues:1000 AWSBatchChangeInterval:1s AWSEvaluateTargetHealth:true AWSAPIRetries:3 AWSPreferCNAME:false AWSZoneCacheDuration:0s AWSSDServiceCleanup:false AWSSDCreateTag:map[] AWSZoneMatchParent:false AWSDynamoDBRegion: AWSDynamoDBTable:external-dns AzureConfigFile:/etc/kubernetes/azure.json AzureResourceGroup: AzureSubscriptionID: AzureUserAssignedIdentityClientID: AzureActiveDirectoryAuthorityHost: AzureZonesCacheDuration:0s AzureMaxRetriesCount:3 BatchChangeSize:200 BatchChangeInterval:1s CloudflareProxied:false CloudflareCustomHostnames:false CloudflareDNSRecordsPerPage:100 CloudflareDNSRecordsComment: CloudflareCustomHostnamesMinTLSVersion:1.0 CloudflareCustomHostnamesCertificateAuthority:none CloudflareRegionalServices:false CloudflareRegionKey: CoreDNSPrefix:/skydns/ CoreDNSStrictlyOwned:false OCIConfigFile:/etc/kubernetes/oci.yaml OCICompartmentOCID: OCIAuthInstancePrincipal:false OCIZoneScope:GLOBAL OCIZoneCacheDuration:0s InMemoryZones:[] OVHEndpoint:ovh-eu OVHApiRateLimit:20 OVHEnableCNAMERelative:false PDNSServer:http://powerdns-api.powerdns.svc.cluster.local:8081 PDNSServerID:localhost PDNSAPIKey:****** PDNSSkipTLSVerify:false TLSCA: TLSClientCert: TLSClientCertKey: Policy:upsert-only Registry:txt TXTOwnerID:my-cluster TXTOwnerOld: TXTPrefix: TXTSuffix: TXTEncryptEnabled:false TXTEncryptAESKey: Interval:30s MinEventSyncInterval:5s MinTTL:0s Once:false DryRun:false UpdateEvents:false LogFormat:text MetricsAddress::7979 LogLevel:info TXTCacheInterval:0s TXTWildcardReplacement: ExoscaleEndpoint: ExoscaleAPIKey: ExoscaleAPISecret: ExoscaleAPIEnvironment:api ExoscaleAPIZone:ch-gva-2 ExoscaleZoneCacheDuration:0s CRDSourceAPIVersion:externaldns.k8s.io/v1alpha1 CRDSourceKind:DNSEndpoint ServiceTypeFilter:[] ResolveServiceLoadBalancerHostname:false RFC2136Host:[] RFC2136Port:0 RFC2136Zone:[] RFC2136Insecure:false RFC2136GSSTSIG:false RFC2136KerberosRealm: RFC2136KerberosUsername: RFC2136KerberosPassword: RFC2136TSIGKeyName: RFC2136TSIGSecret: RFC2136TSIGSecretAlg: RFC2136AXFR:false RFC2136TAXFR:false RFC2136MinTTL:0s RFC2136LoadBalancingStrategy:disabled RFC2136BatchChangeSize:50 RFC2136UseTLS:false RFC2136SkipTLSVerify:false NS1Endpoint: NS1IgnoreSSL:false NS1MinTTLSeconds:0 ManagedDNSRecordTypes:[A AAAA CNAME] ExcludeDNSRecordTypes:[] GoDaddyAPIKey: GoDaddySecretKey: GoDaddyTTL:0 GoDaddyOTE:false OCPRouterName: PiholeServer: PiholePassword: PiholeTLSInsecureSkipVerify:false WebhookProviderURL:http://localhost:8888 WebhookProviderReadTimeout:5s WebhookProviderWriteTimeout:10s WebhookServer:false TraefikEnableLegacy:false TraefikDisableNew:false NAT64Networks:[] ExcludeUnschedulable:true EmitEvents:[] ForceDefaultTargets:false UnstructuredResources:[] PreferAlias:false}"
time="2026-09-25T15:07:51Z" level=info msg="GitCommitShort=unknown, GoVersion=go1.26.6, Platform=linux/amd64, UserAgent=ExternalDNS/v20260820-v0.22.0"
time="2026-09-25T15:07:51Z" level=info msg="Created Kubernetes client https://10.96.0.1:443"
time="2026-09-25T15:07:51Z" level=info msg="Created GatewayAPI client https://10.96.0.1:443"
time="2026-09-25T15:07:51Z" level=info msg="All records are already up to date"
```

## Deploy a sample application

Apply the manifest
```bash
kubectl apply -f 2.echoapp.yaml
```

Check pod status
```bash
kubectl get pods
```

Pod should be in the `Running` status
```bash
NAME                    READY   STATUS    RESTARTS   AGE
echo-6697d99c4d-xrnh4   1/1     Running   0          7s
```

Deploy the Gateway
```bash
kubectl apply -f 3.gateway.yaml
```

Check pod status
```bash
kubectl get pods
```

The Gateway pod should be in rhe `Running` status
```bash
NAME                             READY   STATUS    RESTARTS   AGE
echo-6697d99c4d-xrnh4            1/1     Running   0          2m27s
gateway-nginx-6c67bcd864-7tmvz   4/4     Running   0          30s
```

Check the service status: the `LoadBalancer` service has allocated an external-facing IP address for the Gateway
```bash
kubectl get svc
```

Output should be similar to
```bash
NAME            TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
echo            ClusterIP      10.106.42.41     <none>          80/TCP         70m
gateway-nginx   LoadBalancer   10.111.180.165   192.168.2.200   80:31375/TCP   86s
kubernetes      ClusterIP      10.96.0.1        <none>          443/TCP        2y8d
```

Create the `HTTPRoute` object
```bash
kubectl apply -f 4.httproute.yaml
```

Within 15 seconds (as specified in the [external DNS values file](artifacts/external-dns-values.yaml) as `interval: 15s` the DNS record is created in PowerDNS by external-dns
```bash
kubectl logs $EDNS_POD_NAME -n external-dns
```

Output should be similar to
```bash
time="2026-09-25T15:47:23Z" level=info msg="CREATE: echo.example.com 0 IN A  192.168.2.200 []"
time="2026-09-25T15:47:23Z" level=info msg="CREATE: a-echo.example.com 0 IN TXT  \"heritage=external-dns,external-dns/owner=my-cluster,external-dns/resource=httproute/default/echo\" []"
time="2026-09-25T15:47:23Z" level=info msg="Changes pushed out to PowerDNS in 94.7816ms\n"
```

external-dns has configured `LoadBalancer` service IP address on PowerDNS

Get PowerDNS resolver port and IP address
```bash
export DNS_IP=`kubectl get nodes -o json |   jq -r 'first(.items[].status.addresses[] | select(.type == "InternalIP") | .address)'`
export DNS_PORT=`kubectl get svc powerdns-dns -n powerdns -o jsonpath='{.spec.ports[0].nodePort}'`
echo -e "DNS IP  : $DNS_IP\nDNS Port: $DNS_PORT"
```

Send a DNS `A` query
```bash
dig @$DNS_IP -p $DNS_PORT -t a echo.example.com
```

Output should be similar to
```bash
; <<>> DiG 9.18.39-0ubuntu0.24.04.7-Ubuntu <<>> @192.168.2.49 -p 30311 -t a echo.example.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 48408
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;echo.example.com.              IN      A

;; ANSWER SECTION:
echo.example.com.       300     IN      A       192.168.2.200

;; Query time: 3 msec
;; SERVER: 192.168.2.49#30311(192.168.2.49) (UDP)
;; WHEN: Fri Sep 25 16:48:08 IST 2026
;; MSG SIZE  rcvd: 61
```

The DNS record for `echo.example.com` is active

Test application access: since PowerDNS is not in the local DNS resolver chain, send a crafted request using `curl`
```bash
APP_IP_ADDRESS=`dig @$DNS_IP -p $DNS_PORT -t a echo.example.com +short`
curl -H "Host: echo.example.com" http://$APP_IP_ADDRESS
```

Output should be similar to
```bash
Server address: 10.0.86.24:8080
Server name: echo-6697d99c4d-xrnh4
Date: 25/Sep/2026:15:51:03 +0000
URI: /
Request ID: 9a137606b9b7d7f0f4aa3f92bb67ce01
```

Remove the `HTTPRoute`
```bash
kubectl delete -f 4.httproute.yaml
```

Within 15 seconds (as specified in the [external DNS values file](artifacts/external-dns-values.yaml) as `interval: 15s` the DNS record is deleted from PowerDNS by external-dns
```bash
kubectl logs $EDNS_POD_NAME -n external-dns
```

Output should be similar to
```bash
time="2026-09-25T15:51:30Z" level=info msg="DELETE: echo.example.com 300 IN A  192.168.2.200 []"
time="2026-09-25T15:51:30Z" level=info msg="DELETE: a-echo.example.com 0 IN TXT  \"heritage=external-dns,external-dns/owner=my-cluster,external-dns/resource=httproute/default/echo\" []"
time="2026-09-25T15:51:30Z" level=info msg="Changes pushed out to PowerDNS in 59.862698ms\n"
```

Send a DNS `A` query
```bash
dig @$DNS_IP -p $DNS_PORT -t a echo.example.com
```

Output should be similar to
```bash
; <<>> DiG 9.18.39-0ubuntu0.24.04.7-Ubuntu <<>> @192.168.2.49 -p 30311 -t a echo.example.com
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 368
;; flags: qr aa rd; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
;; QUESTION SECTION:
;echo.example.com.              IN      A

;; AUTHORITY SECTION:
example.com.            3600    IN      SOA     a.misconfigured.dns.server.invalid. hostmaster.example.com. 2026092509 10800 3600 604800 3600

;; Query time: 3 msec
;; SERVER: 192.168.2.49#30311(192.168.2.49) (UDP)
;; WHEN: Fri Sep 25 16:53:10 IST 2026
;; MSG SIZE  rcvd: 126
```

PowerDNS replied with `NXDOMAIN` as the record was deleted


## Delete the lab

```bash
kubectl delete -f .

helm uninstall ngf -n nginx-gateway
helm uninstall external-dns -n external-dns
helm uninstall metallb -n metallb-system

kubectl delete ns nginx-gateway
kubectl delete ns external-dns
kubectl delete ns metallb-system
kubectl delete ns powerdns

kubectl delete -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.7.2/deploy/crds.yaml
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" | kubectl delete -f -
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/inference-extension/?ref=v2.7.2" | kubectl delete -f -
```
