package client_test

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	clt "github.com/stolostron/applifecycle-backend-e2e/client"
	"github.com/stolostron/applifecycle-backend-e2e/webapp/server"
	"github.com/stolostron/applifecycle-backend-e2e/webapp/storage"
	"sigs.k8s.io/controller-runtime/pkg/envtest/printer"
)

const (
	StartTimeout = 60 // seconds
	JUnitDir     = "./results"
	JUnitName    = "app-backend-e2e.xml"
	defaultAddr  = "localhost:8765"
	//empty dataDir means test will use the compiled binary data for test
	defaultDataDir = "../../testdata"
	logLvl         = 1
	testTimeout    = 30
	pullInterval   = 3 * time.Second
	evnKubeConfig  = "KUBE_DIR"
)

var (
	//this will be depended on the caller's location
	cfgDir = "../../default-kubeconfigs"
)

func TestAppLifecycle_API_E2E(t *testing.T) {
	RegisterFailHandler(Fail)

	resultDest := filepath.Join(JUnitDir, JUnitName)

	RunSpecsWithDefaultAndCustomReporters(t,
		"Applifecycle-API-Test",
		[]Reporter{printer.NewlineReporter{}, reporters.NewJUnitReporter(resultDest)})
}

var DefaultRunner = clt.NewRunner(defaultAddr, "/run")

var _ = BeforeSuite(func(done Done) {
	By("bootstrapping test environment")

	envDir, _ := os.LookupEnv(evnKubeConfig)
	if envDir != "" {
		fmt.Fprintf(os.Stdout, "using ENV var KUBE_DIR (%s) to get kubeconfigs\n", envDir)
		cfgDir = envDir
	}

	store := storage.NewStorage(storage.WithInputTestDataDir(defaultDataDir))
	srv := server.NewServer(defaultAddr, cfgDir, logLvl, testTimeout, store)
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}

		fmt.Fprintln(os.Stdout, "test server started")
	}()

	Eventually(func() error {
		return clt.IsSeverUp(defaultAddr, "/clusters")
	}, StartTimeout, pullInterval)

	close(done)
}, StartTimeout)

var _ = AfterSuite(func() {
	fmt.Fprintln(os.Stdout, "tear down the test server")
	gexec.KillAndWait(3 * time.Second)
})
