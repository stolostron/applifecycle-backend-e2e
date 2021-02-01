#! /bin/bash
set -e
echo "e2e TEST"
# need to find a way to use the Makefile to set these
IMG=$(cat COMPONENT_NAME 2> /dev/null)

echo "print ENVs: "
echo "travis_build: ${TRAVIS_BUILD}"
echo "travis_event_type: ${TRAVIS_EVENT_TYPE}"
echo "component version: ${COMPONENT_VERSION}"
echo "component_tag_extension: ${COMPONENT_TAG_EXTENSION}"
echo "pull_request-travis_commit: ${TRAVIS_PULL_REQUEST}-${TRAVIS_COMMIT}"
echo "end of printing ENVs"
echo

export GO111MODULE=on

if [ "$TRAVIS_BUILD" != 1 ]; then
    echo "Build is on Travis"

    # Download and install kubectl
    echo -e "\nGet kubectl binary\n"
    PLATFORM=`uname -s | awk '{print tolower($0)}'`
    if [ "`which kubectl`" ]; then
        echo "kubectl PATH is `which kubectl`"
    else
        mkdir -p $(pwd)/bin
        curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/$PLATFORM/amd64/kubectl && mv kubectl $(pwd)/bin/ && chmod +x $(pwd)/bin/kubectl
        export PATH=$PATH:$(pwd)/bin
        echo "kubectl PATH is `which kubectl`"
    fi

    echo -e "\nDownload and install KinD\n"
    go get sigs.k8s.io/kind

fi

kind delete cluster
if [ $? != 0 ]; then
        exit $?;
fi

kind create cluster
if [ $? != 0 ]; then
        exit $?;
fi

sleep 15

if [ ! -d "default-kubeconfigs" ]; then
	mkdir default-kubeconfigs
fi


kind get kubeconfig > default-kubeconfigs/hub

setup_application_operator(){
    echo "Clone the application repo"
    echo
    if [ ! -d "multicloud-operators-application" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-application.git
    fi

    kubectl apply -f multicloud-operators-application/deploy/crds
}

setup_channel_operator(){
    echo "Clone the channel repo"
    echo
    if [ ! -d "multicloud-operators-channel" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-channel.git
    fi

	sed -i -e "s|image: .*$|image: quay.io/open-cluster-management/multicluster-operators-channel:community-${COMPONENT_VERSION}|" multicloud-operators-channel/deploy/standalone/operator.yaml

    kubectl apply -f multicloud-operators-channel/deploy/crds
    kubectl apply -f multicloud-operators-channel/deploy/standalone

    kubectl rollout status deployment/multicluster-operators-channel
    if [ $? != 0 ]; then
        echo "failed to deploy the channel operator"
        exit $?;
    fi
}

setup_subscription_operator(){
    echo "Clone the subscription repo"
    echo
    if [ ! -d "multicloud-operators-subscription" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-subscription.git
    fi

    kubectl apply -f multicloud-operators-subscription/deploy/common
    sleep 5

	echo "before sed $COMPONENT_VERSION"
    sed -i -e "s|image: .*$|image: quay.io/open-cluster-management/multicluster-operators-subscription:community-$COMPONENT_VERSION|" multicloud-operators-subscription/deploy/standalone/operator.yaml

    kubectl apply -f multicloud-operators-subscription/deploy/standalone

    kubectl rollout status deployment/multicluster-operators-subscription -n multicluster-operators
    if [ $? != 0 ]; then
        echo "failed to deploy the subscription operator"
        exit $?;
    fi
}

setup_placementrule_operator(){
    echo "Clone the placementrule repo"
    echo
    if [ ! -d "multicloud-operators-placementrule" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-placementrule.git
    fi

    kubectl apply -f https://raw.githubusercontent.com/open-cluster-management/multicloud-operators-placementrule/master/deploy/crds/apps.open-cluster-management.io_placementrules_crd.yaml
}

setup_helmrelease_operator(){
    echo "Clone the helmrelease repo"
    echo
    if [ ! -d "multicloud-operators-subscription-release" ]; then
        git clone https://github.com/open-cluster-management/multicloud-operators-subscription-release.git
    fi

    sed -i -e "s|image: .*$|image: quay.io/open-cluster-management/multicluster-operators-subscription-release:community-$COMPONENT_VERSION|" multicloud-operators-subscription-release/deploy/operator.yaml

    kubectl apply -f multicloud-operators-subscription-release/deploy/crds
    kubectl apply -f multicloud-operators-subscription-release/deploy

    kubectl rollout status deployment/multicluster-operators-subscription-release
    if [ $? != 0 ]; then
        echo "failed to deploy the subscription operator"
        exit $?;
    fi

    echo -e "\nApply the Apache service with basic auth and helm chart\n"
    kubectl apply -f apache-basic-auth/apache-basic-auth-service.yaml
}

setup_operators(){
    setup_application_operator
	setup_placementrule_operator

	setup_subscription_operator
    setup_channel_operator
    setup_helmrelease_operator


    if [ "$TRAVIS_BUILD" != 1 ]; then
        sleep 90
    fi

   	echo -e "\nRunning images\n"
	kubectl get deploy -A -o jsonpath='{.items[*].spec.template.spec.containers[*].image}' | xargs -n1 echo

    echo -e "\nPod status\n"

	kubectl get po -A
}

function cleanup()
{

	docker kill apache-basic-auth-container || true
	docker rm apache-basic-auth-container || true

  	echo -e "\nPod status\n"

	kubectl get po -A

	echo "channel webhook resource"
	kubectl get svc -n default
	kubectl get ValidatingWebhookConfiguration -n default
}

setup_operators


trap cleanup EXIT

export KUBE_DIR="../../default-kubeconfigs"
# echo "Process the canary test cases"
# go test -v ./client/canary/...

echo "Process the API test cases"
go test -v ./client/e2e_client/...

exit 0

