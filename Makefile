# Image URL to use all building/pushing image targets;
# Use your own docker registry and image name for dev/test by overridding the IMG and REGISTRY environment variable.
IMG ?= $(shell cat COMPONENT_NAME 2> /dev/null)
# Build the details for the remote destination repo for the image
REGISTRY ?= quay.io/open-cluster-management

TRAVIS_BUILD_DIR ?= $(shell pwd)

COMPONENT_VERSION ?= $(shell cat COMPONENT_VERSION 2> /dev/null)
export COMPONENT_VERSION
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

# This repo is build in Travis-ci by default;
# Override this variable in local env.
TRAVIS_BUILD ?= 1

# GITHUB_USER containing '@' char must be escaped with '%40'
ifeq ($(TRAVIS_BUILD),1)
	-include $(shell [ -f ".build-harness-bootstrap" ] || curl --fail -sSL -o .build-harness-bootstrap -H "Authorization: token $(GITHUB_TOKEN)" -H "Accept: application/vnd.github.v3.raw" "https://raw.github.com/open-cluster-management/build-harness-extensions/master/templates/Makefile.build-harness-bootstrap"; echo .build-harness-bootstrap)
endif


default::
	@echo "Build Harness Bootstrapped"
	@echo "${TRAVIS_BUILD}"


gobuild:
	@echo "gobuild the test server binary ${GOOS}, ${GOARCH}"
	# create the directory for hosting the go binary
	mkdir -p build/_output/bin
	GOOS=${GOOS} GOARCH=${GOARCH} go build -ldflags="-w -s" -o build/_output/bin/$(IMG)

build-images: gobuild
	@echo "build image ${IMAGE_NAME_AND_VERSION}"
	@docker build -t ${IMAGE_NAME_AND_VERSION} .

APACHE_BASIC_AUTH_IMAGE ?= apache-basic-auth-image
APACHE_BASIC_AUTH_CONTAINER ?= apache-basic-auth-container
export APACHE_BASIC_AUTH_IMAGE
export APACHE_BASIC_AUTH_CONTAINER
build-apache-basic-auth-image:
	docker build -t ${APACHE_BASIC_AUTH_IMAGE} -f apache-basic-auth/Dockerfile .

boot-apache-basic-auth-service: build-apache-basic-auth-image
	docker run -d --name ${APACHE_BASIC_AUTH_CONTAINER}  -p 8080:8080 ${APACHE_BASIC_AUTH_IMAGE}

export CONTAINER_NAME=$(shell echo "e2e")
run: build-images
	kind get kubeconfig > default-kubeconfigs/hub
	docker rm -f ${CONTAINER_NAME} || true
	docker run -p 8765:8765 --name ${CONTAINER_NAME} -d --rm ${IMAGE_NAME_AND_VERSION}:latest sleep 300
	sleep 10
	curl http://localhost:8765/clusters | head -n 10
	curl http://localhost:8765/testcases | head -n 10
	curl http://localhost:8765/expectations | head -n 10

kind-setup:
	kind get kubeconfig > default-kubeconfigs/hub
	kubectl config use-context kind-kind

e2e: gobuild
	build/run-e2e-tests.sh

tag: build-images
	docker tag ${IMAGE_NAME_AND_VERSION}:latest ${IMAGE_NAME_AND_VERSION}:${COMPONENT_VERSION}${COMPONENT_TAG_EXTENSION}
	docker tag ${IMAGE_NAME_AND_VERSION}:latest ${IMAGE_NAME_AND_VERSION}:canary
	@echo "tagged images are:"
	docker images

push: tag
	docker login ${REGISTRY} -u ${DOCKER_USER} -p ${DOCKER_PASS}
	docker push ${IMAGE_NAME_AND_VERSION}:${COMPONENT_VERSION}${COMPONENT_TAG_EXTENSION}
	@echo "Pushed the following image: ${IMAGE_NAME_AND_VERSION}:${COMPONENT_VERSION}${COMPONENT_TAG_EXTENSION}"
	docker push ${IMAGE_NAME_AND_VERSION}:canary
	@echo "Pushed the following image: ${IMAGE_NAME_AND_VERSION}:canary"

############################################################
# clean section
############################################################
clean::
	rm -f build/$(IMG)
	docker stop ${APACHE_BASIC_AUTH_CONTAINER}
	docker rm ${APACHE_BASIC_AUTH_CONTAINER}

gen:
	@echo "generate the default test data for binary"
	go generate ./...
