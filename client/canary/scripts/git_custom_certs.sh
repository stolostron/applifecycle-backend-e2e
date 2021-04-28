#!/bin/bash

echo "==== Subscribing application from Git repo with custom certificate ===="

# Find the directory we're in (used to reference other scripts)
root_dir=$(pwd)
cd tests/e2e-001
cur_dir=$(pwd)
echo "Current directory is $cur_dir"

kubeconfig=/opt/e2e/default-kubeconfigs/hub

KUBECTL_CMD="kubectl --kubeconfig /opt/e2e/default-kubeconfigs/hub"

# Apply subscription
$KUBECTL_CMD apply -f . -n e2e-001

# Wait for the test config map to be created
FOUND=1
SECONDS=0
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 10 minutes
    if [ $SECONDS -gt 1200 ]; then
        echo "Timeout waiting for configmap test-configmap to be created in e2e-001 namespace."
        echo "List of current configmap:"
        $KUBECTL_CMD -n e2e-001 get configmap
        echo
        
        $KUBECTL_CMD get appsub e2e-001-subscription -n e2e-001 -o yaml
        echo

        $KUBECTL_CMD get appsub e2e-001-subscription-local -n e2e-001 -o yaml
        echo

        APPSUB_POD_NAME=`$KUBECTL_CMD get pod -n open-cluster-management -o custom-columns=":metadata.name" | grep hub-subscription`

        $KUBECTL_CMD describe pod $APPSUB_POD_NAME -n open-cluster-management
        echo

        $KUBECTL_CMD logs $APPSUB_POD_NAME -n open-cluster-management
        echo

        APPMGR_POD_NAME=`$KUBECTL_CMD get pod -n open-cluster-management-agent-addon -o custom-columns=":metadata.name" | grep appmgr`

        $KUBECTL_CMD describe pod $APPMGR_POD_NAME -n open-cluster-management-agent-addon
        echo

        $KUBECTL_CMD logs $APPMGR_POD_NAME -n open-cluster-management-agent-addon
        echo

        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    configmap=`$KUBECTL_CMD -n e2e-001 get configmap test-configmap`

    if [[ $(echo $configmap | grep test-configmap) ]]; then 
        echo "test-configmap is created"
        break
    fi

    # Sleep for 10 seconds
    sleep 10
    (( SECONDS = SECONDS + 10 ))
done

# Delete subscription
$KUBECTL_CMD delete -f application.yaml -n e2e-001

echo "E2E CANARY TEST - DONE"