module github.com/open-cluster-management/applifecycle-backend-e2e

go 1.15

require (
	github.com/go-logr/logr v0.3.0
	github.com/go-logr/zapr v0.3.0
	github.com/onsi/ginkgo v1.12.1
	github.com/onsi/gomega v1.10.1
	github.com/open-cluster-management/multicloud-operators-channel v1.0.1-0.20201120143200-e505a259de45
	github.com/open-cluster-management/multicloud-operators-deployable v0.2.2-pre
	github.com/open-cluster-management/multicloud-operators-placementrule v1.0.1-2020-06-08-14-28-27.0.20201118195339-05a8c4c89c12
	github.com/open-cluster-management/multicloud-operators-subscription v0.2.2-pre
	github.com/pkg/errors v0.9.1
	go.uber.org/zap v1.14.1
	gopkg.in/yaml.v3 v3.0.0-20200615113413-eeeca48fe776 // indirect
	k8s.io/api v0.19.3
	k8s.io/apiextensions-apiserver v0.19.3
	k8s.io/apimachinery v0.19.3
	k8s.io/client-go v12.0.0+incompatible
	sigs.k8s.io/controller-runtime v0.6.3
)

replace (
	github.com/open-cluster-management/multicloud-operators-channel => github.com/open-cluster-management/multicloud-operators-channel v0.2.2-pre
	github.com/open-cluster-management/multicloud-operators-placementrule => github.com/open-cluster-management/multicloud-operators-placementrule v0.2.2-pre
	k8s.io/client-go => k8s.io/client-go v0.19.3
)
