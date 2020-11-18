# Start from a Debian image with the latest version of Go installed
# and a workspace (GOPATH) configured at /go.
FROM golang

# Copy the local package files to the container's workspace.
COPY build/_output/bin/applifecycle-backend-e2e /go/bin/applifecycle-backend-e2e

# Copy default data to the binary level in the container
COPY default-kubeconfigs default-kubeconfigs
COPY default-e2e-test-data default-e2e-test-data

RUN git clone https://github.com/open-cluster-management/applifecycle-backend-e2e.git /opt/e2e

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin


ENTRYPOINT /go/bin/applifecycle-backend-e2e

# Document that the service listens on port 8765.
EXPOSE 8765
