#! /bin/bash
echo "E2E TEST - ArgoCD integration"

KUBECONFIG_HUB="/opt/e2e/default-kubeconfigs/hub"

KUBECTL_HUB="oc --kubeconfig $KUBECONFIG_HUB --insecure-skip-tls-verify=true"

# apply the fixed version v 1.8.7 for argocd
ARGO_VERSION=v2.0.0
LOCAL_OS=$(uname)

echo "$(date) Local OS: $LOCAL_OS, ArgoCD version: $ARGO_VERSION"

waitForRes() {
    FOUND=1
    MINUTE=0
    kubeConfig=$1
    resKinds=$2
    resName=$3
    resNamespace=$4
    ignore=$5
    running="\([0-9]\+\)\/\1"
    printf "$(date) \n#####\nWait for ${resNamespace}/${resName} to reach running state (4min).\n"
    while [ ${FOUND} -eq 1 ]; do
        # Wait up to 4min, should only take about 20-30s
        if [ $MINUTE -gt 240 ]; then
            echo "$(date) Timeout waiting for the ${resNamespace}\/${resName}."
            echo "$(date) List of current resources:"
            kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds}
            echo "$(date) You should see ${resNamespace}/${resName} ${resKinds}"
            if [ "${resKinds}" == "pods" ]; then
                kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} describe deployments ${resName}
            fi
            echo "E2E CANARY TEST - EXIT WITH ERROR"
            exit 1
        fi
        if [ "$ignore" == "" ]; then
            echo "$(date) kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds} | grep ${resName}"
            operatorRes=`kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds} | grep ${resName}`
        else
            operatorRes=`kubectl --kubeconfig ${kubeConfig} -n ${resNamespace} get ${resKinds} | grep ${resName} | grep -v ${ignore}`
        fi
        if [[ $(echo $operatorRes | grep "${running}") ]]; then
            echo "$(date) * ${resName} is running"
            break
        elif [[ ("${operatorRes}" > "") && ("${resKinds}" == "deployments") ]]; then
            echo "$(date) * ${resKinds} created: ${operatorRes}"
            break
        elif [ "$operatorRes" == "" ]; then
            operatorRes="Waiting"
        fi
        echo "$(date) * STATUS: $operatorRes"
        sleep 3
        (( MINUTE = MINUTE + 3 ))
    done
}

installArgocd() {
    argoNamespace=$1

    echo "$(date) ==== Installing ArgoCD server into namespace ${argoNamespace} ===="

    $KUBECTL_HUB create namespace ${argoNamespace}
    $KUBECTL_HUB apply -n ${argoNamespace} -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGO_VERSION/manifests/install.yaml
    sleep 5

    waitForRes $KUBECONFIG_HUB "pods" "argocd-server" ${argoNamespace} ""
    waitForRes $KUBECONFIG_HUB "pods" "argocd-repo-server" ${argoNamespace} ""
    waitForRes $KUBECONFIG_HUB "pods" "argocd-redis" ${argoNamespace} ""
    waitForRes $KUBECONFIG_HUB "pods" "argocd-dex-server" ${argoNamespace} ""
    waitForRes $KUBECONFIG_HUB "pods" "argocd-application-controller" ${argoNamespace} ""

    $KUBECTL_HUB -n ${argoNamespace} patch deployment argocd-server -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"argocd-server"}],"containers":[{"command":["argocd-server","--insecure","--staticassets","/shared/app"],"name":"argocd-server"}]}}}}'
}

installGitopsOperator() {
    argoNamespace=$1

    echo "$(date) ==== Installing openshift-gitops operator ===="

    $KUBECTL_HUB apply -f scripts/argocd/openshift-gitops-sub.yaml
    sleep 5

    waitForRes $KUBECONFIG_HUB "pods" "openshift-gitops-application-controller" ${argoNamespace} ""
    waitForRes $KUBECONFIG_HUB "pods" "openshift-gitops-applicationset-controller" ${argoNamespace} ""
    waitForRes $KUBECONFIG_HUB "pods" "openshift-gitops-redis" ${argoNamespace} ""
    waitForRes $KUBECONFIG_HUB "pods" "openshift-gitops-repo-server" ${argoNamespace} ""
    waitForRes $KUBECONFIG_HUB "pods" "openshift-gitops-server" ${argoNamespace} ""
}

uninstallArgocd() {
    argoNamespace=$1

    echo "$(date) ==== Uninstalling ArgoCD server from namespace ${argoNamespace} ===="

    $KUBECTL_HUB get namespace ${argoNamespace}
    if [ $? -eq 0 ]; then
        $KUBECTL_HUB delete -n ${argoNamespace} -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGO_VERSION/manifests/install.yaml
        $KUBECTL_HUB -n ${argoNamespace} delete route argocd-server
        $KUBECTL_HUB delete namespace ${argoNamespace} --ignore-not-found
        sleep 5
    fi

    # stop port forwarding service if exists
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
            echo "$(date) Timeout waiting for ${CMD}"
            echo "E2E CANARY TEST - EXIT WITH ERROR"
            exit 1
        fi
        echo ${CMD}
        eval ${CMD}
        if [ $? -eq 0 ]; then
            break
        fi
        echo "$(date) * STATUS: ${WAIT_MSG}. Retry in 10 sec"
        sleep 10
        (( MINUTE = MINUTE + 10 ))
    done
}

verifyClusterRegistrationInArgo() {
    argoNamespace=$1

    # port forward argocd server
    $KUBECTL_HUB -n ${argoNamespace} port-forward svc/argocd-server --pod-running-timeout=5m0s 8080:443 > /dev/null &
    sleep 10
    sh ./scripts/argocd/port_forward.sh > /dev/null &

    # Log into argocd
    ARGOCD_PWD=$($KUBECTL_HUB -n ${argoNamespace} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    ARGOCD_HOST="localhost:8080"

    RUN_CMD="argocd login $ARGOCD_HOST --insecure --username admin --password $ARGOCD_PWD --grpc-web"
    WAIT_MSG="ArgoCD host NOT ready"
    waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"

    sleep 10

    MANAGED_CLUSTERS=( $($KUBECTL_HUB get managedclusters -o name |awk -F/ '{print $2}') )

    for element in "${MANAGED_CLUSTERS[@]}"
    do
        echo "$(date) ==== verifying that the the managed cluster $element is registered in argocd ${argoNamespace} ===="
        RUN_CMD="argocd cluster list --grpc-web |grep -w $element"
        WAIT_MSG="failed to list argocd cluster"
        waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"
    done

    # stop port forwarding
    for pid in $(ps aux | grep 'port_forward\.sh' | awk '{print $2}'); do kill -9 $pid; done
    for pid in $(ps aux | grep 'port-forward svc\/argocd-server' | awk '{print $2}'); do kill -9 $pid; done
}

verifyClusterRegistrationInGitOpsOperator() {
    # Log into argocd
    ARGOCD_PWD=$($KUBECTL_HUB -n openshift-gitops get secret openshift-gitops-cluster -o jsonpath="{.data.admin\.password}" | base64 -d)
    ARGOCD_HOST=$($KUBECTL_HUB get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')

    RUN_CMD="argocd login $ARGOCD_HOST --insecure --username admin --password $ARGOCD_PWD --grpc-web"
    WAIT_MSG="ArgoCD host NOT ready"
    waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"

    sleep 10

    MANAGED_CLUSTERS=( $($KUBECTL_HUB get managedclusters -o name |awk -F/ '{print $2}') )

    for element in "${MANAGED_CLUSTERS[@]}"
    do
        echo "$(date) ==== verifying that the the managed cluster $element is registered in openshift-gitops operator default instance ===="
        RUN_CMD="argocd cluster list --grpc-web |grep -w $element"
        WAIT_MSG="failed to list argocd cluster"
        waitForCMD "\${RUN_CMD}" "\${WAIT_MSG}"
    done    
}

verifySecretDeleted() {
    managedCluster=$1
    namespace=$2

    # Wait for the managed cluster secret to be deleted
    MINUTE=0
    while [ true ]; do
        # Wait up to 2min
        if [ $MINUTE -gt 120 ]; then
            echo "$(date) Timeout waiting for the managed cluster secret ${managedCluster}-cluster-secret to be deleted from ${namespace}"
            echo "E2E CANARY TEST - EXIT WITH ERROR"
            exit 1
        fi
        OUTPUT=$($KUBECTL_HUB get secret ${managedCluster}-cluster-secret -n ${namespace})
        if [ "${OUTPUT}" == "" ]; then
            break
        fi

        echo "$(date) waiting for the managed cluster secret ${managedCluster}-cluster-secret to be deleted from ${namespace}"

        sleep 10
        (( MINUTE = MINUTE + 10 ))
    done

}

uninstallOpenshiftGitopsOperator() {
    echo "$(date) ==== Uninstalling openshift-gitops operator ===="

    # openshift-gitops operator uninstallation does not work. Need to do these workaround
    $KUBECTL_HUB delete -f scripts/argocd/openshift-gitops-sub.yaml
    GITOPS_OP_CSV=$($KUBECTL_HUB get csv -n openshift-operators -o name |  grep gitops |head -n 1 |awk -F/ '{print $2}')
    $KUBECTL_HUB delete subscription.operators.coreos.com openshift-gitops -n openshift-operators --ignore-not-found
    if [ "${GITOPS_OP_CSV}" != "" ]; then
        $KUBECTL_HUB delete clusterserviceversion ${GITOPS_OP_CSV} -n openshift-operators --ignore-not-found
    fi
    $KUBECTL_HUB delete deployment --all -n openshift-gitops --ignore-not-found
    $KUBECTL_HUB delete service --all -n openshift-gitops --ignore-not-found
    $KUBECTL_HUB delete route --all -n openshift-gitops --ignore-not-found
    $KUBECTL_HUB delete statefulset.apps openshift-gitops-application-controller -n openshift-gitops --ignore-not-found

    # Wait for all resources to be deleted
    MINUTE=0
    while [ true ]; do
        # Wait up to 5min
        if [ $MINUTE -gt 300 ]; then
            echo "$(date) Timeout waiting for "
            echo "E2E CANARY TEST - EXIT WITH ERROR"
            exit 1
        fi
        OUTPUT=$(${KUBECTL_HUB} get all -n openshift-gitops)
        if [ "${OUTPUT}" == "" ]; then
            break
        fi

        echo "$(date) waiting for all resources to be deleted. Retry in 10 sec"

        sleep 10
        (( MINUTE = MINUTE + 10 ))
    done

    echo "$(date) OpenShift GitOps operator was uninstalled"
}

echo "$(date) ==== Validating hub cluster access ===="
$KUBECTL_HUB cluster-info
if [ $? -ne 0 ]; then
    echo "$(date) hub cluster Not accessed."
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Make sure we start with no ArgoCD server
uninstallArgocd argocdtest1
uninstallArgocd argocdtest2

# Install two ArgoCD servers in namespace argocdtest1 and argocdtest2
installArgocd argocdtest1
echo "$(date) installed ArgoCD instance in argocdtest1"

installArgocd argocdtest2
echo "$(date) installed ArgoCD instance in argocdtest2"

# Create managedclusterset
$KUBECTL_HUB apply -f scripts/argocd/managedclusterset.yaml
echo "$(date) managedclusterset created"

# Add all managed clusters to managedclusterset clusterset1
MANAGED_CLUSTERS=( $($KUBECTL_HUB get managedclusters -o name |awk -F/ '{print $2}') )

for element in "${MANAGED_CLUSTERS[@]}"
do
   echo "$(date) Adding ${element} to managed cluster set clusterset1"
   $KUBECTL_HUB label --overwrite managedclusters ${element} cluster.open-cluster-management.io/clusterset=clusterset1
done

# Create ManagedClusterSetBinding
$KUBECTL_HUB apply -f scripts/argocd/managedclustersetbinding.yaml
echo "$(date) managedclustersetbinding created"

# Create placement to choose all managed clusters
sed -i -e "s/__NUM__/${#MANAGED_CLUSTERS[@]}/" scripts/argocd/placement.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __NUM__ in placement.yaml"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi
$KUBECTL_HUB apply -f scripts/argocd/placement.yaml
echo "$(date) placement created"

# Sleep for placement decision
sleep 10

# Install ArgoCD CLI
rm -fr /usr/local/bin/argocd

if [[ "$LOCAL_OS" == "Linux" ]]; then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$ARGO_VERSION/argocd-linux-amd64
elif [[ "$LOCAL_OS" == "Darwin" ]]; then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$ARGO_VERSION/argocd-darwin-amd64
fi

chmod +x /usr/local/bin/argocd

# Create GitOpsCluster for argocdtest1
$KUBECTL_HUB delete -f scripts/argocd/gitopscluster.yaml
$KUBECTL_HUB apply -f scripts/argocd/gitopscluster.yaml
echo "$(date) gitopscluster created"

# Sleep for GitOpsCluster reconcile
sleep 10

verifyClusterRegistrationInArgo "argocdtest1"

# Change the target the second ArgoCD instance in argocdtest2
$KUBECTL_HUB -n default patch gitopscluster gitops-cluster-test -p '{"spec": {"argoServer": {"argoNamespace": "argocdtest2"}}}' --type merge

# Sleep for GitOpsCluster reconcile
sleep 10

# Verify that the managed cluster secrets are deleted from the first argocd instance
echo "$(date)  ====  verify that the managed cluster secrets are deleted from the first argocd instance"
for element in "${MANAGED_CLUSTERS[@]}"
do
   verifySecretDeleted ${element} "argocdtest1"
done

verifyClusterRegistrationInArgo "argocdtest2"

# Remove all test resources
$KUBECTL_HUB delete -f scripts/argocd/placement.yaml
echo "$(date) placement deleted"
$KUBECTL_HUB delete -f scripts/argocd/managedclustersetbinding.yaml
echo "$(date) managedclustersetbinding deleted"

for element in "${MANAGED_CLUSTERS[@]}"
do
   echo "$(date) Removing ${element} from managed cluster set clusterset1"
   $KUBECTL_HUB label --overwrite managedclusters ${element} cluster.open-cluster-management.io/clusterset-
done

$KUBECTL_HUB apply -f scripts/argocd/managedclusterset.yaml
echo "$(date) managedclusterset deleted"


# Uninstall the ArgoCD servers
uninstallArgocd argocdtest1
echo "$(date) uninstalled ArgoCD from argocdtest1"
uninstallArgocd argocdtest2
echo "$(date) uninstalled ArgoCD from argocdtest2"

echo "E2E CANARY TEST - DONE"
exit 0