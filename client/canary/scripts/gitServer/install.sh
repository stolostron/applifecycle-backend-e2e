#!/bin/bash

echo "==== Deploying Gogs Git server with custom certificate ===="

# Find the directory we're in (used to reference other scripts)
root_dir=$(pwd)
cd scripts/gitServer
cur_dir=$(pwd)
echo "Current directory is $cur_dir"

kubeconfig=/opt/e2e/default-kubeconfigs/hub

KUBECTL_CMD="oc --kubeconfig /opt/e2e/default-kubeconfigs/hub --insecure-skip-tls-verify=true"

# Get the application domain
APP_DOMAIN=`$KUBECTL_CMD -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'`
if [ $? -ne 0 ]; then
    echo "failed to get the application domain"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo "Application domain is $APP_DOMAIN"

GIT_HOSTNAME=gogs-svc-default.$APP_DOMAIN
echo "Git hostname is $GIT_HOSTNAME"

# Inject the real Git hostname into the Gogs deployment YAML
sed -i -e "s/__HOSTNAME__/$GIT_HOSTNAME/" gogs.yaml
if [ $? -ne 0 ]; then
    echo "failed to substitue __HOSTNAME__ in gogs.yaml"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi


echo "Switching to default namespace"
$KUBECTL_CMD project default

# want to run the gogs container as root
$KUBECTL_CMD adm policy add-scc-to-user anyuid -z default
if [ $? -ne 0 ]; then
    echo "failed to update security policy"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Deploy Gogs Git server
$KUBECTL_CMD apply -f gogs.yaml
if [ $? -ne 0 ]; then
    echo "failed to deploy Gogs server"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

sleep 5

# Get Gogs pod name
GOGS_POD_NAME=`$KUBECTL_CMD get pods -n default -o=custom-columns='DATA:metadata.name' | grep gogs-`
if [ $? -ne 0 ]; then
    echo "failed to get the pod name"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo "Gogs pod name is $GOGS_POD_NAME"

# Wait for Gogs to be running
FOUND=1
MINUTE=0
running="\([0-9]\+\)\/\1"
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 5min
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for Gogs pod ${GOGS_POD_NAME}."
        echo "List of current pods:"
        $KUBECTL_CMD -n default get pods
        echo
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    pod=`$KUBECTL_CMD -n default get pod $GOGS_POD_NAME`

    if [[ $(echo $pod | grep "${running}") ]]; then 
        echo "${GOGS_POD_NAME} is running"
        break
    fi
    sleep 3
    (( MINUTE = MINUTE + 3 ))
done

OC_VERSION=`$KUBECTL_CMD version`
echo "$OC_VERSION"

echo "$pod"

DESC_POD=`$KUBECTL_CMD describe pod $GOGS_POD_NAME`
echo "$DESC_POD"

sleep 60

echo "Adding testadmin user in Gogs"
# Run script in Gogs container to add Git admin user
$KUBECTL_CMD exec $GOGS_POD_NAME -- /tmp/adduser.sh
if [ $? -ne 0 ]; then
    echo "failed to add testadmin user"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

$KUBECTL_CMD get route gogs-svc -n default -o yaml

# Create a test Git repository. This creates a repo named testrepo under user testadmin.
RESPONSE=$(curl -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": "testrepo", "description": "test repo", "private": false}' --write-out %{http_code} --silent --output /dev/null https://${GIT_HOSTNAME}/api/v1/admin/users/testadmin/repos --insecure)
if [ $? -ne 0 ]; then
    echo "failed to create testrepo"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo "RESPONSE = ${RESPONSE}"

if [ ${RESPONSE} -eq 500 ] || [ ${RESPONSE} -eq 501 ] || [ ${RESPONSE} -eq 502 ] || [ ${RESPONSE} -eq 503 ] || [ ${RESPONSE} -eq 504 ]; then
    echo "Gog server error ${RESPONSE}"

    DESC_POD=`$KUBECTL_CMD describe pod $GOGS_POD_NAME`
    echo "$DESC_POD"

    $KUBECTL_CMD logs $GOGS_POD_NAME -n default
    echo

    sleep 300

    echo "trying to create testrepo again after 5 minute sleep"
    RESPONSE2=$(curl -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": "testrepo", "description": "test repo", "private": false}' --write-out %{http_code} --silent --output /dev/null https://${GIT_HOSTNAME}/api/v1/admin/users/testadmin/repos --insecure)
    if [ $? -ne 0 ]; then
        echo "failed to create testrepo"
        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi

    if [ ${RESPONSE2} -eq 500 ] || [ ${RESPONSE2} -eq 501 ] || [ ${RESPONSE2} -eq 502 ] || [ ${RESPONSE2} -eq 503 ] || [ ${RESPONSE2} -eq 504 ]; then
        echo "failed to create testrepo again"

        DESC_POD=`$KUBECTL_CMD describe pod $GOGS_POD_NAME`
        echo "$DESC_POD"

        $KUBECTL_CMD logs $GOGS_POD_NAME -n default
        echo

        echo "E2E CANARY TEST - EXIT WITH ERROR"
        exit 1
    fi
fi

# Populate the repo with test data
mkdir testrepo
cd testrepo
git init
git config --global user.email "testadmin@redhat.com"
git config --global user.name "testadmin"
git config http.sslVerify "false"
cp -r ../repoContents/* .
git add .
git commit -m "first commit"
git push https://testadmin:testadmin@${GIT_HOSTNAME}/testadmin/testrepo.git --all
if [ $? -ne 0 ]; then
    echo "failed to push to testrepo Git repository"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

cd ..

# Inject the real Git hostname into certificate config files
sed -i -e "s/__HOSTNAME__/$GIT_HOSTNAME/" ca.conf
sed -i -e "s/__HOSTNAME__/$GIT_HOSTNAME/" san.ext

# Generate certificates
openssl genrsa -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.crt -config ca.conf
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr -config ca.conf
openssl x509 -req -in server.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out server.crt -days 500 -sha256 -extfile san.ext
if [ $? -ne 0 ]; then
    echo "failed to create a self-signed certificate"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Recreate Gogs route with the generated self-signed certificates
$KUBECTL_CMD delete route gogs-svc -n default
if [ $? -ne 0 ]; then
    echo "failed to delete Gogs route"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

$KUBECTL_CMD create route edge --service=gogs-svc --cert=server.crt --key=server.key --path=/ -n default
if [ $? -ne 0 ]; then
    echo "failed to create Gogs route with the self-signed certificate"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

$KUBECTL_CMD get route gogs-svc -n default -o yaml

# Generate a channel configmap to contain the root CA certificate
$KUBECTL_CMD create configmap --dry-run git-ca --from-file=caCerts=rootCA.crt --output yaml > $root_dir/tests/e2e-001/git-ca-configmap.yaml
if [ $? -ne 0 ]; then
    echo "failed to create configmap with the self-signed certificate"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

# Inject the real Git hostname into the test input YAML
sed -i -e "s/__HOSTNAME__/$GIT_HOSTNAME/" $root_dir/tests/e2e-001/application.yaml
if [ $? -ne 0 ]; then
    echo "failed to substitute __HOSTNAME__ in application.yaml"
    echo "E2E CANARY TEST - EXIT WITH ERROR"
    exit 1
fi

echo "E2E CANARY TEST - DONE"
exit 0