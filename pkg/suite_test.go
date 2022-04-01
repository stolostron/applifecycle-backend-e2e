// Package test provides ...
package pkg

import (
	"testing"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	crdapis "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1beta1"
	"k8s.io/client-go/kubernetes/scheme"

	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/envtest"
	"sigs.k8s.io/controller-runtime/pkg/envtest/printer"
	mgr "sigs.k8s.io/controller-runtime/pkg/manager"

	apis "github.com/stolostron/applifecycle-backend-e2e/pkg/subapis"
)

const (
	k8swait      = time.Second * 3
	StartTimeout = 30 // seconds
)

var testEnv = &envtest.Environment{}
var k8sManager mgr.Manager
var k8sClient client.Client

func TestSynchorizerOnSub(t *testing.T) {
	RegisterFailHandler(Fail)

	RunSpecsWithDefaultAndCustomReporters(t,
		"E2E test Suite",
		[]Reporter{printer.NewlineReporter{}})
}

var _ = BeforeSuite(func(done Done) {
	By("bootstrapping test environment")

	// t := true

	// customAPIServerFlags := []string{"--disable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount," +
	// 	"TaintNodesByCondition,Priority,DefaultTolerationSeconds,DefaultStorageClass,StoragebjectInUseProtection," +
	// 	"PersistentVolumeClaimResize,ResourceQuota",
	// }

	// apiServerFlags := append([]string(nil), envtest.DefaultKubeAPIServerFlags...)
	// apiServerFlags = append(apiServerFlags, customAPIServerFlags...)

	// testEnv.KubeAPIServerFlags = apiServerFlags

	cfg, err := testEnv.Start()
	Expect(err).ToNot(HaveOccurred())
	Expect(cfg).ToNot(BeNil())

	Expect(apis.AddToScheme(scheme.Scheme)).Should(Succeed())
	Expect(crdapis.AddToScheme(scheme.Scheme)).Should(Succeed())

	k8sManager, err = mgr.New(cfg, mgr.Options{MetricsBindAddress: "0"})
	Expect(err).ToNot(HaveOccurred())

	go func() {
		err = k8sManager.Start(ctrl.SetupSignalHandler())
		Expect(err).ToNot(HaveOccurred())
	}()

	k8sClient = k8sManager.GetClient()
	Expect(k8sClient).ToNot(BeNil())

	close(done)
}, StartTimeout)

var _ = AfterSuite(func() {
	By("tearing down the test environment")
	gexec.KillAndWait(5 * time.Second)
	err := testEnv.Stop()
	Expect(err).ToNot(HaveOccurred())
})
