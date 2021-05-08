#! /bin/bash
echo "e2e TEST - ArgoCD integration"

KUBECONFIG_HUB="/opt/e2e/default-kubeconfigs/hub"
KUBECONFIG_SPOKE="/opt/e2e/default-kubeconfigs/import-kubeconfig"

KUBECTL_HUB="kubectl --kubeconfig $KUBECONFIG_HUB"
KUBECTL_SPOKE="kubectl --kubeconfig $KUBECONFIG_SPOKE"

# apply the fixed version v 1.8.7 for argocd
ARGO_VERSION=v2.0.0
LOCAL_OS=$(uname)

echo "$LOCAL_OS, $ARGO_VERSION"

waitForRes() {
    FOUND=1
    MINUTE=0
    kubeConfig=$1
    resKinds=$2
    resName=$3
    resNamespace=$4
    ignore=$5
    running="\([0-9]\+\)\/\1"
    printf "\n#####\nWait for ${resNamespace}/${resName} to reach running state (4min).\n"
    while [ ${FOUND} -eq 1 ]; do
        # Wait up to 4min, should only take about 20-30s
        if [ $MINUTE -gt 240 ]; then
            echo "Timeout waiting for the ${resNamespace}\/${resName}."
            echo "List of current resources:"
            kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds}
            echo "You should see ${resNamespace}/${resName} ${resKinds}"
            if [ "${resKinds}" == "pods" ]; then
                kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} describe deployments ${resName}
            fi
            echo "E2E CANARY TEST - EXIT WITH ERROR"
            exit 1
        fi
        if [ "$ignore" == "" ]; then
            echo "kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds} | grep ${resName}"
            operatorRes=`kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds} | grep ${resName}`
        else
            operatorRes=`kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds} | grep ${resName} | grep -v ${ignore}`
        fi
        if [[ $(echo $operatorRes | grep "${running}") ]]; then
            echo "* ${resName} is running"
            break
        elif [[ ("${operatorRes}" > "") && ("${resKinds}" == "deployments") ]]; then
            echo "* ${resKinds} created: ${operatorRes}"
            break
        elif [ "$operatorRes" == "" ]; then
            operatorRes="Waiting"
        fi
        echo "* STATUS: $operatorRes"
        sleep 3
        (( MINUTE = MINUTE + 3 ))
    done
}

uninstallArgocd() {
    $KUBECTL_HUB delete deployments -n default  guestbook-ui
    $KUBECTL_HUB delete services -n default  guestbook-ui

    $KUBECTL_HUB get namespace argocd
    if [ $? -eq 0 ]; then
        echo "==== UnInstalling ArgoCd server ===="
        $KUBECTL_HUB delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGO_VERSION/manifests/install.yaml
        $KUBECTL_HUB delete namespace argocd --ignore-not-found
        sleep 5
    fi

    for pid in $(ps aux | grep 'port_forward\.sh' | awk '{print $2}'); do kill -9 $pid; done
    for pid in $(ps aux | grep 'port-forward svc\/argocd-server' | awk '{print $2}'); do kill -9 $pid; done
}

waitForCMD() {
    eval CMD="$1"
    eval WAIT_MSG="$2"

    MINUTE=0
    while [ true ]; do
        # Wait up to 5min
        if [ $MINUTE -gt 300 ]; then
            echo "Timeout waiting for ${CMD}"
            echo "E2E CANARY TEST - EXIT WITH ERROR"
            exit 1
        fi
        echo ${CMD}
        eval ${CMD}
        if [ $? -eq 0 ]; then
            break
        fi
        echo "* STATUS: ${WAIT_MSG}. Retry in 10 sec"
        sleep 10
        (( MINUTE = MINUTE + 10 ))
    done
}

echo "==== Validating hub and spoke cluster access ===="
$KUBECTL_HUB cluster-info
if [ $? -ne 0 ]; then
    echo "hub cluster Not accessed."
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

$KUBECTL_SPOKE cluster-info
if [ $? -ne 0 ]; then
    echo "spoke cluster Not accessed."
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

uninstallArgocd

echo "==== Installing ArgoCd server ===="
$KUBECTL_HUB create namespace argocd
$KUBECTL_HUB apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGO_VERSION/manifests/install.yaml
sleep 5

waitForRes $KUBECONFIG_HUB "pods" "argocd-server" "argocd" ""
waitForRes $KUBECONFIG_HUB "pods" "argocd-repo-server" "argocd" ""
waitForRes $KUBECONFIG_HUB "pods" "argocd-redis" "argocd" ""
waitForRes $KUBECONFIG_HUB "pods" "argocd-dex-server" "argocd" ""
waitForRes $KUBECONFIG_HUB "pods" "argocd-application-controller" "argocd" ""

sleep 10

rm -fr /usr/local/bin/argocd

if [[ "$LOCAL_OS" == "Linux" ]]; then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$ARGO_VERSION/argocd-linux-amd64
elif [[ "$LOCAL_OS" == "Darwin" ]]; then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$ARGO_VERSION/argocd-darwin-amd64
fi

chmod +x /usr/local/bin/argocd

echo "==== port forward argocd server ===="
$KUBECTL_HUB -n argocd port-forward svc/argocd-server -n argocd --pod-running-timeout=5m0s 8080:443 > /dev/null &

sleep 10

sh ./scripts/argocd/port_forward.sh > /dev/null &

# login using the cli
ARGOCD_PWD=$($KUBECTL_HUB -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
ARGOCD_HOST="localhost:8080"

RUN_CMD="argocd login $ARGOCD_HOST --insecure --username admin --password $ARGOCD_PWD --grpc-web"
WAIT_MSG="ArgoCD host NOT ready"
waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"

echo "==== Enabling ArgoCd cluster collection for the managed local-cluster ===="
SPOKE_CLUSTER=$($KUBECTL_HUB get managedclusters -l local-cluster=true -o name |head -n 1 |awk -F/ '{print $2}')

echo "SPOKE_CLUSTER: $SPOKE_CLUSTER"

$KUBECTL_HUB patch klusterletaddonconfig -n $SPOKE_CLUSTER $SPOKE_CLUSTER --type merge -p '{"spec":{"applicationManager":{"argocdCluster":true}}}'

RUN_CMD="$KUBECTL_HUB get secrets -n argocd $SPOKE_CLUSTER-cluster-secret"
WAIT_MSG="The spoke cluster token is NOT in the argocd Namespace"
waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"

echo "$SPOKE_CLUSTER cluster secrets imported to the argocd namespace successfully."

sleep 10

echo "==== verifying the the managed cluster secret in argocd cluster list ===="
RUN_CMD="argocd cluster list --grpc-web |grep -w $SPOKE_CLUSTER"
WAIT_MSG="failed to list argocd cluster"
waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"

echo "==== submitting a argocd application to the ACM managed cluster  ===="
SPOKE_CLUSTER_SERVER=$(argocd cluster list --grpc-web |grep -w $SPOKE_CLUSTER |awk -F' ' '{print $1}')

RUN_CMD="argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server $SPOKE_CLUSTER_SERVER --dest-namespace default --grpc-web"
WAIT_MSG="argocd application creation failed"
waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"

RUN_CMD="argocd app sync guestbook --grpc-web"
WAIT_MSG="failed to sync  argocd application"
waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"

waitForRes $KUBECONFIG_HUB "deployments" "guestbook-ui" "default" ""

uninstallArgocd

echo "E2E CANARY TEST - DONE"
exit 0