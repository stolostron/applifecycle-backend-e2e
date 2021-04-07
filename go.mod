module github.com/open-cluster-management/applifecycle-backend-e2e

go 1.16

require (
	github.com/go-logr/logr v0.3.0
	github.com/go-logr/zapr v0.3.0
	github.com/onsi/ginkgo v1.12.1
	github.com/onsi/gomega v1.10.1
	github.com/open-cluster-management/multicloud-operators-channel v1.2.2-2-20201130-37b47
	github.com/open-cluster-management/multicloud-operators-deployable v1.2.2-2-20201130-7bc3c
	github.com/open-cluster-management/multicloud-operators-placementrule v1.2.2-2-20201130-98cfd
	github.com/open-cluster-management/multicloud-operators-subscription v1.2.3-1-20210407-9f32325
	github.com/pkg/errors v0.9.1
	go.uber.org/zap v1.14.1
	k8s.io/api v0.20.2
	k8s.io/apiextensions-apiserver v0.20.2
	k8s.io/apimachinery v0.20.2
	k8s.io/client-go v12.0.0+incompatible
	sigs.k8s.io/controller-runtime v0.6.3
)

replace (
	github.com/docker/distribution => github.com/docker/distribution v0.0.0-20191216044856-a8371794149d
	github.com/docker/docker => github.com/moby/moby v17.12.0-ce-rc1.0.20200618181300-9dc6525e6118+incompatible
	k8s.io/client-go => k8s.io/client-go v0.19.3
)
