# Start from a Debian image with the latest version of Go installed
# and a workspace (GOPATH) configured at /go.
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

RUN  microdnf update -y \
        && rpm -e --nodeps tzdata \
        && microdnf install tzdata \
        && microdnf install git \
        && microdnf install openssh-clients \
        && microdnf install golang \
        && microdnf install curl \
        && microdnf install tar \
        && microdnf clean all

ENV USER_UID=1001 \
    USER_NAME=app-backend \
    ZONEINFO=/usr/share/timezone


RUN git clone -b v0.1.8 --single-branch https://github.com/open-cluster-management/applifecycle-backend-e2e.git /opt/e2e

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin


WORKDIR /opt/e2e/client/canary

# the test data is in the binary format
ENTRYPOINT go test -v

# Document that the service listens on port 8765.
EXPOSE 8765
