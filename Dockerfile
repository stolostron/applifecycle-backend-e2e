# Start from a Debian image with the latest version of Go installed
# and a workspace (GOPATH) configured at /go.
FROM golang

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin

# Copy the local package files to the container's workspace.
COPY ./bin/applifecycle-backend-e2e /go/bin/applifecycle-backend-e2e
COPY ./e2etest /e2etest

# Run the outyet command by default when the container starts.
ENTRYPOINT /go/bin/applifecycle-backend-e2e

# Document that the service listens on port 8765.
EXPOSE 8765
