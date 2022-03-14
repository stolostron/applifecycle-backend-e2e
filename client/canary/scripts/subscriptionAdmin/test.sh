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
$KUBECTL_CMD create ns mergeown

USER=`$KUBECTL_CMD whoami`
echo "The current user is $USER"

# Add the current user to the subscription-admin clustrerolebinding
# IMPORTANT: Use patches to not interfere with the GRC Policy Generator tests.
#
# A strategic merge patch is required when there are no subjects since the Kubernetes API
# rejects a JSON patch when there are no subjects set. Setting it first to an empty array
# also does not work since Kubernetes discards the empty array. The strategic
# merge patch works in this case, however, it does not work for the case when subjects
# is already set to one or more values. The Kubernetes API will just overwrite the
# entire subjects array in this case. This is why both patch types must be used.
SUBJECT="{\"apiGroup\": \"rbac.authorization.k8s.io\", \"kind\": \"User\", \"name\": \"$USER\"}"
if [[ $($KUBECTL_CMD get clusterrolebinding open-cluster-management:subscription-admin -o=jsonpath='{.subjects}') ]]; then
    $KUBECTL_CMD patch clusterrolebinding open-cluster-management:subscription-admin \
        --type=json \
        -p="[{\"op\": \"add\", \"path\": \"/subjects/-\", \"value\": $SUBJECT}]"
else
    $KUBECTL_CMD patch clusterrolebinding open-cluster-management:subscription-admin \
        -p "{\"subjects\": [$SUBJECT]}"
fi

if [ $? -ne 0 ]; then
    echo "failed to add kubeadmin user to open-cluster-management:subscription-admin clusterrolebinding"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Keep track of this for clean up
SUB_ADMIN_INDEX=$(($($KUBECTL_CMD get clusterrolebinding open-cluster-management:subscription-admin -o=jsonpath='{.subjects}' | grep -o '"apiGroup"' | wc -l) - 1))

echo "==== Test nested subscriptions ===="
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

        CLUSTERROLEBINDING=`$KUBECTL_CMD get clusterrolebinding open-cluster-management:subscription-admin -o yaml`
        echo "$CLUSTERROLEBINDING"

        ROOT_APPSUB=`$KUBECTL_CMD get appsub root-level-sub -n rootsub -o yaml`
        echo "$ROOT_APPSUB"

        SECOND_APPSUB=`$KUBECTL_CMD get appsub second-level-sub -n secondsub -o yaml`
        echo "$SECOND_APPSUB"

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

echo "==== Test mergeAndOwn option ===="

# Create a config map
$KUBECTL_CMD apply -f configmap.yaml
if [ $? -ne 0 ]; then
    echo "failed to create the config map"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

sleep 3

# Create a subscription with mergeAndOwn option to take ownership of the existing config map
$KUBECTL_CMD apply -f mergeOwnSub.yaml
if [ $? -ne 0 ]; then
    echo "failed to apply the mergeAndOwn subscription YAML"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

sleep 3

# Verify that the configmap has the hosting subscription annotation
FOUND=1
SECONDS=0
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 5min
    if [ $SECONDS -gt 300 ]; then
        echo "Timeout waiting for configmap mergeown-configmap in mergeown namespace with the hosting-subscription annotation"

        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    configMapAnnotation=`$KUBECTL_CMD get configmap mergeown-configmap -n mergeown -o=jsonpath='{.metadata.annotations.apps\.open-cluster-management\.io/hosting-subscription}'`

    if [ "$configMapAnnotation" == "rootsub/mergeown-sub-local" ]; then
        echo "The hosting-subscription annotation found in the configmap. SUCCESSFUL"
        break
    fi

    echo "The hosting-subscription annotation not found in the configmap yet. Check again in 3 seconds.."

    sleep 3
    (( SECONDS = SECONDS + 3 ))
done

# Delete the subscription and verify that the config map is removed
$KUBECTL_CMD delete -f mergeOwnSub.yaml
if [ $? -ne 0 ]; then
    echo "failed to delete the mergeAndOwn subscription"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Verify that the configmap is deleted
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 5min
    if [ $SECONDS -gt 300 ]; then
        echo "Timeout waiting for configmap mergeown-configmap in mergeown namespace to be deleted"

        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    $KUBECTL_CMD get configmap mergeown-configmap -n mergeown

    if [ $? -ne 0 ]; then 
        echo "mergeown-configmap deleted from mergeown namespace. SUCCESSFUL"
        break
    fi
    sleep 3
    (( SECONDS = SECONDS + 3 ))
done

$KUBECTL_CMD delete -f rootAppSub.yaml

sleep 5

# Remove kube:admin from the subscription-admin clustrerolebinding
$KUBECTL_CMD patch clusterrolebinding open-cluster-management:subscription-admin \
    --type=json \
    -p="[{\"op\": \"remove\", \"path\": \"/subjects/$SUB_ADMIN_INDEX\", \"value\": $SUBJECT}]"
if [ $? -ne 0 ]; then
    echo "failed to remove kubeadmin user from open-cluster-management:subscription-admin clusterrolebinding"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Delete test namespaces
$KUBECTL_CMD delete ns rootsub
$KUBECTL_CMD delete ns secondsub
$KUBECTL_CMD delete ns multins
$KUBECTL_CMD delete ns mergeown

echo "E2E CANARY TEST - DONE"
exit 0