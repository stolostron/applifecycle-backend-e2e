package handler

import (
	"fmt"
	"net/http"
	"time"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg/e2e"
)

func (s *Processor) ReloadStageReg() {
	s.mux.Lock()
	newSt, err := e2e.LoadStages(s.dataDir)
	if err != nil {
		return
	}

	s.stages = newSt

	s.mux.Unlock()
}

func (s *Processor) StageRunnerHandler(w http.ResponseWriter, r *http.Request) {
	ID := r.URL.Query().Get("id")
	w.Header().Set("Content-Type", "application/json")

	tr := &TResponse{
		TestID: ID,
		Name:   "test case list",
		Status: Succeed,
	}

	if ID == "" {
		tr.Details = s.stages
		tr.Error = fmt.Errorf("stage group ID is not defined, checkout details for avaliable stages").Error()
		tr.Status = Fialed
		fmt.Fprint(w, tr.String())
		return
	}

	rsp := s.Run(ID, 10*time.Second, s.DefaultRunner, s.DefaultChecker, s.DefaultCleaner)
}

func (s *Processor) DisplayStagesHandler(w http.ResponseWriter, r *http.Request) {
	s.ReloadStageReg()

	ID := r.URL.Query().Get("id")
	w.Header().Set("Content-Type", "application/json")

	tr := &TResponse{
		TestID: ID,
		Name:   "test case list",
		Status: Succeed,
	}

	if ID == "" {
		tr.Details = s.stages
		fmt.Fprint(w, tr.String())

		return
	}

	c, ok := s.stages[ID]
	if !ok {
		tr.Status = Fialed
		tr.Error = fmt.Errorf("ID (%s) doesn't exist", ID).Error()

		fmt.Fprint(w, tr.String())
		return
	}

	tr.Details = c

	fmt.Fprint(w, tr.String())

	return
}

type runner func(id string, caseReg e2e.TestCasesReg) (AppliedCase, error)
type checker func(id string, timeout time.Duration, expReg e2e.ExpctationReg) (*TResponse, error)
type cleaner func(AppliedCase)

// we can provide a stage endpoint
// each stage will link to a test unit run the stage in numeric order, if any
// stage failed the will fail the test

func (st *Processor) Run(groupID string, timeout time.Duration, run runner, check checker, clean cleaner) *TResponse {
	a := []AppliedCase{}

	out := &TResponse{}
	defer func() {
		for _, c := range a {
			clean(c)
		}
	}()

	out.Name = fmt.Sprintf("run stage group %s", groupID)

	for _, s := range st.stages[groupID] {
		applied, rerr := run(s.CaseID, st.testCases)
		if rerr != nil {
			out.Error = rerr.Error()
			return out
		}

		a = append(a, applied)

		rsp, err := check(s.CaseID, timeout, st.expectations)

		if s.Clean == "true" {
			clean(applied)
		}

		if err != nil {
			rsp.Error = err.Error()
			rsp.Status = Fialed
			return rsp
		}
	}

	out.Status = Succeed

	return out
}

func (s *Processor) DefaultRunner(testID string, tc e2e.TestCasesReg) (AppliedCase, error) {
	out := AppliedCase{}

	c := tc[testID]

	cUnit, ok := s.configs[c.TargetCluster]
	if !ok {
		err := fmt.Errorf("unregister cluster name: (%s)", c.TargetCluster)
		return out, err
	}

	kCfg := cUnit.CfgDir
	if kerr := processResource(c.URL, kCfg, Apply); kerr != nil {
		err := fmt.Errorf("failed to apply test case %s, resource %s on cluster %s, err: %v", testID, c.Desc, c.TargetCluster, kerr)
		return out, err
	}

	s.logger.V(DebugLevel).Info(fmt.Sprintf("applyed %s of test case %s on cluster %s", c.Desc, testID, c.TargetCluster))

	out.Cfg = kCfg
	out.Tc = c

	return out, nil
}

func (s *Processor) DefaultChecker(testID string, timeout time.Duration, expReg e2e.ExpctationReg) (*TResponse, error) {
	ticker := time.NewTicker(pullInterval)
	scale := timeout / pullInterval
	timeOut := time.After(pullInterval * scale)

timoutLoop:
	for {
		select {
		case <-ticker.C:
			rsp, err := s.dispatchExpectation(testID, s.expectations[testID])
			if err == nil {
				return rsp, err
			}

			s.logger.Error(err, "faild")
		case <-timeOut:
			break timoutLoop
		}
	}

	out := "failed to successfully check all the expectations due to timeout"
	return &TResponse{TestID: testID, Status: Fialed, Error: out}, nil
}

func (s *Processor) DefaultCleaner(applied AppliedCase) {
	if err := processResource(applied.Tc.URL, applied.Cfg, Delete); err != nil {
		s.logger.Error(err, fmt.Sprintf("failed to delete applied resource %s on cluster %s",
			applied.Tc.Desc, applied.Tc.TargetCluster))
	}

	s.logger.Info(fmt.Sprintf("successfully deleted resource %s on cluster %s", applied.Tc.Desc, applied.Tc.TargetCluster))

	return
}
