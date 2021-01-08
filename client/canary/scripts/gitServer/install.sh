#!/bin/bash

echo "==== Deploying Gogs Git server with custom certificate ===="

# Find the directory we're in (used to reference other scripts)
my_dir=$(dirname $(readlink -f $0))
# The main directory of canary-scripts
root_dir=$my_dir/../../../..
kubeconfig=/opt/e2e/default-kubeconfigs/hub

KUBECTL_CMD="oc --kubeconfig /opt/e2e/default-kubeconfigs/hub"

# Get the application domain
APP_DOMAIN=`$KUBECTL_CMD -n openshift-console get routes console -o jsonpath='{.status.ingress[0].routerCanonicalHostname}'`
echo "Application domain is $APP_DOMAIN"

GIT_HOSTNAME=gogs-svc-default.$APP_DOMAIN
echo "Git hostname is $GIT_HOSTNAME"

# Inject the real Git hostname into the Gogs deployment YAML
sed -i "s/__HOSTNAME__/$GIT_HOSTNAME/" gogs.yaml

# Deploy Gogs Git server
$KUBECTL_CMD apply -f gogs.yaml

sleep 5

# Get Gogs pod name
GOGS_POD_NAME=`$KUBECTL_CMD get pods -n default -o=custom-columns='DATA:metadata.name' | grep gogs-`
echo "Gogs pod name is $GOGS_POD_NAME"

# Wait for Gogs to be running
FOUND=1
MINUTE=0
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 5min
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for Gogs pod ${GOGS_POD_NAME}."
        echo "List of current pods:"
        $KUBECTL_CMD -n default get pods
        echo
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

# Run script in Gogs container to add Git admin user
$KUBECTL_CMD exec $GOGS_POD_NAME -- /tmp/adduser.sh

# Create a test Git repository. This creates a repo named testrepo under user testadmin.
curl -u testadmin:testadmin -X POST -H "content-type: application/json" -d '{"name": "testrepo", "description": "test repo", "private": false}' https://${GIT_HOSTNAME}/api/v1/admin/users/testadmin/repos --insecure

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
cd ..

# Inject the real Git hostname into certificate config files
sed -i "s/__HOSTNAME__/$GIT_HOSTNAME/" ca.conf
sed -i "s/__HOSTNAME__/$GIT_HOSTNAME/" san.ext

# Generate certificates
openssl genrsa -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.crt -config ca.conf
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr -config ca.conf
openssl x509 -req -in server.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out server.crt -days 500 -sha256 -extfile san.ext

# Recreate Gogs route with the generated self-signed certificates
$KUBECTL_CMD delete route gogs-svc -n default
$KUBECTL_CMD create route edge --service=gogs-svc --cert=server.crt --key=server.key --path=/ -n default

# Generate a configmap to contain the root CA certificate
$KUBECTL_CMD create configmap --dry-run git-ca --from-file=caCerts=rootCA.crt --output yaml > git-ca-configmap.yaml
