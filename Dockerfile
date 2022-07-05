# Start from a Debian image with the latest version of Go installed
# and a workspace (GOPATH) configured at /go.
FROM  registry.ci.openshift.org/stolostron/builder:go1.18-linux

RUN  yum update -y \
        && yum install openssh-clients \
        && yum install curl \
        && yum install procps \
        && yum install -y nc \
        && yum remove -y python3-urllib3 python38 \
        && yum install tar


ENV USER_UID=1001 \
    USER_NAME=app-backend \
    ZONEINFO=/usr/share/timezone

COPY COMPONENT_VERSION /COMPONENT_VERSION

RUN export VERSION=$(cat /COMPONENT_VERSION); export COMPONENT_VERSION=${VERSION%.0}; git clone -b release-${COMPONENT_VERSION} --single-branch https://github.com/stolostron/applifecycle-backend-e2e.git /opt/e2e

WORKDIR /opt/e2e/client/canary

# the test data is in the binary format
ENTRYPOINT go test -v -timeout 30m

# Document that the service listens on port 8765.
EXPOSE 8765
