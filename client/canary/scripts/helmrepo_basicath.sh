#!/bin/bash
echo "e2e TEST - HelmRepo basic auth"

KUBECONFIG_HUB="/opt/e2e/default-kubeconfigs/hub"
KUBECONFIG_SPOKE="/opt/e2e/default-kubeconfigs/import-kubeconfig"

KUBECTL_HUB="kubectl --kubeconfig $KUBECONFIG_HUB"
KUBECTL_SPOKE="kubectl --kubeconfig $KUBECONFIG_SPOKE"

dataPath="./scripts/helmrepo_basicath"

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
        # Wait up to 10min, should only take about 20-30s
        if [ $MINUTE -gt 600 ]; then
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
        elif [[ ("${operatorRes}" > "") && ("${resKinds}" == "routes") ]]; then
            echo "* ${resKinds} created: ${operatorRes}"
            break
        elif [ "$operatorRes" == "" ]; then
            operatorRes="Waiting"
        fi
        echo "* STATUS: $operatorRes"
        sleep 15
        (( MINUTE = MINUTE + 15 ))
    done
}

deleteApp() {
  $KUBECTL_HUB delete -f $dataPath/app_helloworld.yaml
  $KUBECTL_HUB delete -f $dataPath/app_chartmuseum.yaml
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

ingressHub=`$KUBECTL_HUB get ingress.config.openshift.io -o custom-columns=NAME:.spec.domain --no-headers`

deleteApp

echo "==== Creating chartmuseum application ===="
$KUBECTL_HUB create -f $dataPath/app_chartmuseum.yaml

waitForRes $KUBECONFIG_HUB "pods" "chartmuseum" "ns-chartmuseum" ""

echo "==== Adding route for chartmuseum ===="
$KUBECTL_HUB create -f $dataPath/app_chartmuseum_route.yaml

waitForRes $KUBECONFIG_HUB "routes" "chartmuseum-chartmuseum" "ns-chartmuseum" ""

sleep 10
echo "==== Upload helloworld app to HelmRepo ===="

(cd $dataPath; curl -u wshi:redhat --data-binary '@helloworld-0.1.0.tgz' http://chartmuseum-chartmuseum-ns-chartmuseum.$ingressHub/charts/api/charts)

sed -i -e "s/pathname:.*/pathname: 'http:\/\/chartmuseum-chartmuseum-ns-chartmuseum.$ingressHub\/charts'/" $dataPath/app_helloworld.yaml
echo "\n==== Creating helloworld application ===="
$KUBECTL_HUB create -f $dataPath/app_helloworld.yaml

waitForRes $KUBECONFIG_HUB "routes" "helloworld-app-route" "ns-sub-wshi" ""

MINUTE=0
while [ true ]; do
    # Wait up to 5min to see if the local appsub is subscribed
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for local appsub status being subscribed."
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi
    status=`$KUBECTL_HUB get appsub app-helloworld-subscription-1-local -n ns-sub-wshi -o custom-columns=:.status.phase --no-headers`
    if [ "$status" == "Subscribed" ]; then
        break
    fi
    echo "* STATUS: local appsub NOT subscribed. Retry in 10 sec"
    echo `$KUBECTL_HUB get appsub app-helloworld-subscription-1-local -n ns-sub-wshi -o custom-columns=:.status`
    sleep 10
    (( MINUTE = MINUTE + 10 ))
done

echo "\n==== helloworld application deployed successfully ===="
deleteApp

echo "E2E CANARY TEST - DONE"
exit 0