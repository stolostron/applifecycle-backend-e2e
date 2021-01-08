#!/bin/bash

# Find the directory we're in (used to reference other scripts)
my_dir=$(dirname $(readlink -f $0))
# The main directory of canary-scripts
root_dir=$my_dir/../../../..

KUBECTL_CMD="kubectl --kubeconfig /opt/e2e/default-kubeconfigs/hub"

# Uninstall Gogs Git server
$KUBECTL_CMD delete -f gogs.yaml