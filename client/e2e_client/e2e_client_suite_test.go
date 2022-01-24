package client_test

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"testing"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	clt "github.com/stolostron/applifecycle-backend-e2e/client"
	"github.com/stolostron/applifecycle-backend-e2e/webapp/server"
	"sigs.k8s.io/controller-runtime/pkg/envtest/printer"
)

const (
	suiteTimeout = 60 // seconds
	defaultAddr  = "localhost:8765"
	//empty dataDir means test will use the compiled binary data for test
	defaultDataDir = ""
	logLvl         = 1
	testTimeout    = 90
	pullInterval   = 3 * time.Second
	evnKubeConfig  = "KUBE_DIR"
)

var (
	//this will be depend on the caller's location
	cfgDir = "../../kubeconfigs"
)

func TestAppLifecycle_API_E2E(t *testing.T) {
	RegisterFailHandler(Fail)

	RunSpecsWithDefaultAndCustomReporters(t,
		"Applifecycle-API-Test",
		[]Reporter{printer.NewlineReporter{}})
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
	}, suiteTimeout, pullInterval)

	close(done)
}, suiteTimeout)

var _ = AfterSuite(func() {
	By("tearing down the test environment")
	gexec.KillAndWait(3 * time.Second)
})
