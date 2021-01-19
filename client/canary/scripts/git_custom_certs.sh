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
MINUTE=0
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 2min
    if [ $MINUTE -gt 120 ]; then
        echo "Timeout waiting for configmap test-configmap to be created in e2e-001 namespace."
        echo "List of current configmap:"
        $KUBECTL_CMD -n e2e-001 get configmap
        echo
        exit 1
    fi

    configmap=`$KUBECTL_CMD -n e2e-001 get configmap test-configmap`

    if [[ $(echo $configmap | grep test-configmap) ]]; then 
        echo "test-configmap is created"
        break
    fi
    sleep 3
    (( MINUTE = MINUTE + 3 ))
done

# Delete subscription
$KUBECTL_CMD delete -f application.yaml -n e2e-001