package client_test

import (
	"log"
	"net/http"
	"testing"
	"time"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	clt "github.com/open-cluster-management/applifecycle-backend-e2e/client"
	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/server"
	"sigs.k8s.io/controller-runtime/pkg/envtest/printer"
)

const (
	StartTimeout = 60 // seconds
	JUnitResult  = "results"
	defaultAddr  = "localhost:8765"
	//this will be depend on the caller's location
	defaultCfgDir  = "../default-kubeconfigs"
	defaultDataDir = "../default-e2e-test-data"
	logLvl         = 1
	testTimeout    = 30
)

func TestAppLifecycleAPI_E2E(t *testing.T) {
	RegisterFailHandler(Fail)

	RunSpecsWithDefaultAndCustomReporters(t,
		"Applifecycle-API-Test",
		[]Reporter{printer.NewlineReporter{}, reporters.NewJUnitReporter(JUnitResult)})
}

var DefaultRunner = &clt.Runner{}

var _ = BeforeSuite(func(done Done) {
	By("bootstrapping test environment")

	srv := server.NewServer(defaultAddr, defaultCfgDir, defaultDataDir, logLvl, testTimeout)

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	Eventually(func() error {
		return clt.IsSeverUp(defaultAddr, "/clusters")
	}, StartTimeout, 3*time.Second)

	DefaultRunner.Addr = defaultAddr
	DefaultRunner.Endpoint = "/run"

	close(done)
}, StartTimeout)

var _ = AfterSuite(func() {
	By("tearing down the test environment")
	gexec.KillAndWait(5 * time.Second)
})
