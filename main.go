package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-logr/zapr"
	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/handler"
	"go.uber.org/zap"
)

const (
	defaultAddr    = "localhost:8765"
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

	zapLog, err := zap.NewDevelopment(zap.AddCaller())
	if err != nil {
		panic(fmt.Sprintf("who watches the watchmen (%v)?", err))
	}

	logger := zapr.NewLogger(zapLog)

	p, err := handler.NewProcessor(configPath, dataPath, logger)
	if err != nil {
		logger.Error(err, "failed to create test sever")
		os.Exit(2)
	}

	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

	// run is used by operators
	http.HandleFunc("/run", p.TestCasesRunnerHandler)
	http.HandleFunc("/run/stage", p.StageRunnerHandler)
	http.HandleFunc("/result", p.ExpectationCheckerHandler)
	http.HandleFunc("/clusters", p.DisplayClusterHandler)
	http.HandleFunc("/testcases", p.DisplayTestCasesHandler)
	http.HandleFunc("/expectations", p.DisplayExpectationHandler)
	http.HandleFunc("/stages", p.DisplayStagesHandler)

	srv := &http.Server{
		Addr: defaultAddr,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	log.Print("Server Started")

	<-done
	log.Print("Server Stopped")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer func() {
		// extra handling here
		cancel()
	}()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server Shutdown Failed:%+v", err)
	}

	log.Print("Server Exited Properly")
}
