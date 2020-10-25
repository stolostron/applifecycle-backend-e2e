# Image URL to use all building/pushing image targets;
# Use your own docker registry and image name for dev/test by overridding the IMG and REGISTRY environment variable.
IMG ?= $(shell cat COMPONENT_NAME 2> /dev/null)
REGISTRY ?= quay.io/open-cluster-management

# Github host to use for checking the source tree;
# Override this variable ue with your own value if you're working on forked repo.
GIT_HOST ?= github.com/open-cluster-management

PWD := $(shell pwd)
BASE_DIR := $(shell basename $(PWD))

# Keep an existing GOPATH, make a private one if it is undefined
GOPATH_DEFAULT := $(PWD)/.go
export GOPATH ?= $(GOPATH_DEFAULT)
GOBIN_DEFAULT := $(GOPATH)/bin

export GOBIN ?= $(GOBIN_DEFAULT)
TESTARGS_DEFAULT := "-v"

export TESTARGS ?= $(TESTARGS_DEFAULT)
DEST ?= $(GOPATH)/src/$(GIT_HOST)/$(BASE_DIR)
VERSION ?= $(shell cat COMPONENT_VERSION 2> /dev/null)
IMAGE_NAME_AND_VERSION ?= $(REGISTRY)/$(IMG)

LOCAL_OS := $(shell uname)
ifeq ($(LOCAL_OS),Linux)
    TARGET_OS ?= linux
    XARGS_FLAGS="-r"
else ifeq ($(LOCAL_OS),Darwin)
    TARGET_OS ?= darwin
    XARGS_FLAGS=
else
    $(error "This system's OS $(LOCAL_OS) isn't recognized/supported")
endif


# GITHUB_USER containing '@' char must be escaped with '%40'
GITHUB_USER := $(shell echo $(GITHUB_USER) | sed 's/@/%40/g')
GITHUB_TOKEN ?=

BUILD_GOOS=${GOOS:-linux}


build:
	@GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o bin

local:
	@GOOS=darwin go build -o bin

build-images:
	@docker build -t $(IMG) .

run: build build-images
	docker run -p 8765:8765 --env CONFIG="/e2etest/" --name e2e -d --rm applifecycle-backend-e2e


tag:
	@docker tag $(IMG) $(REGISTRY)/$(IMG):latest

publish:
	docker login ${COMPONENT_DOCKER_REPO} -u ${DOCKER_USER} -p ${DOCKER_PASS}
	docker push $(REGISTRY)/$(IMG):latest
	@echo "Pushed the following image: $(REGISTRY)/$(IMG):latest"

## Simple target running a kubectl command to ensure the cluster is up and running
## Environment variables are not always recognized by Makefiles, so it's recommended to use the --kubeconfig flag
test-integration:
	echo $(KUBECONFIG)
	kubectl get pods -A --kubeconfig KUBECONFIG


############################################################
# clean section
############################################################
clean::
	rm -f build/$(IMG)
