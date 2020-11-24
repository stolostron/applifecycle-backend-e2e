#! /bin/bash
set -e
echo "e2e TEST"
# need to find a way to use the Makefile to set these
IMG=$(cat COMPONENT_NAME 2> /dev/null)

echo ${TRAVIS_BUILD}

echo ${TRAVIS_EVENT_TYPE}
echo ${COMPONENT_TAG_EXTENSION}
echo ${TRAVIS_PULL_REQUEST}-${TRAVIS_COMMIT}
export GO111MODULE=on

if [ "$TRAVIS_BUILD" != 1 ]; then
    echo "Build is on Travis" 

    echo -e "Get kubectl binary \n"
    # Download and install kubectl
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

    echo -e "\nDownload and install KinD\n"
    go get sigs.k8s.io/kind

    kind create cluster
    if [ $? != 0 ]; then
            exit $?;
    fi

    sleep 15
fi

kind get kubeconfig > default-kubeconfigs/hub

setup_channel_operator(){
    echo "Clone the channel repo"
    rm -rf multicloud-operators-channel || true
    git clone https://github.com/open-cluster-management/multicloud-operators-channel.git

    kubectl apply -f multicloud-operators-channel/deploy/standalone
    kubectl apply -f multicloud-operators-channel/deploy/crds
}

setup_subscription_operator(){
    echo "Clone the subscription repo"
    rm -rf multicloud-operators-subscription || true
    git clone https://github.com/open-cluster-management/multicloud-operators-subscription.git

    kubectl apply -f multicloud-operators-subscription/deploy/standalone
}

setup_placementrule_operator(){
    echo "Clone the placementrule repo"
    rm -rf multicloud-operators-placementrule || true
    git clone https://github.com/open-cluster-management/multicloud-operators-placementrule.git

    kubectl apply -f https://raw.githubusercontent.com/open-cluster-management/multicloud-operators-placementrule/master/deploy/crds/apps.open-cluster-management.io_placementrules_crd.yaml
}

setup_helmrelease_operator(){
    echo "Clone the subscription repo"
    rm -rf multicloud-operators-subscription-release || true
    git clone https://github.com/open-cluster-management/multicloud-operators-subscription-release.git

    kubectl apply -f multicloud-operators-subscription-release/deploy
    kubectl apply -f multicloud-operators-subscription-release/deploy/crds
}

setup_channel_operator
setup_subscription_operator
setup_helmrelease_operator
setup_placementrule_operator

echo "Process the test cases"
# go test -v ./client
