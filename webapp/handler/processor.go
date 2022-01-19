package handler

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/go-logr/logr"
	"github.com/stolostron/applifecycle-backend-e2e/pkg"

	gerr "github.com/pkg/errors"
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
	configs      pkg.KubeConfigs
	testCases    pkg.TestCasesReg
	expectations pkg.ExpctationReg
	stages       pkg.StageReg
	getMatcher   func(string) pkg.Matcher
	logger       logr.Logger
	set          map[string]struct{}
}

type Storage interface {
	LoadTestCases() (pkg.TestCasesReg, error)
	LoadExpectations() (pkg.ExpctationReg, error)
	LoadStages() (pkg.StageReg, error)
}

func NewProcessor(cfgDir string, timeout int, storage Storage, logger logr.Logger) (*Processor, error) {
	var err error

	cfg, err := pkg.LoadKubeConfigs(cfgDir)
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load kubeconfig")
	}

	tCases, err := storage.LoadTestCases()
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load test case")
	}

	exps, err := storage.LoadExpectations()
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load expectations")
	}

	stages, err := storage.LoadStages()
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load test case")
	}

	return &Processor{
		mux:          &sync.Mutex{},
		timeout:      time.Duration(timeout) * time.Second,
		cfgDir:       cfgDir,
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
