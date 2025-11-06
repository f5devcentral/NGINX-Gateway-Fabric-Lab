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
NAME                           READY   STATUS              RESTARTS   AGE
pod/php-fpm-69c6d5c564-g6xb6   0/1     ContainerCreating   0          6s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/kubernetes   ClusterIP   10.100.0.1      <none>        443/TCP    23h
service/php-fpm      ClusterIP   10.100.90.251   <none>        9000/TCP   6s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/php-fpm   0/1     1            0           6s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/php-fpm-69c6d5c564   1         1         0       6s
```

Create the gateway object. This deploys the NGINX Gateway Fabric dataplane pod in the current namespace
```code
kubectl apply -f 1.gateway.yaml
```

Check the NGINX Gateway Fabric dataplane pod status
```
kubectl get pods
```

`gateway-nginx-67fb4cdf89-g6gk9` is the NGINX Gateway Fabric dataplane
```
NAME                             READY   STATUS    RESTARTS   AGE
gateway-nginx-67fb4cdf89-g6gk9   1/1     Running   0          17s
php-fpm-69c6d5c564-g6xb6         1/1     Running   0          36s
```

Check the gateway
```code
kubectl get gateway
```

Output should be similar to
```code
NAME      CLASS   ADDRESS                                                                        PROGRAMMED   AGE
gateway   nginx   k8s-default-gatewayn-d3d939fb2e-a7f8853dff4f389f.elb.us-west-2.amazonaws.com   True         83s
```

Check the NGINX Gateway Fabric Service
```code
kubectl get service
```

`cafe-nginx` is the NGINX Gateway Fabric dataplane service
```code
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP                                                                    PORT(S)        AGE
gateway-nginx   LoadBalancer   10.100.64.186   k8s-default-gatewayn-d3d939fb2e-a7f8853dff4f389f.elb.us-west-2.amazonaws.com   80:31328/TCP   93s
kubernetes      ClusterIP      10.100.0.1      <none>                                                                         443/TCP        23h
php-fpm         ClusterIP      10.100.90.251   <none>                                                                         9000/TCP       112s
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
  Creation Timestamp:  2025-11-06T11:19:05Z
  Generation:          1
  Resource Version:    466380
  UID:                 0d60e7ea-ec62-49ce-a4ef-720469841251
Spec:
  Snippets:
    Context:  http.server.location
    Value:    location / { resolver kube-dns.kube-system.svc.cluster.local;fastcgi_param SCRIPT_FILENAME /var/www/html/public/index.php;fastcgi_param DOCUMENT_ROOT /var/www/html/public;fastcgi_param QUERY_STRING $args;fastcgi_param REQUEST_METHOD $request_method;fastcgi_param CONTENT_TYPE $content_type;fastcgi_param CONTENT_LENGTH $content_length;fastcgi_param PATH_INFO $uri;fastcgi_param PATH_TRANSLATED /var/www/html/public$uri;fastcgi_index index.php;fastcgi_buffer_size 32k;fastcgi_buffers 16 16k;fastcgi_pass php-fpm.default.svc.cluster.local:9000;}
Status:
  Controllers:
    Conditions:
      Last Transition Time:  2025-11-06T11:19:05Z
      Message:               SnippetsFilter is accepted
      Observed Generation:   1
      Reason:                Accepted
      Status:                True
      Type:                  Accepted
    Controller Name:         gateway.nginx.org/nginx-gateway-controller
Events:                      <none>
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

Get NGINX Gateway Fabric dataplane loadbalancer DNS
```code
export NGF_DNS=`kubectl get svc gateway-nginx -o json|jq '.status.loadBalancer.ingress[0].hostname' -r`
```

AWS Elastic Load Balancer takes some minutes to register targets. Wait for it using
```code
aws elbv2 wait load-balancer-available --load-balancer-arns $(aws elbv2 describe-load-balancers --query 'LoadBalancers[?DNSName==`'"$NGF_DNS"'`].LoadBalancerArn' --output text)
```

Check NGINX Gateway Fabric dataplane loadbalancer DNS
```code
echo -e "NGF address: $NGF_DNS"
```

Access the PHP application
```code
curl -i -H "Host: php.example.com" http://$NGF_DNS/phpinfo.php
```

Output should be similar to
```code
HTTP/1.1 200 OK
Server: nginx
Date: Thu, 06 Nov 2025 11:22:26 GMT
Content-Type: text/html; charset=UTF-8
Transfer-Encoding: chunked
Connection: keep-alive
X-Powered-By: PHP/8.2.29

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head>
<style type="text/css">

[... OMMITED TO MAKE IT SHORT ...]

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
