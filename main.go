package main

import (
	"context"
	"embed"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/server"
	"github.com/open-cluster-management/applifecycle-backend-e2e/webapp/storage"
)

const (
	defaultAddr = "localhost:8765"
	//this will be depend on the caller's location
	defaultCfgDir  = "default-kubeconfigs"
	defaultDataDir = ""

	CONFIG_PATH = "CONFIGS"
	DATA_PATH   = "E2E_DATA"
)

var LogLevel int
var configPath string
var dataPath string
var timeout int

//go:embed testdata/*
var testData embed.FS

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

type Storage interface {
	LoadTestCases() (pkg.TestCasesReg, error)
	LoadExpectations() (pkg.ExpctationReg, error)
	LoadStages() (pkg.StageReg, error)
}

func main() {
	var store *storage.Store
	if dataPath == "" {
		store = storage.NewStorage(storage.WithEmbedTestData(testData))
	} else {
		store = storage.NewStorage(storage.WithInputTestDataDir(dataPath))
	}
	srv := server.NewServer(defaultAddr, configPath, LogLevel, timeout, store)

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
