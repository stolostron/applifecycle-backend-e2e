#! /bin/bash
set -e
echo "e2e TEST"
# need to find a way to use the Makefile to set these
REGISTRY=quay.io/open-cluster-management
IMG=$(cat COMPONENT_NAME 2> /dev/null)
IMAGE_NAME=${REGISTRY}/${IMG}
COMPONENT_VERSION=$(cat COMPONENT_VERSION 2> /dev/null)
BUILD_IMAGE=${IMAGE_NAME}:latest

if [ "$TRAVIS_BUILD" != 1 ]; then
    echo "Build is on Travis" 

    echo -e "Get kubectl binary \n"
    # Download and install kubectl
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

    BUILD_IMAGE=${IMAGE_NAME}:${COMPONENT_VERSION}${COMPONENT_TAG_EXTENSION}

    echo -e "BUILD_IMAGE tag $BUILD_IMAGE\n"

fi

echo -e "\ndelete the running container:"
docker rm -f ${CONTAINER_NAME} || true

echo -e "\nrun a new container ${CONTAINER_NAME} with the update iamge: ${BUILD_IMAGE}\n"
docker run -p 8765:8765 --name ${CONTAINER_NAME} -d --rm ${BUILD_IMAGE}

sleep 10
curl http://localhost:8765/cluster | head -n 10
curl http://localhost:8765/testcase | head -n 10
curl http://localhost:8765/expectation | head -n 10

