package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/handler"
	"k8s.io/klog/v2/klogr"
)

const (
	defaultPort = ":8765"
)

func main() {
	logger := klogr.New()
	s, err := handler.NewTSever("./e2etest/", logger)
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
