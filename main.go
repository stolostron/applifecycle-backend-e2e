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
	defaultPort = ":8765"
	defaultDir  = "CONFIG"
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
	dPath := os.Getenv(defaultDir)
	if dPath == "" {
		log.Fatal(fmt.Errorf("failed to get the default dir ENV %s", defaultDir))
	}

	s, err := handler.NewTSever(dPath, logger)
	if err != nil {
		log.Fatal(fmt.Sprintf("failed to create test sever, err: %w", err))
	}

	http.HandleFunc("/run", s.TestCasesRunnerHandler)
	http.HandleFunc("/result", s.ExpectationCheckerHandler)
	http.HandleFunc("/cluster", s.DisplayClusterHandler)
	http.HandleFunc("/testcase", s.DisplayTestCasesHandler)
	http.HandleFunc("/expectation", s.DisplayExpectationHandler)

	log.Fatal(http.ListenAndServe(defaultPort, nil))
}
