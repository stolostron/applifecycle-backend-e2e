#! /bin/bash
set -e
echo "e2e TEST"
# need to find a way to use the Makefile to set these
IMG=$(cat COMPONENT_NAME 2> /dev/null)

echo "print ENVs: "
echo "travis_build: ${TRAVIS_BUILD}"
echo "travis_event_type: ${TRAVIS_EVENT_TYPE}"
echo "component_tag_extension: ${COMPONENT_TAG_EXTENSION}"
echo "pull_request-travis_commit: ${TRAVIS_PULL_REQUEST}-${TRAVIS_COMMIT}"
echo "end of printing ENVs"
echo

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
fi

kind get kubeconfig > default-kubeconfigs/hub

setup_application_operator(){
    echo "Clone the channel repo"
    if [ ! -d "multicloud-operators-application" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-application.git
    fi

    kubectl apply -f multicloud-operators-application/deploy/crds
}

setup_channel_operator(){
    echo "Clone the channel repo"
    if [ ! -d "multicloud-operators-channel" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-channel.git
    fi

    kubectl apply -f multicloud-operators-channel/deploy/standalone
    kubectl apply -f multicloud-operators-channel/deploy/crds
}

setup_subscription_operator(){
    echo "Clone the subscription repo"
    if [ ! -d "multicloud-operators-subscription" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-subscription.git
    fi

    kubectl apply -f multicloud-operators-subscription/deploy/standalone
}

setup_placementrule_operator(){
    echo "Clone the placementrule repo"
    if [ ! -d "multicloud-operators-placementrule" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-placementrule.git
    fi

    kubectl apply -f https://raw.githubusercontent.com/open-cluster-management/multicloud-operators-placementrule/master/deploy/crds/apps.open-cluster-management.io_placementrules_crd.yaml
}

setup_helmrelease_operator(){
    echo "Clone the helmrelease repo"
    if [ ! -d "multicloud-operators-subscription-release" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-subscription-release.git
    fi

    kubectl apply -f multicloud-operators-subscription-release/deploy
    kubectl apply -f multicloud-operators-subscription-release/deploy/crds
}


setup_operators(){
    setup_application_operator
    setup_channel_operator
    setup_subscription_operator
    setup_helmrelease_operator
    setup_placementrule_operator

    if [ "$TRAVIS_BUILD" != 1 ]; then
        sleep 90
    fi

    kubectl get deploy -A
}

setup_operators

echo "Process the test cases"
go test -v ./client
