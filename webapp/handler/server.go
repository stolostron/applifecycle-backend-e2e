package handler

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/go-logr/logr"
	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg/e2e"
)

const (
	defaultPort  = ":8765"
	Unknown      = "unknown"
	Succeed      = "succeed"
	Fialed       = "failed"
	InfoLevel    = 0
	DebugLevel   = 1
	pullInterval = time.Second * 5
)

type TServer struct {
	mux          *sync.Mutex
	delay        func(time.Duration)
	defaultDir   string
	configs      e2e.KubeConfigs
	testCases    e2e.TestCasesReg
	expectations e2e.ExpctationReg
	getMatcher   func(string) e2e.Matcher
	logger       logr.Logger
	rmux         *sync.Mutex
	set          map[string]struct{}
}

func NewTSever(dir string, logger logr.Logger) (*TServer, error) {
	cfg, err := e2e.LoadKubeConfigs(dir)
	if err != nil {
		return nil, err
	}

	tCases, err := e2e.LoadTestCases(dir)
	if err != nil {
		return nil, err
	}

	exps := e2e.ExpctationReg{}
	exps, err = exps.Load(dir)
	if err != nil {
		return nil, err
	}

	return &TServer{
		mux:          &sync.Mutex{},
		delay:        time.Sleep,
		defaultDir:   dir,
		configs:      cfg,
		testCases:    tCases,
		expectations: exps,
		getMatcher:   e2e.MatcherRouter,
		logger:       logger,
		rmux:         &sync.Mutex{},
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
