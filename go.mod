module github.com/stolostron/applifecycle-backend-e2e

go 1.16

require (
	github.com/go-cmd/cmd v1.3.0
	github.com/go-logr/logr v1.2.2
	github.com/go-logr/zapr v1.2.2
	github.com/go-logr/zerologr v1.2.1 // indirect
	github.com/onsi/ginkgo v1.16.5
	github.com/onsi/gomega v1.17.0
	github.com/pkg/errors v0.9.1
	github.com/rs/zerolog v1.26.1 // indirect
	go.uber.org/zap v1.21.0
	k8s.io/api v0.23.3
	k8s.io/apiextensions-apiserver v0.23.3
	k8s.io/apimachinery v0.23.3
	k8s.io/client-go v12.0.0+incompatible
	open-cluster-management.io/multicloud-operators-channel v0.6.1-0.20220211220806-5d96f748742d
	open-cluster-management.io/multicloud-operators-subscription v0.6.1-0.20220214154641-44a704d55402
	sigs.k8s.io/controller-runtime v0.11.0
)

replace k8s.io/client-go => k8s.io/client-go v0.21.3
