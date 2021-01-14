#!/bin/bash

cur_dir=$(pwd)
echo "Current directory is $cur_dir"

cd scripts/gitServer
echo "Current directory is $pwd"

KUBECTL_CMD="kubectl --kubeconfig /opt/e2e/default-kubeconfigs/hub"

# Uninstall Gogs Git server
$KUBECTL_CMD delete -f gogs.yaml