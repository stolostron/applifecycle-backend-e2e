# Image URL to use all building/pushing image targets;
# Use your own docker registry and image name for dev/test by overridding the IMG and REGISTRY environment variable.
IMG ?= $(shell cat COMPONENT_NAME 2> /dev/null)
# Build the details for the remote destination repo for the image
REGISTRY ?= quay.io/open-cluster-management

TRAVIS_BUILD_DIR ?= $(shell pwd)

COMPONENT_VERSION ?= $(shell cat COMPONENT_VERSION 2> /dev/null)

VERSION ?= $(shell cat COMPONENT_VERSION 2> /dev/null)

IMAGE_NAME_AND_VERSION ?= $(REGISTRY)/$(IMG)

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

USE_VENDORIZED_BUILD_HARNESS ?=

ifndef USE_VENDORIZED_BUILD_HARNESS
	ifeq ($(TRAVIS_BUILD),1)
	-include $(shell curl -H 'Authorization: token ${GITHUB_TOKEN}' -H 'Accept: application/vnd.github.v4.raw' -L https://api.github.com/repos/open-cluster-management/build-harness-extensions/contents/templates/Makefile.build-harness-bootstrap -o .build-harness-bootstrap; echo .build-harness-bootstrap)
	endif
else
-include vbh/.build-harness-vendorized
endif

default::
	@echo "Build Harness Bootstrapped"


gobuild:
	@echo "gobuild"
	@echo ${TRAVIS_BUILD_DIR}
	mkdir -p build/_output/bin
	@GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o build/_output/bin/$(IMG)

local:
	@GOOS=darwin go build -o build/_output/bin

build-images:
	@echo "build image"
	@docker build -t ${IMAGE_NAME_AND_VERSION} .

run: gobuild build-images 
	docker run -p 8765:8765 --env CONFIG="/e2etest/" --name e2e -d --rm applifecycle-backend-e2e


tag:
	docker tag ${IMAGE_NAME_AND_VERSION}:latest ${IMAGE_NAME_AND_VERSION}:${COMPONENT_VERSION}${COMPONENT_TAG_EXTENSION}
	docker images

push: tag
	docker login ${REGISTRY} -u ${DOCKER_USER} -p ${DOCKER_PASS}
	docker images
	docker push ${IMAGE_NAME_AND_VERSION}:${COMPONENT_VERSION}${COMPONENT_TAG_EXTENSION}
	@echo "Pushed the following image: $(REGISTRY)/$(IMG):latest"

## Simple target running a kubectl command to ensure the cluster is up and running
## Environment variables are not always recognized by Makefiles, so it's recommended to use the --kubeconfig flag
test-integration:
	kind get kubeconfig > kindconfig
	sleep 30
	kubectl get po -A --kubeconfig kindconfig
	kubectl get ns -A --kubeconfig kindconfig

############################################################
# clean section
############################################################
clean::
	rm -f build/$(IMG)
