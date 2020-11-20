module github.com/open-cluster-management/applifecycle-backend-e2e

go 1.15

require (
	github.com/MakeNowJust/heredoc v0.0.0-20171113091838-e9091a26100e // indirect
	github.com/Masterminds/semver v1.5.0 // indirect
	github.com/cameront/go-jsonpatch v0.0.0-20180223123257-a8710867776e // indirect
	github.com/docker/spdystream v0.0.0-20181023171402-6480d4af844c // indirect
	github.com/emicklei/go-restful v2.11.1+incompatible // indirect
	github.com/go-logr/logr v0.3.0
	github.com/go-logr/zapr v0.3.0
	github.com/google/go-cmp v0.5.1 // indirect
	github.com/google/go-github/v32 v32.1.0 // indirect
	github.com/johannesboyne/gofakes3 v0.0.0-20200218152459-de0855a40bc1 // indirect
	github.com/onsi/ginkgo v1.12.1
	github.com/onsi/gomega v1.10.1
	github.com/open-cluster-management/ansiblejob-go-lib v0.1.12 // indirect
	github.com/open-cluster-management/multicloud-operators-channel v1.0.1-0.20201120143200-e505a259de45
	github.com/open-cluster-management/multicloud-operators-deployable v0.0.0-20201119200129-dcb15e7afa3f
	github.com/open-cluster-management/multicloud-operators-placementrule v1.0.1-2020-06-08-14-28-27.0.20201118195339-05a8c4c89c12
	github.com/open-cluster-management/multicloud-operators-subscription v0.0.2-pre
	github.com/pkg/errors v0.9.1
	github.com/sabhiram/go-gitignore v0.0.0-20180611051255-d3107576ba94 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
	github.com/xeipuuv/gojsonpointer v0.0.0-20190905194746-02993c407bfb // indirect
	go.uber.org/zap v1.14.1
	golang.org/x/net v0.0.0-20200822124328-c89045814202 // indirect
	golang.org/x/oauth2 v0.0.0-20200107190931-bf48bf16ab8d // indirect
	k8s.io/api v0.19.3
	k8s.io/apiextensions-apiserver v0.19.3
	k8s.io/apimachinery v0.19.3
	k8s.io/client-go v12.0.0+incompatible
	k8s.io/helm v2.17.0+incompatible // indirect
	sigs.k8s.io/controller-runtime v0.6.3
	sigs.k8s.io/kind v0.9.0 // indirect
	sigs.k8s.io/kustomize/api v0.6.0 // indirect
)

replace (
	github.com/open-cluster-management/multicloud-operators-channel => github.com/open-cluster-management/multicloud-operators-channel v0.2.2-pre
	github.com/open-cluster-management/multicloud-operators-deployable => github.com/open-cluster-management/multicloud-operators-deployable v0.2.2-pre
	github.com/open-cluster-management/multicloud-operators-subscription => github.com/open-cluster-management/multicloud-operators-subscription v0.2.2-pre
	github.com/open-cluster-management/multicloud-operators-subscription-release => github.com/open-cluster-management/multicloud-operators-subscription-release v0.2.2-pre
	k8s.io/client-go => k8s.io/client-go v0.19.3
)
