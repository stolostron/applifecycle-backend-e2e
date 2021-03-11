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
        # Wait up to 4min, should only take about 20-30s
        if [ $MINUTE -gt 240 ]; then
            echo "Timeout waiting for the ${resNamespace}\/${resName}."
            echo "List of current resources:"
            kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds}
            echo "You should see ${resNamespace}/${resName} ${resKinds}"
            if [ "${resKinds}" == "pods" ]; then
                kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} describe deployments ${resName}
            fi
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
        sleep 3
        (( MINUTE = MINUTE + 3 ))
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
    exit 1
fi

$KUBECTL_SPOKE cluster-info
if [ $? -ne 0 ]; then
    echo "spoke cluster Not accessed."
    exit 1
fi

ingressHub=`$KUBECTL_HUB get ingress.config.openshift.io -o custom-columns=NAME:.spec.domain --no-headers`

deleteApp

echo "==== Creating chartmuseum application ===="
$KUBECTL_HUB create -f $dataPath/app_chartmuseum.yaml

waitForRes $KUBECONFIG_HUB "pods" "chartmuseum-chartmuseum" "ns-chartmuseum" ""

echo "==== Adding route for chartmuseum ===="
$KUBECTL_HUB create -f $dataPath/app_chartmuseum_route.yaml

waitForRes $KUBECONFIG_HUB "routes" "chartmuseum-chartmuseum" "ns-chartmuseum" ""

echo "==== Upload helloworld app to HelmRepo ===="
(cd $dataPath; curl -u wshi:redhat --data-binary "@helloworld-0.1.0.tgz" http://chartmuseum-chartmuseum-ns-chartmuseum.$ingressHub/charts/api/charts)

sed -i "s/pathname:.*/pathname: 'http:\/\/chartmuseum-chartmuseum-ns-chartmuseum.$ingressHub\/charts'/" $dataPath/app_helloworld.yaml
echo "==== Creating helloworld application ===="
$KUBECTL_HUB create -f $dataPath/app_helloworld.yaml

waitForRes $KUBECONFIG_HUB "routes" "helloworld-app-route" "ns-sub-wshi" ""

status=`$KUBECTL_HUB get subscription app-helloworld-subscription-1 -n ns-sub-wshi -o custom-columns=NAME:.status.statuses.local-cluster.packages.*.phase --no-headers`
if [[ "$status" != "Subscribed" ]]; then
  echo "appsub status.statuses != Subscribed."
  exit 1
fi

status=`$KUBECTL_HUB get subscription app-helloworld-subscription-1 -n ns-sub-wshi -o custom-columns=:.status.phase --no-headers`
if [[ "$status" != "Propagated" ]]; then
  echo "appsub status != Propagated."
  exit 1
fi

status=`$KUBECTL_HUB get subscription app-helloworld-subscription-1-local -n ns-sub-wshi -o custom-columns=:.status.phase --no-headers`
if [[ "$status" != "Subscribed" ]]; then
  echo "appsub-local status != Subscribed."
  exit 1
fi

deleteApp

exit 0

