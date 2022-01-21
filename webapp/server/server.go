package server

import (
	"fmt"
	"net/http"
	"os"

	"github.com/go-logr/zapr"
	"github.com/stolostron/applifecycle-backend-e2e/webapp/handler"
	"go.uber.org/zap"
)

func NewServer(addr, cfg string, lvl, timeout int, storage handler.Storage) *http.Server {
	zapLog, err := zap.NewDevelopment()
	if err != nil {
		panic(fmt.Sprintf("who watches the watchmen (%v)?", err))
	}

	logger := zapr.NewLogger(zapLog)

	p, err := handler.NewProcessor(cfg, timeout, storage, logger)
	if err != nil {
		logger.Error(err, "failed to create test sever")
		os.Exit(2)
	}

	mux := http.NewServeMux()

	// run is used by operators
	mux.HandleFunc("/run", p.CasesRunnerHandler)
	mux.HandleFunc("/help", p.HelperHandler)
	mux.HandleFunc("/run/stage", p.StageRunnerHandler)
	mux.HandleFunc("/results", p.ExpectationCheckerHandler)
	mux.HandleFunc("/clusters", p.DisplayClusterHandler)
	mux.HandleFunc("/testcases", p.DisplayTestCasesHandler)
	mux.HandleFunc("/expectations", p.DisplayExpectationHandler)
	mux.HandleFunc("/stages", p.DisplayStagesHandler)
	mux.HandleFunc("/", p.HelperHandler)

	return &http.Server{
		Addr:    addr,
		Handler: mux,
	}
}
