package handler

import (
	"fmt"
	"net/http"
	"time"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
	gerr "github.com/pkg/errors"
)

func (s *Processor) ReloadStageReg() {
	s.mux.Lock()
	newSt, err := pkg.LoadStages(s.dataDir)
	if err != nil {
		return
	}

	s.stages = newSt

	s.mux.Unlock()
}

type StageRunner interface {
	Run(id string, caseReg pkg.TestCasesReg) (AppliedCase, error)
	Check(id string, timeout time.Duration, expReg pkg.ExpctationReg) (*TResponse, error)
	Clean(AppliedCase) error
}

var _ StageRunner = (*Processor)(nil)

func (s *Processor) StageRunnerHandler(w http.ResponseWriter, r *http.Request) {

	ID := r.URL.Query().Get("id")
	w.Header().Set("Content-Type", "application/json")

	s.logger.Info(fmt.Sprintf("Start stage runner on %s", ID))
	defer s.logger.Info(fmt.Sprintf("Done stage runner on %s", ID))

	tr := &TResponse{
		TestID: ID,
		Name:   "test case list",
		Status: Succeed,
	}

	if ID == "" {
		tr.Details = s.stages
		tr.Error = fmt.Errorf("stage group ID is not defined, checkout details for avaliable stages").Error()
		tr.Status = Failed

		fmt.Fprint(w, tr.String())
		return
	}

	out := s.RunStage(ID, s.timeout, s)

	tr.Error = out.Error
	tr.Name = out.Name
	tr.Details = out.Details
	tr.Status = out.Status

	fmt.Fprint(w, tr.String())
}

func (s *Processor) DisplayStagesHandler(w http.ResponseWriter, r *http.Request) {
	s.ReloadStageReg()

	ID := r.URL.Query().Get("id")
	s.logger.Info(fmt.Sprintf("Start display stages testID (%s)", ID))
	defer s.logger.Info(fmt.Sprintf("Done display stages testID (%s)", ID))

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
		tr.Status = Failed
		tr.Error = fmt.Errorf("ID (%s) doesn't exist", ID).Error()

		fmt.Fprint(w, tr.String())
		return
	}

	tr.Details = c

	fmt.Fprint(w, tr.String())

	return
}

// we can provide a stage endpoint
// each stage will link to a test unit run the stage in numeric order, if any
// stage failed the will fail the test

func (st *Processor) RunStage(groupID string, timeout time.Duration, sRunner StageRunner) *TResponse {
	a := []AppliedCase{}

	out := &TResponse{}
	defer func() {
		for _, c := range a {
			sRunner.Clean(c)
		}
	}()

	out.Name = fmt.Sprintf("run stage group %s", groupID)

	for _, s := range st.stages[groupID] {
		applied, rerr := sRunner.Run(s.CaseID, st.testCases)
		if rerr != nil {
			out.Error = rerr.Error()
			return out
		}

		a = append(a, applied)

		rsp, err := sRunner.Check(s.CaseID, timeout, st.expectations)

		if s.Clean == "true" {
			err = sRunner.Clean(applied)
		}

		if err != nil {
			rsp.Error = err.Error()
			rsp.Status = Failed
			return rsp
		}
	}

	out.Status = Succeed

	return out
}

func (s *Processor) Run(testID string, tc pkg.TestCasesReg) (AppliedCase, error) {
	out := AppliedCase{}

	c := tc[testID]

	cUnit, ok := s.configs[c.TargetCluster]
	if !ok {
		err := fmt.Errorf("unregister cluster name: (%s)", c.TargetCluster)
		return out, err
	}

	kCfg := cUnit.CfgDir
	if kerr := processResource(c.URL, kCfg, Apply); kerr != nil {
		err := fmt.Errorf("failed to apply resource %s on cluster %s, \n err: %+v", c.Desc, c.TargetCluster, kerr.Error())
		return out, err
	}

	s.logger.Info(fmt.Sprintf("applyed %s of test case %s on cluster %s", c.URL, testID, c.TargetCluster))

	out.Cfg = kCfg
	out.Tc = c

	return out, nil
}

func (s *Processor) Check(testID string, timeout time.Duration, expReg pkg.ExpctationReg) (*TResponse, error) {
	ticker := time.NewTicker(pullInterval)
	timeOut := time.After(timeout)

	out := "failed to  check all the expectations due to timeout"

	for {
		select {
		case <-ticker.C:
			rsp, err := s.dispatchExpectation(testID, s.expectations[testID])
			if err == nil {
				return rsp, nil
			}

			s.logger.Error(err, "faild")
		case <-timeOut:
			return &TResponse{TestID: testID, Status: Failed, Error: out}, fmt.Errorf(out)
		}
	}

	return &TResponse{}, fmt.Errorf(out)
}

func (s *Processor) Clean(applied AppliedCase) error {
	if err := processResource(applied.Tc.URL, applied.Cfg, Delete); err != nil {
		return gerr.Wrap(err, fmt.Sprintf("failed to delete applied resource %s on cluster %s",
			applied.Tc.Desc, applied.Tc.TargetCluster))
	}

	s.logger.Info(fmt.Sprintf("successfully deleted resource %s on cluster %s", applied.Tc.Desc, applied.Tc.TargetCluster))

	return nil
}
