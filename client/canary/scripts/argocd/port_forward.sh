#! /bin/bash

echo "e2e TEST - Start port forward for argocd client"

KUBECONFIG_HUB="/opt/e2e/default-kubeconfigs/hub"
KUBECTL_HUB="kubectl --kubeconfig $KUBECONFIG_HUB"

for pid in $(ps aux | grep 'port-forward svc\/argocd-server' | awk '{print $2}'); do kill -9 $pid; done

$KUBECTL_HUB -n argocd port-forward svc/argocd-server -n argocd --pod-running-timeout=5m0s 8080:443

# avoid port forward time out
while true ; do nc -vz 127.0.0.1 8080 ; sleep 10 ; done
