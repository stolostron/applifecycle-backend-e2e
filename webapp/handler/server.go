package handler

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/go-logr/logr"
	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg/e2e"
	gerr "github.com/pkg/errors"
)

const (
	defaultPort  = ":8765"
	Unknown      = "unknown"
	Succeed      = "succeed"
	Failed       = "failed"
	InfoLevel    = 0
	DebugLevel   = 1
	pullInterval = time.Second * 5
)

type Processor struct {
	mux          *sync.Mutex
	cfgDir       string
	dataDir      string
	configs      e2e.KubeConfigs
	testCases    e2e.TestCasesReg
	expectations e2e.ExpctationReg
	stages       e2e.StageReg
	getMatcher   func(string) e2e.Matcher
	logger       logr.Logger
	set          map[string]struct{}
}

func NewProcessor(cfgDir, dataDir string, logger logr.Logger) (*Processor, error) {
	cfg, err := e2e.LoadKubeConfigs(cfgDir)
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load kubeconfig")
	}

	tCases, err := e2e.LoadTestCases(dataDir)
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load test case")
	}

	exps := e2e.ExpctationReg{}
	exps, err = exps.Load(dataDir)
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load expectations")
	}

	stages, err := e2e.LoadStages(dataDir)
	if err != nil {
		return nil, gerr.Wrap(err, "failed to load test case")
	}

	return &Processor{
		mux:          &sync.Mutex{},
		cfgDir:       cfgDir,
		dataDir:      dataDir,
		configs:      cfg,
		testCases:    tCases,
		expectations: exps,
		stages:       stages,
		getMatcher:   e2e.MatcherRouter,
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
