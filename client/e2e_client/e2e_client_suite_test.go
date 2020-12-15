package client_test

import (
	"fmt"
	"log"
	"net/http"
	"os"
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
	//empty dataDir means test will use the compiled binary data for test
	defaultDataDir = ""
	logLvl         = 1
	testTimeout    = 30
	pullInterval   = 3 * time.Second
	evnKubeConfig  = "KUBE_DIR"
)

var (
	//this will be depend on the caller's location
	cfgDir = "../../default-kubeconfigs"
)

func TestAppLifecycle_API_E2E(t *testing.T) {
	RegisterFailHandler(Fail)

	RunSpecsWithDefaultAndCustomReporters(t,
		"Applifecycle-API-Test",
		[]Reporter{printer.NewlineReporter{}, reporters.NewJUnitReporter(JUnitResult)})
}

var DefaultRunner = clt.NewRunner(defaultAddr, "/run")

var _ = BeforeSuite(func(done Done) {
	By("bootstrapping test environment")

	envDir, _ := os.LookupEnv(evnKubeConfig)
	if envDir != "" {
		fmt.Fprintf(os.Stdout, "using ENV var KUBE_DIR (%s) to get kubeconfigs\n", envDir)
		cfgDir = envDir
	}

	srv := server.NewServer(defaultAddr, cfgDir, defaultDataDir, logLvl, testTimeout)

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}

		fmt.Println("test server started")
	}()

	Eventually(func() error {
		return clt.IsSeverUp(defaultAddr, "/clusters")
	}, StartTimeout, pullInterval)

	close(done)
}, StartTimeout)

var _ = AfterSuite(func() {
	By("tearing down the test environment")
	gexec.KillAndWait(3 * time.Second)
})
