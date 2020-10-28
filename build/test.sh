#! /bin/bash

echo "e2e TEST"
# need to find a way to use the Makefile to set these
REGISTRY=quay.io/open-cluster-management
IMG=$(cat COMPONENT_NAME 2> /dev/null)
IMAGE_NAME=${REGISTRY}/${IMG}
COMPONENT_VERSION=$(cat COMPONENT_VERSION 2> /dev/null)
BUILD_IMAGE=${IMAGE_NAME}:${COMPONENT_VERSION}
DOCKER_TOKEN=${QUAYIO_TOKEN}

if [ "$TRAVIS_BUILD" != 1 ]; then
    echo "Build is on Travis" 

    echo "Download and install KinD"
    GO111MODULE=on go get sigs.k8s.io/kind

    echo "get kubectl binary"
    # Download and install kubectl
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

    BUILD_IMAGE=${IMAGE_NAME}:${COMPONENT_VERSION}${COMPONENT_TAG_EXTENSION}

    echo "BUILD_IMAGE tag $BUILD_IMAGE"


    kind create cluster
    if [ $? != 0 ]; then
            exit $?;
    fi

    DOCKER_TOKEN=${GITHUB_TOKEN}
    #kind get kubeconfig > kindconfig
    sleep 15
fi

echo "switch kubeconfig to kind cluster"
kubectl cluster-info --context kind-kind

kubectl delete -f deploy

echo "modify deployment to point to the PR image"
sed -i -e "s|image: .*:latest$|image: $BUILD_IMAGE|" deploy/test-api-server.yaml

echo "path for container in YAML $(grep 'image: .*' deploy/test-api-server.yaml)"

echo "load build image ($BUILD_IMAGE)to kind cluster"
kind load docker-image $BUILD_IMAGE
if [ $? != 0 ]; then
    exit $?;
fi


echo "applying channel operator to kind cluster"
kubectl apply -f deploy
if [ $? != 0 ]; then
    exit $?;
fi

sleep 3
curl http://localhost:8765/cluster | head -n 10
curl http://localhost:8765/testcase | head -n 10
curl http://localhost:8765/expectation | head -n 10
