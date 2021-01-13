package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/server"
)

const (
	defaultAddr = "localhost:8765"
	//this will be depend on the caller's location
	defaultCfgDir  = "kubeconfigs"
	defaultDataDir = ""

	CONFIG_PATH = "CONFIGS"
	DATA_PATH   = "E2E_DATA"
)

var LogLevel int
var configPath string
var dataPath string
var timeout int

func init() {
	flag.IntVar(
		&LogLevel,
		"v",
		1,
		"log level",
	)

	flag.IntVar(
		&timeout,
		"t",
		45,
		"timeout for running each expectation unit",
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
		"the path to testdata files",
	)

	flag.Parse()
}

func main() {
	srv := server.NewServer(defaultAddr, configPath, dataPath, LogLevel, timeout)

	done := make(chan os.Signal, 1)
	signal.Notify(done, os.Interrupt, syscall.SIGINT, syscall.SIGTERM)

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
