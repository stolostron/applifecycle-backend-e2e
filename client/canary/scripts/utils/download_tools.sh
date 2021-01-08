#!/bin/bash

# Install OpenShift CLI.
echo "Installing oc and kubectl clis..."
curl -kLo oc.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.6.4/openshift-client-linux-4.6.4.tar.gz
mkdir oc-unpacked
tar -xzf oc.tar.gz -C oc-unpacked
chmod 755 ./oc-unpacked/oc
chmod 755 ./oc-unpacked/kubectl
mv ./oc-unpacked/oc /usr/local/bin/oc
mv ./oc-unpacked/kubectl /usr/local/bin/kubectl
rm -rf ./oc-unpacked ./oc.tar.gz
