#! /bin/bash
echo "e2e TEST - ArgoCD integration"

KUBECONFIG_HUB="/opt/e2e/default-kubeconfigs/hub"
KUBECONFIG_SPOKE="/opt/e2e/default-kubeconfigs/import-kubeconfig"

KUBECTL_HUB="kubectl --kubeconfig $KUBECONFIG_HUB"
KUBECTL_SPOKE="kubectl --kubeconfig $KUBECONFIG_SPOKE"

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
        $KUBECTL_HUB delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        $KUBECTL_HUB delete namespace argocd --ignore-not-found
        sleep 5
    fi
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
$KUBECTL_HUB apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 5

waitForRes $KUBECONFIG_HUB "pods" "argocd-server" "argocd" ""
waitForRes $KUBECONFIG_HUB "pods" "argocd-repo-server" "argocd" ""
waitForRes $KUBECONFIG_HUB "pods" "argocd-redis" "argocd" ""
waitForRes $KUBECONFIG_HUB "pods" "argocd-dex-server" "argocd" ""
waitForRes $KUBECONFIG_HUB "pods" "argocd-application-controller" "argocd" ""

echo "==== port forward argocd server ===="
MINUTE=0
while [ true ]; do
    # Wait up to 3min
    if [ $MINUTE -gt 180 ]; then
        echo "Timeout waiting for port forwarding argocd server."
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    for pid in $(ps aux | grep 'port-forward svc\/argocd-server' | awk '{print $2}'); do kill -9 $pid; done
    $KUBECTL_HUB -n argocd port-forward svc/argocd-server -n argocd 8080:443 > /dev/null &
    if [ $? -eq 0 ]; then
        break
    fi

    echo "* STATUS: Port forwarding argocd server failed. Retry in 10 sec"
    sleep 10
    (( MINUTE = MINUTE + 10 ))
done

# install argocd cli
# ARGO_VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

# apply the fixed version v 2.0.0. The latest v2.0.1 is not working.
ARGO_VERSION=v2.0.0
LOCAL_OS=$(uname)

echo "$LOCAL_OS, $ARGO_VERSION"

rm -fr /usr/local/bin/argocd

if [[ "$LOCAL_OS" == "Linux" ]]; then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$ARGO_VERSION/argocd-linux-amd64
elif [[ "$LOCAL_OS" == "Darwin" ]]; then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$ARGO_VERSION/argocd-darwin-amd64
fi

chmod +x /usr/local/bin/argocd

# login using the cli
ARGOCD_PWD=$($KUBECTL_HUB -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
ARGOCD_HOST="localhost:8080"

echo "argocd login $ARGOCD_HOST --insecure --username admin --password $ARGOCD_PWD --grpc-web"

MINUTE=0
while [ true ]; do
    # Wait up to 5min, should only take about 1-2 min
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for argocd cli login."
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi
    argocd login $ARGOCD_HOST --insecure --username admin --password $ARGOCD_PWD --grpc-web
    if [ $? -eq 0 ]; then
        break
    fi
    echo "* STATUS: ArgoCD host NOT ready. Retry in 10 sec"
    sleep 10
    (( MINUTE = MINUTE + 10 ))
done

echo "==== Enabling ArgoCd cluster collection for the managed local-cluster ===="
SPOKE_CLUSTER=$($KUBECTL_HUB get managedclusters -l local-cluster=true -o name |head -n 1 |awk -F/ '{print $2}')

echo "SPOKE_CLUSTER: $SPOKE_CLUSTER"

$KUBECTL_HUB patch klusterletaddonconfig -n $SPOKE_CLUSTER $SPOKE_CLUSTER --type merge -p '{"spec":{"applicationManager":{"argocdCluster":true}}}'

MINUTE=0
while [ true ]; do
    # Wait up to 5min, should only take about 1-2 min
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for the spoke cluster token being imported to the argocd Namespace."
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi
    $KUBECTL_HUB get secrets -n argocd "$SPOKE_CLUSTER-cluster-secret"
    if [ $? -eq 0 ]; then
        break
    fi
    echo "* STATUS: The spoke cluster token is NOT in the argocd Namespace. Re-check in 10 sec"
    sleep 10
    (( MINUTE = MINUTE + 10 ))
done

echo "$SPOKE_CLUSTER cluster secrets imported to the argocd namespace successfully."

sleep 10

echo "==== verifying the the managed cluster secret in argocd cluster list ===="
argocd cluster list --grpc-web |grep -w $SPOKE_CLUSTER
if [ $? -ne 0 ]; then
    echo "Managed cluster $SPOKE_CLUSTER is NOT in the ArgoCD cluster list"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo "==== submitting a argocd application to the ACM managed cluster  ===="
SPOKE_CLUSTER_SERVER=$(argocd cluster list --grpc-web |grep -w $SPOKE_CLUSTER |awk -F' ' '{print $1}')

argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server $SPOKE_CLUSTER_SERVER --dest-namespace default --grpc-web
argocd app sync guestbook --grpc-web

waitForRes $KUBECONFIG_HUB "deployments" "guestbook-ui" "default" ""

uninstallArgocd

echo "E2E CANARY TEST - DONE"
exit 0