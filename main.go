package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/handler"
	"k8s.io/klog/v2/klogr"
)

const (
	defaultPort    = ":8765"
	defaultCfgDir  = "default-kubeconfigs"
	defaultDataDir = "default-e2e-test-data"

	CONFIG_PATH = "CONFIGS"
	DATA_PATH   = "E2E_DATA"
)

var LogLevel int

func init() {
	flag.IntVar(
		&LogLevel,
		"v",
		1,
		"The interval of housekeeping in seconds.",
	)
}

func main() {
	flag.Parse()

	logger := klogr.New().V(LogLevel)
	cfgPath := os.Getenv(CONFIG_PATH)
	if cfgPath == "" {
		logger.Error(fmt.Errorf("failed to get the default dir ENV %s", CONFIG_PATH), fmt.Sprintf("will use default %s", defaultCfgDir))
		cfgPath = defaultCfgDir
	}

	dataPath := os.Getenv(DATA_PATH)
	if dataPath == "" {
		logger.Error(fmt.Errorf("failed to get the default dir ENV %s", DATA_PATH), fmt.Sprintf("will use default %s", defaultDataDir))
		dataPath = defaultDataDir
	}

	s, err := handler.NewTSever(cfgPath, dataPath, logger)
	if err != nil {
		log.Fatal(fmt.Sprintf("failed to create test sever, err: %v", err))
	}

	http.HandleFunc("/run", s.TestCasesRunnerHandler)
	http.HandleFunc("/result", s.ExpectationCheckerHandler)
	http.HandleFunc("/cluster", s.DisplayClusterHandler)
	http.HandleFunc("/testcase", s.DisplayTestCasesHandler)
	http.HandleFunc("/expectation", s.DisplayExpectationHandler)

	log.Fatal(http.ListenAndServe(defaultPort, nil))
}
