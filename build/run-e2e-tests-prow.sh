#! /bin/bash
set -e
echo "e2e TEST"

# just for pass the PROW onboard

if [ "$RUN_ON" != "github" ]; then
	echo "skip e2e on prow, maybe when clusterpool is on, we will enable it"
	exit 0
fi


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
    kubectl apply -f https://raw.githubusercontent.com/open-cluster-management/multicloud-operators-placementrule/master/hack/test/crds/clusters.open-cluster-management.io_managedclusters.crd.yaml

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

kind delete cluster
if [ $? != 0 ]; then
        exit $?;
fi

kind create cluster --image=kindest/node:v1.19.1
if [ $? != 0 ]; then
        exit $?;
fi

sleep 15

if [ ! -d "default-kubeconfigs" ]; then
    mkdir default-kubeconfigs
fi


kind get kubeconfig > default-kubeconfigs/hub

setup_operators

trap cleanup EXIT

export KUBE_DIR="../../default-kubeconfigs"
# echo "Process the canary test cases"
# go test -v ./client/canary/...

echo "Process the API test cases"
go test -v ./client/e2e_client/...

exit 0

