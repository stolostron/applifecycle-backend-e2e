package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"

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
var configPath string
var dataPath string

func init() {
	flag.IntVar(
		&LogLevel,
		"v",
		1,
		"The interval of housekeeping in seconds.",
	)

	flag.StringVar(
		&configPath,
		"cfg",
		defaultCfgDir,
		"the path to clusters config files",
	)

	flag.StringVar(
		&dataPath,
		"data",
		defaultDataDir,
		"the path to clusters config files",
	)
}

func main() {
	flag.Parse()

	logger := klogr.New().V(LogLevel)

	s, err := handler.NewTSever(configPath, dataPath, logger)
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
