package handler

import (
	"bytes"
	"fmt"
	"net/http"
	"os/exec"
	"time"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg/e2e"
)

type ocCommand string

const (
	Apply  ocCommand = "apply"
	Delete ocCommand = "delete"
)

type appliedCase struct {
	tc  e2e.TestCase
	cfg string
}

func (s *Processor) applyTestCases(testID string, tc e2e.TestCases) ([]appliedCase, error) {
	applied := []appliedCase{}
	for _, c := range tc {
		cUnit, ok := s.configs[c.TargetCluster]
		if !ok {
			err := fmt.Errorf("unregister cluster name: (%s)", c.TargetCluster)
			return applied, err
		}

		kCfg := cUnit.CfgDir
		if kerr := processResource(c.URL, kCfg, Apply); kerr != nil {
			err := fmt.Errorf("failed to apply test case %s, resource %s on cluster %s, err: %v", testID, c.Desc, c.TargetCluster, kerr)
			return applied, err
		}

		applied = append(applied, appliedCase{tc: c, cfg: kCfg})

		s.logger.V(DebugLevel).Info(fmt.Sprintf("applyed %s of test case %s on cluster %s", c.Desc, testID, c.TargetCluster))
	}

	return applied, nil
}

func processResource(tURL, kCfgDir string, subCmd ocCommand) error {
	var cmd *exec.Cmd
	switch subCmd {
	case Apply:
		cmd = exec.Command("kubectl", "apply", "-f", tURL, "--kubeconfig", kCfgDir)
	case Delete:
		cmd = exec.Command("kubectl", "delete", "-f", tURL, "--kubeconfig", kCfgDir)
	}

	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return err
	}

	return nil
}

func (s *Processor) TestCasesRunnerHandler(w http.ResponseWriter, r *http.Request) {
	testID := r.URL.Query().Get("id")

	s.logger.V(0).Info(fmt.Sprintf("Start running %s", testID))

	w.Header().Set("Content-Type", "application/json")

	tr := &TResponse{
		TestID: testID,
		Name:   fmt.Sprintf("run test case id (%s)", testID),
	}

	var err error

	defer func() {
		if err != nil {
			s.logger.Error(err, "failed on running test")
		}
		s.logger.V(0).Info(fmt.Sprintf("DONE servering %s!", testID))
	}()

	if testID == "" {
		tr.Status = Unknown
		err = fmt.Errorf("unknow id (%s)", testID)
		tr.Error = err.Error()

		fmt.Fprint(w, tr.String())

		return
	}

	//make sure unique id is running
	_, ok := s.set[testID]
	if ok {
		tr.Status = Fialed
		tr.Details = fmt.Sprintf("the request test case (%s) is running", testID)
		fmt.Fprint(w, tr.String())

		return
	}

	s.set[testID] = struct{}{}

	c, ok := s.testCases[testID]
	if !ok {
		tr.Status = Fialed
		err = fmt.Errorf("ID (%s) doesn't exist", testID)
		tr.Error = err.Error()

		fmt.Fprint(w, tr.String())

		return
	}

	applied, err := s.applyTestCases(testID, c)
	defer s.cleanUp(testID, applied)

	if err != nil {
		tr.Status = Fialed
		tr.Error = err.Error()
		return
	}

	tr = s.continuousCheck(testID)

	fmt.Fprint(w, tr.String())

	return
}

func (s *Processor) continuousCheck(testID string) *TResponse {
	ticker := time.NewTicker(pullInterval)
	timeOut := time.After(pullInterval * 3)

timoutLoop:
	for {
		select {
		case <-ticker.C:
			rsp, err := s.dispatchExpectation(testID, s.expectations[testID])
			if err == nil {
				return rsp
			}

			s.logger.Error(err, "faild")
		case <-timeOut:
			break timoutLoop
		}
	}

	out := "failed to successfully check all the expectations due to timeout"
	return &TResponse{TestID: testID, Status: Fialed, Error: out}
}

func (s *Processor) cleanUp(testID string, applied []appliedCase) {
	if applied != nil {
		for _, e := range applied {
			if err := processResource(e.tc.URL, e.cfg, Delete); err != nil {
				s.logger.Error(err, fmt.Sprintf("failed to delete applied resource %s on cluster %s",
					e.tc.Desc, e.tc.TargetCluster))
			}

			s.logger.Info(fmt.Sprintf("successfully deleted resource %s on cluster %s", e.tc.Desc, e.tc.TargetCluster))
		}
	}

	delete(s.set, testID)

	return
}

func (s *Processor) ReloadTestCaseReg() {
	s.mux.Lock()
	newTc, err := e2e.LoadTestCases(s.dataDir)
	if err != nil {
		return
	}

	s.testCases = newTc

	s.mux.Unlock()
}

func (s *Processor) DisplayTestCasesHandler(w http.ResponseWriter, r *http.Request) {
	s.ReloadTestCaseReg()

	testID := r.URL.Query().Get("id")
	w.Header().Set("Content-Type", "application/json")

	tr := &TResponse{
		TestID: testID,
		Name:   "test case list",
		Status: Succeed,
	}

	if testID == "" {
		tr.Details = s.testCases
		fmt.Fprint(w, tr.String())

		return
	}

	c, ok := s.testCases[testID]
	if !ok {
		tr.Status = Fialed
		tr.Error = fmt.Errorf("ID (%s) doesn't exist", testID).Error()

		fmt.Fprint(w, tr.String())
		return
	}

	tr.Details = c

	fmt.Fprint(w, tr.String())

	return
}
