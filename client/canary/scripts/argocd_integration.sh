#! /bin/bash
echo "e2e TEST - ArgoCD integration"

KUBECONFIG_HUB="/opt/e2e/default-kubeconfigs/hub"
KUBECONFIG_SPOKE="/opt/e2e/default-kubeconfigs/import-kubeconfig"

KUBECTL_HUB="kubectl --kubeconfig $KUBECONFIG_HUB"
KUBECTL_SPOKE="kubectl --kubeconfig $KUBECONFIG_SPOKE"

function waitForPod() {
    FOUND=1
    MINUTE=0
    kubeConfig=$1
    podName=$2
    podNamespace=$3
    ignore=$4
    running="\([0-9]\+\)\/\1"
    printf "\n#####\nWait for ${podNamespace}/${podName} to reach running state (4min).\n"
    while [ ${FOUND} -eq 1 ]; do
        # Wait up to 4min, should only take about 20-30s
        if [ $MINUTE -gt 240 ]; then
            echo "Timeout waiting for the ${podNamespace}\/${podName}."
            echo "List of current pods:"
            kubectl --kubeconfig ${kubeConfig} -n ${podNamespace} get pods
            echo "You should see ${podNamespace}/${podName} pod"
            exit 1
        fi
        if [ "$ignore" == "" ]; then
            echo "kubectl --kubeconfig ${kubeConfig} -n ${podNamespace} get pods | grep ${podName}"
            operatorPod=`kubectl --kubeconfig ${kubeConfig} -n ${podNamespace} get pods | grep ${podName}`
        else
            operatorPod=`kubectl --kubeconfig ${kubeConfig} -n ${podNamespace} get pods | grep ${podName} | grep -v ${ignore}`
        fi
        if [[ $(echo $operatorPod | grep "${running}") ]]; then
            echo "* ${podName} is running"
            break
        elif [ "$operatorPod" == "" ]; then
            operatorPod="Waiting"
        fi
        echo "* STATUS: $operatorPod"
        sleep 3
        (( MINUTE = MINUTE + 3 ))
    done
}

function uninstallArgocd() {
    $KUBECTL_SPOKE delete all -n default  --all

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
    exit 1
fi

$KUBECTL_SPOKE cluster-info
if [ $? -ne 0 ]; then
    echo "spoke cluster Not accessed."
    exit 1
fi

uninstallArgocd

echo "==== Installing ArgoCd server ===="
$KUBECTL_HUB create namespace argocd
$KUBECTL_HUB apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 5

waitForPod $KUBECONFIG_HUB "argocd-server" "argocd" ""
waitForPod $KUBECONFIG_HUB "argocd-repo-server" "argocd" ""
waitForPod $KUBECONFIG_HUB "argocd-redis" "argocd" ""
waitForPod $KUBECONFIG_HUB "argocd-dex-server" "argocd" ""
waitForPod $KUBECONFIG_HUB "argocd-application-controller" "argocd" ""

kill $(ps aux | grep 'port-forward svc\/argocd-server' | awk '{print $2}')
$KUBECTL_HUB -n argocd port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &

sleep 5

# install argocd cli
ARGO_VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

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
ARGOCD_PWD=$($KUBECTL_HUB get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)
ARGOCD_HOST="localhost:8080"

echo "argocd login $ARGOCD_HOST --insecure --username admin --password $ARGOCD_PWD"

MINUTE=0
while [ true ]; do
    # Wait up to 5min, should only take about 1-2 min
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for argocd cli login."
        exit 1
    fi
    argocd login $ARGOCD_HOST --insecure --username admin --password $ARGOCD_PWD
    if [ $? -eq 0 ]; then
        break
    fi
    echo "* STATUS: ArgoCD host NOT ready. Retry in 10 sec"
    sleep 10
    (( MINUTE = MINUTE + 10 ))
done

echo "==== Enabling ArgoCd cluster collection for the managed cluster ===="
SPOKE_CLUSTER=$($KUBECTL_HUB get managedclusters -o name |grep -v local-cluster |head -n 1 |awk -F/ '{print $2}')

echo "SPOKE_CLUSTER: $SPOKE_CLUSTER"

$KUBECTL_HUB patch klusterletaddonconfig -n $SPOKE_CLUSTER $SPOKE_CLUSTER --type merge -p '{"spec":{"applicationManager":{"argocdCluster":true}}}'

echo "==== verifying the the managed cluster secret in argocd cluster list ===="
argocd cluster list  |grep -w $SPOKE_CLUSTER
if [ $? -ne 0 ]; then
    echo "Managed cluster $SPOKE_CLUSTER is not in ArgoCD cluster list"
    exit 1
fi

echo "==== submitting a argocd application to the ACM managed cluster  ===="
SPOKE_CLUSTER_SERVER=$(argocd cluster list  |grep -w $SPOKE_CLUSTER |awk -F' ' '{print $1}')

argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server $SPOKE_CLUSTER_SERVER --dest-namespace default
argocd app sync guestbook

waitForPod $KUBECONFIG_SPOKE "guestbook-ui" "default" ""

# uninstallArgocd

exit 0
