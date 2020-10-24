# Start from a Debian image with the latest version of Go installed
# and a workspace (GOPATH) configured at /go.
FROM golang

# Copy the local package files to the container's workspace.
COPY /bin/applifecycle-backend-e2e /go/bin/applifecycle-backend-e2e
COPY /e2etest /e2etest

# Run the outyet command by default when the container starts.
ENTRYPOINT /go/bin/applifecycle-backend-e2e

# Document that the service listens on port 8765.
EXPOSE 8765
