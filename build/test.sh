#! /bin/bash
echo $KUBECONFIG
kind get kubeconfig > kindconfig
sleep 30
kubectl get po -A --kubeconfig kindconfig
kubectl get ns -A --kubeconfig $KUBECONFIG

