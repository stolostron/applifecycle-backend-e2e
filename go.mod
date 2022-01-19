module github.com/stolostron/applifecycle-backend-e2e

go 1.16

require (
	github.com/go-cmd/cmd v1.3.0
	github.com/go-logr/logr v0.4.0
	github.com/go-logr/zapr v0.4.0
	github.com/onsi/ginkgo v1.16.4
	github.com/onsi/gomega v1.13.0
	github.com/pkg/errors v0.9.1
	go.uber.org/zap v1.17.0
	k8s.io/api v0.21.3
	k8s.io/apiextensions-apiserver v0.21.3
	k8s.io/apimachinery v0.21.3
	k8s.io/client-go v12.0.0+incompatible
	open-cluster-management.io/multicloud-operators-channel v0.5.1-0.20211122200432-da1610291798
	open-cluster-management.io/multicloud-operators-subscription v0.6.0
	sigs.k8s.io/controller-runtime v0.9.1
)

require golang.org/x/crypto v0.0.0-20220112180741-5e0467b6c7ce // indirect

replace k8s.io/client-go => k8s.io/client-go v0.21.3
