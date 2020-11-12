module github.com/open-cluster-management/applifecycle-backend-e2e

go 1.15

require (
	github.com/go-logr/logr v0.2.1
	github.com/go-logr/zapr v0.2.0
	github.com/onsi/ginkgo v1.12.1
	github.com/onsi/gomega v1.10.1
	github.com/open-cluster-management/multicloud-operators-channel v1.0.1-0.20200930214554-fa55cf642642
	github.com/open-cluster-management/multicloud-operators-deployable v0.0.0-20200925154205-fc4ec3e30a4d
	github.com/open-cluster-management/multicloud-operators-placementrule v1.0.1-2020-06-08-14-28-27.0.20201013190828-d760a392d21d
	github.com/open-cluster-management/multicloud-operators-subscription v1.0.0-2020-05-12-21-17-19.0.20201021204840-fdc45ae83e25
	github.com/pkg/errors v0.9.1
	github.com/spf13/pflag v1.0.5
	go.uber.org/zap v1.14.1
	k8s.io/api v0.18.6
	k8s.io/apiextensions-apiserver v0.18.6
	k8s.io/apimachinery v0.18.8
	k8s.io/client-go v13.0.0+incompatible
	sigs.k8s.io/controller-runtime v0.6.2
	sigs.k8s.io/kind v0.9.0 // indirect
)

replace k8s.io/client-go => k8s.io/client-go v0.18.2
