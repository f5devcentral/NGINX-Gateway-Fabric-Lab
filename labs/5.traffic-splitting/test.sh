#!/bin/bash

NGF_IP=`kubectl get pod -l app.kubernetes.io/instance=ngf -n nginx-gateway -o json|jq '.items[0].status.hostIP' -r`
HTTP_PORT=`kubectl get svc ngf-nginx-gateway-fabric -n nginx-gateway -o jsonpath='{.spec.ports[0].nodePort}'`
HTTPS_PORT=`kubectl get svc ngf-nginx-gateway-fabric -n nginx-gateway -o jsonpath='{.spec.ports[1].nodePort}'`

coffee_v1_count=0
coffee_v2_count=0

for i in {1..100}
do
  response=$(curl -s --resolve cafe.example.com:$HTTP_PORT:$NGF_IP http://cafe.example.com:$HTTP_PORT/coffee | grep "Server name" | awk '{print $3}')
  echo -en .

  if [[ "$response" == *"-v1-"* ]]; then
    coffee_v1_count=$((coffee_v1_count + 1))
  elif [[ "$response" == *"-v2-"* ]]; then
    coffee_v2_count=$((coffee_v2_count + 1))
  fi
done

echo
echo "Summary of responses:"
echo "Coffee v1: $coffee_v1_count times"
echo "Coffee v2: $coffee_v2_count times"
