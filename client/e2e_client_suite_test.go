package client_test

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"testing"
	"time"

	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/reporters"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/handler"
	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/server"
	"sigs.k8s.io/controller-runtime/pkg/envtest/printer"
)

const (
	StartTimeout = 60 // seconds
	JUnitResult  = "result"
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

func isSeverUp(addr, cluster string) error {
	URL := fmt.Sprintf("%s%s", addr, cluster)
	resp, err := http.Get(URL)

	if err != nil {
		return err
	}

	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("e2e server is not up")
	}

	return nil
}

type Runner struct {
	addr     string
	endpoint string
}

func (r *Runner) run(runID string) error {
	URL := fmt.Sprintf("http://%s%s?id=%s", r.addr, r.endpoint, runID)
	resp, err := http.Get(URL)

	if err != nil {
		return err
	}

	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		bodyBytes, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return err
		}

		res := &handler.TResponse{}

		if err := json.Unmarshal(bodyBytes, res); err != nil {
			return err
		}

		if res.Status != handler.Succeed {
			return fmt.Errorf("failed test on %s, with status %s err: %s", res.TestID, res.Status, res.Status)
		}

		return nil
	}

	return fmt.Errorf("incorrect response code %v", resp.StatusCode)
}

var DefaultRunner = &Runner{}

var _ = BeforeSuite(func(done Done) {
	By("bootstrapping test environment")

	srv := server.NewServer(defaultAddr, defaultCfgDir, defaultDataDir, logLvl, testTimeout)

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	Eventually(func() error {
		return isSeverUp(defaultAddr, "/clusters")
	}, StartTimeout, 3*time.Second)

	DefaultRunner.addr = defaultAddr
	DefaultRunner.endpoint = "/run"

	close(done)
}, StartTimeout)

var _ = AfterSuite(func() {
	By("tearing down the test environment")
	gexec.KillAndWait(5 * time.Second)
})
