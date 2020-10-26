#! /bin/bash
# Set KUBECONFIG environment variable.
export KUBECONFIG="$(kind get kubeconfig)"
kind get kubeconfig > kindconfig
sleep 30
kubectl get po -A --kubeconfig kindconfig
echo "$KUBECONFIG"
kubectl get ns -A --kubeconfig="$KUBECONFIG"

