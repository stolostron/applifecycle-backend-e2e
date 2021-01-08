#!/bin/bash

# Find the directory we're in (used to reference other scripts)
my_dir=$(dirname $(readlink -f $0))
# The main directory of canary-scripts
root_dir=$my_dir/../../../..
kubeconfig_dir=$root_dir/kubeconfig

KUBECTL_CMD="kubectl --kubeconfig $kubeconfig_dir/import-kubeconfig"

# Deploy Gogs Git server
$KUBECTL_CMD delete -f gogs.yaml