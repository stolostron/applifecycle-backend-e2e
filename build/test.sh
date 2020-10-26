#! /bin/bash
# Set KUBECONFIG environment variable.
kind get kubeconfig > kindconfig
sleep 30
kubectl get po -A --kubeconfig kindconfig
kubectl get ns -A --Kubeconfig kindconfig

