#!/bin/bash

echo "==== Testing nested subscriptions with subscription admin user ===="

# Find the directory we're in (used to reference other scripts)
root_dir=$(pwd)
cd scripts/subscriptionAdmin
cur_dir=$(pwd)
echo "Current directory is $cur_dir"

KUBECONFIG=/opt/e2e/default-kubeconfigs/hub

KUBECTL_CMD="oc --kubeconfig $KUBECONFIG --insecure-skip-tls-verify=true"

# Create test namespaces
$KUBECTL_CMD create ns rootsub
$KUBECTL_CMD create ns secondsub
$KUBECTL_CMD create ns multins

USER=`$KUBECTL_CMD whoami`
echo "The current user is $USER"

# Add thte current user in the YAML
sed -i -e "s/__USER__/$USER/" addSubAdmin.yaml
if [ $? -ne 0 ]; then
    echo "failed to substitue __USER__ in addSubAdmin.yaml"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Add the current user to the subscription-admin clustrerolebinding
$KUBECTL_CMD apply -f addSubAdmin.yaml
if [ $? -ne 0 ]; then
    echo "failed to add kubeadmin user to open-cluster-management:subscription-admin clusterrolebinding"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Create a root subscription which will apply a nested subscription from Git
$KUBECTL_CMD apply -f rootAppSub.yaml
if [ $? -ne 0 ]; then
    echo "failed to apply the root subscription YAML"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Wait for the nested second subscription's subscribed configmap to show up in its namespace, not the secondsub's namespace
FOUND=1
SECONDS=0
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 5min
    if [ $SECONDS -gt 300 ]; then
        echo "Timeout waiting for configmap perf-configmap in multins namespace"
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    $KUBECTL_CMD -n multins get configmap perf-configmap

    if [ $? -eq 0 ]; then 
        echo "configmap perf-configmap found in multins namespace. SUCCESSFUL"
        break
    fi
    sleep 3
    (( SECONDS = SECONDS + 3 ))
done

# Remove kube:admin from the subscription-admin clustrerolebinding
$KUBECTL_CMD apply -f removeSubAdmin.yaml
if [ $? -ne 0 ]; then
    echo "failed to remove kubeadmin user from open-cluster-management:subscription-admin clusterrolebinding"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Delete test namespaces
$KUBECTL_CMD delete ns rootsub
$KUBECTL_CMD delete ns secondsub
$KUBECTL_CMD delete ns multins

echo "E2E CANARY TEST - DONE"
exit 0