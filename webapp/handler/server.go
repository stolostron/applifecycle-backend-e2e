package handler

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/go-logr/logr"
	gerr "github.com/pkg/errors"
	"github.com/stolostron/applifecycle-backend-e2e/pkg"
	"github.com/stolostron/applifecycle-backend-e2e/webapp/storage"
)

const (
	defaultPort  = ":8765"
	Unknown      = "unknown"
	Succeed      = "succeed"
	Failed       = "failed"
	InfoLevel    = 0
	DebugLevel   = 1
	pullInterval = time.Second * 10
)

type Processor struct {
	mux     *sync.Mutex
	timeout time.Duration
	// the config directory flag
	cfgDir       string
	dataDir      string
	configs      pkg.KubeConfigs
	testCases    pkg.TestCasesReg
	expectations pkg.ExpctationReg
	stages       pkg.StageReg
	getMatcher   func(string) pkg.Matcher
	logger       logr.Logger
	set          map[string]struct{}
}

func NewProcessor(cfgDir, dataDir string, timeout int, logger logr.Logger) (*Processor, error) {
	var err error

	cfg, err := pkg.LoadKubeConfigs(cfgDir)
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load kubeconfig")
	}

	tCases := pkg.TestCasesReg{}
	exps := pkg.ExpctationReg{}
	stages := pkg.StageReg{}

	//dataDir should have folders for testcases, expectations, and stages
	if dataDir == "" {
		tCases, err = storage.LoadTestCases()
		if err != nil {
			return nil, gerr.Wrap(err, "failed to load test case")
		}

		exps, err = storage.LoadExpectations()
		if err != nil {
			return nil, gerr.Wrap(err, "failed to load expectations")
		}

		stages, err = storage.LoadStages()
		if err != nil {
			return nil, gerr.Wrap(err, "failed to load test case")
		}
	} else {
		tCases, err = pkg.LoadTestCases(dataDir)
		if err != nil {
			return nil, gerr.Wrap(err, "failed to load test case")
		}

		exps = pkg.ExpctationReg{}
		exps, err = exps.Load(dataDir)
		if err != nil {
			return nil, gerr.Wrap(err, "failed to load expectations")
		}

		stages, err = pkg.LoadStages(dataDir)
		if err != nil {
			return nil, gerr.Wrap(err, "failed to load test case")
		}
	}

	return &Processor{
		mux:          &sync.Mutex{},
		timeout:      time.Duration(timeout) * time.Second,
		cfgDir:       cfgDir,
		dataDir:      dataDir,
		configs:      cfg,
		testCases:    tCases,
		expectations: exps,
		stages:       stages,
		getMatcher:   pkg.MatcherRouter,
		logger:       logger,
		set:          map[string]struct{}{},
	}, nil
}

type TResponse struct {
	TestID  string      `json:"test_id"`
	Name    string      `json:"name"`
	Status  string      `json:"run_status"`
	Error   string      `json:"error"`
	Details interface{} `json:"details"`
}

func (tr *TResponse) String() string {
	o, err := json.MarshalIndent(tr, "", "\t")
	if err != nil {
		return ""
	}

	return string(o)
}
