# Start from a Debian image with the latest version of Go installed
# and a workspace (GOPATH) configured at /go.
FROM golang

RUN git clone -b v0.1.7 --single-branch https://github.com/open-cluster-management/applifecycle-backend-e2e.git /opt/e2e

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin


WORKDIR /opt/e2e/client/canary

# the test data is in the binary format
ENTRYPOINT go test -v


# Document that the service listens on port 8765.
EXPOSE 8765
