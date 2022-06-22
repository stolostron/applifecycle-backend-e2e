#! /bin/bash
set -e
echo "e2e TEST"

if [ "$RUN_ON" != "github" ]; then
	echo "skip e2e on prow, maybe when clusterpool is on, we will enable it"
	exit 0
fi

# need to find a way to use the Makefile to set these
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
	echo "Build is on $RUN_ON"

	# Download and install kubectl
	echo -e "\nGet kubectl binary\n"
	PLATFORM=$(uname -s | awk '{print tolower($0)}')
	if [ "$(which kubectl)" ]; then
		echo "kubectl PATH is $(which kubectl)"
	else
		mkdir -p $(pwd)/bin
		curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/$PLATFORM/amd64/kubectl && mv kubectl $(pwd)/bin/ && chmod +x $(pwd)/bin/kubectl
		export PATH=$PATH:$(pwd)/bin
		echo "kubectl PATH is $(which kubectl)"
	fi

	echo -e "\nDownload and install KinD\n"
	go get sigs.k8s.io/kind@v0.13.0

fi

kind delete cluster
if [ $? != 0 ]; then
	exit $?
fi

kind create cluster --image=kindest/node:v1.21.1
if [ $? != 0 ]; then
	exit $?
fi

sleep 15

if [ ! -d "default-kubeconfigs" ]; then
	mkdir default-kubeconfigs
fi

kind get kubeconfig > default-kubeconfigs/hub

setup_channel_operator() {
	echo "Clone the channel repo"
	echo
	if [ ! -d "multicloud-operators-channel" ]; then
		git clone https://github.com/stolostron/multicloud-operators-channel.git
	fi

	sed -i -e "s|image: .*$|image: quay.io/stolostron/multicluster-operators-channel:${COMPONENT_VERSION}|" multicloud-operators-channel/deploy/standalone/operator.yaml

	kubectl apply -f multicloud-operators-channel/deploy/crds
	kubectl apply -f multicloud-operators-channel/deploy/standalone

	kubectl rollout status deployment/multicluster-operators-channel
	if [ $? != 0 ]; then
		echo "failed to deploy the channel operator"
		exit $?
	fi
}

setup_subscription_operator() {
	echo "Clone the subscription repo"
	echo
	if [ ! -d "multicloud-operators-subscription" ]; then
		git clone https://github.com/stolostron/multicloud-operators-subscription.git
	fi

	kubectl apply -f multicloud-operators-subscription/deploy/common
	sleep 5

	echo "before sed $COMPONENT_VERSION"
	sed -i -e "s|image: .*$|image: quay.io/stolostron/multicluster-operators-subscription:${COMPONENT_VERSION}|" multicloud-operators-subscription/deploy/standalone/operator.yaml

	kubectl apply -f multicloud-operators-subscription/deploy/standalone

	kubectl rollout status deployment/multicluster-operators-subscription -n multicluster-operators
	if [ $? != 0 ]; then
		echo "failed to deploy the subscription operator"
		exit $?
	fi
}

setup_operators() {
	kubectl apply -f https://raw.githubusercontent.com/stolostron/multicloud-operators-placementrule/master/hack/test/crds/clusters.open-cluster-management.io_managedclusters.crd.yaml

	setup_subscription_operator
	setup_channel_operator

	if [ "$TRAVIS_BUILD" != 1 ]; then
		sleep 90
	fi

	echo -e "\nRunning images\n"
	kubectl get deploy -A -o jsonpath='{.items[*].spec.template.spec.containers[*].image}' | xargs -n1 echo

	echo -e "\nPod status\n"

	kubectl get po -A
}

function cleanup() {

	docker kill apache-basic-auth-container || true
	docker rm apache-basic-auth-container || true

	echo -e "\nPod status\n"

	kubectl get po -A

	echo "channel webhook resource"
	kubectl get svc -n default
	kubectl get ValidatingWebhookConfiguration -n default
}

start_up_private_helm() {
	echo "start up private helm registery"
	docker build -t ${APACHE_BASIC_AUTH_IMAGE} -f apache-basic-auth/Dockerfile .
	docker run -d --name ${APACHE_BASIC_AUTH_CONTAINER} -p 8080:8080 ${APACHE_BASIC_AUTH_IMAGE}
}

start_up_private_helm
setup_operators

trap cleanup EXIT

export KUBE_DIR="../../default-kubeconfigs"
# echo "Process the canary test cases"

if [ "$RUN_ON" != "github" ]; then
	go test -v ./client/canary/...
fi

# The default go test time is 10 minutes, we need to increase test time after adding more test cases
echo "Process the API test cases"
go test -v ./client/e2e_client/... -timeout 30m

exit 0
