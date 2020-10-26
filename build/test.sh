#! /bin/bash
# Set KUBECONFIG environment variable.
export KUBECONFIG="$(kind get kubeconfig)"
kind get kubeconfig > kindconfig
kind get kubeconfig > $HOME/.kube/config
sleep 30
kubectl get po -A --kubeconfig kindconfig
kubectl get ns -A

