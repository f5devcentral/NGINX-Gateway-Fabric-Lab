# Publishing a FastCGI application using SnippetsFilter

This use case shows how to publish a sample PHP application using the FastCGI interface through SnippetsFilter

`cd` into the lab directory
```code
cd ~/NGINX-Gateway-Fabric-Lab/labs/7.fastcgi
```

Deploy the sample PHP application
```code
kubectl apply -f 0.phpapp.yaml
```

Verify that the pod is in the `Running` state

```code
kubectl get all
```

Output should be similar to

```
NAME                           READY   STATUS    RESTARTS   AGE
pod/php-fpm-7f8d9d598c-wqsj9   1/1     Running   0          4s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP    385d
service/php-fpm      ClusterIP   10.111.251.242   <none>        9000/TCP   4s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/php-fpm   1/1     1            1           4s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/php-fpm-7f8d9d598c   1         1         1       4s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Set AWS annotations to make the Network Load Balancer external and Internet-facing
```
kubectl annotate svc gateway-nginx service.beta.kubernetes.io/aws-load-balancer-type=external --overwrite
kubectl annotate svc gateway-nginx service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing --overwrite
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-56678b747f-f6h2w` is the NGINX Gateway Fabric dataplane
```
NAME                             READY   STATUS    RESTARTS   AGE
gateway-nginx-56678b747f-f6h2w   1/1     Running   0          82s
php-fpm-7f8d9d598c-wqsj9         1/1     Running   0          2m27s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS         PROGRAMMED   AGE
gateway   nginx   192.168.2.211   True         5s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`cafe-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
gateway-nginx          LoadBalancer   10.103.244.105   192.168.2.211   80:31858/TCP   13s
kubernetes             ClusterIP      10.96.0.1        <none>          443/TCP        402d
php-fpm                ClusterIP      10.98.66.18      <none>          9000/TCP       17s
```

Create the SnippetsFilter to set up the FastCGI configuration snippets
```code
kubectl apply -f 2.snippetsfilter-fastcgi.yaml
```

Check the SnippetsFilter
```code
kubectl describe snippetsfilter fastcgi
```

Output should be similar to
```code
Name:         fastcgi
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  gateway.nginx.org/v1alpha1
Kind:         SnippetsFilter
Metadata:
  Creation Timestamp:  2025-10-07T08:10:17Z
  Generation:          1
  Resource Version:    66548537
  UID:                 50958b7f-ebb0-4b8a-b16c-e60794e97c57
Spec:
  Snippets:
    Context:  http.server.location
    Value:    location / { resolver kube-dns.kube-system.svc.cluster.local;fastcgi_param SCRIPT_FILENAME /var/www/html/public/index.php;fastcgi_param DOCUMENT_ROOT /var/www/html/public;fastcgi_param QUERY_STRING $args;fastcgi_param REQUEST_METHOD $request_method;fastcgi_param CONTENT_TYPE $content_type;fastcgi_param CONTENT_LENGTH $content_length;fastcgi_param PATH_INFO $uri;fastcgi_param PATH_TRANSLATED /var/www/html/public$uri;fastcgi_index index.php;fastcgi_buffer_size 32k;fastcgi_buffers 16 16k;fastcgi_pass php-fpm.default.svc.cluster.local:9000;}
Events:       <none>
```

Create the HTTP route that references the SnippetsFilter
```code
kubectl apply -f 3.httproute.yaml
```

Check the HTTP route
```code
kubectl get httproute
```

Output should be similar to
```code
NAME      HOSTNAMES             AGE
php-fpm   ["php.example.com"]   13s
```

Get NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
export NGF_IP=`kubectl get svc gateway-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`
export HTTP_PORT=`kubectl get svc gateway-nginx -o jsonpath='{.spec.ports[0].targetPort}'`
```

Check NGINX Gateway Fabric dataplane instance IP and HTTP port
```code
echo -e "NGF address: $NGF_IP\nHTTP port  : $HTTP_PORT"
```

Access the PHP application
```code
curl -si --resolve php.example.com:$HTTP_PORT:$NGF_IP http://php.example.com:$HTTP_PORT/phpinfo.php
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Tue, 07 Oct 2025 08:28:49 GMT
Content-Type: text/html; charset=UTF-8
Transfer-Encoding: chunked
Connection: keep-alive
X-Powered-By: PHP/8.2.29

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head>
<style type="text/css">
body {background-color: #fff; color: #222; font-family: sans-serif;}
pre {margin: 0; font-family: monospace;}
[...]
<tr class="v"><td>
<p>
This program is free software; you can redistribute it and/or modify it under the terms of the PHP License as published by the PHP Group and included in the distribution in the file:  LICENSE
</p>
<p>This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
</p>
<p>If you did not receive a copy of the PHP license, or have any questions about PHP licensing, please contact license@php.net.
</p>
</td></tr>
</table>
</div></body></html>
```

Delete the lab

```code
kubectl delete -f .
```
