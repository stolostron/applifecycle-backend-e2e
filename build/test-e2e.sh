#! /bin/bash
set -e
echo "e2e TEST"
# need to find a way to use the Makefile to set these
IMG=$(cat COMPONENT_NAME 2> /dev/null)

if [ "$TRAVIS_BUILD" != 1 ]; then
    echo "Build is on Travis" 

    echo -e "Get kubectl binary \n"
    # Download and install kubectl
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/

    echo -e "\nDownload and install KinD\n"
    GO111MODULE=on go get sigs.k8s.io/kind

    kind create cluster
    if [ $? != 0 ]; then
            exit $?;
    fi
    sleep 15

fi

kind get kubeconfig > default-kubeconfigs/hub

./build/_output/bin/${IMG} &

sleep 10
curl http://localhost:8765/cluster | head -n 10
curl http://localhost:8765/testcase | head -n 10
curl http://localhost:8765/expectation | head -n 10

