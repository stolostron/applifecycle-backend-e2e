package handler

import (
	"bytes"
	"fmt"
	"net/http"
	"os/exec"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
	gerr "github.com/pkg/errors"
)

type ocCommand string

const (
	Apply  ocCommand = "apply"
	Delete ocCommand = "delete"
)

type AppliedCase struct {
	Tc  pkg.TestCase
	Cfg string
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
		return fmt.Errorf(stderr.String())
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
			err = gerr.Wrap(err, fmt.Sprintf("failed to run test case %s", testID))
			tr.Error = err.Error()
		}

		s.logger.V(0).Info(fmt.Sprintf("DONE servering %s!", testID))

		delete(s.set, testID)

		fmt.Fprint(w, tr.String())
	}()

	if testID == "" {
		tr.Status = Unknown
		err = fmt.Errorf("unknow id (%s)", testID)

		return
	}

	//make sure unique id is running
	_, ok := s.set[testID]
	if ok {
		tr.Status = Failed
		tr.Details = fmt.Sprintf("the request test case (%s) is running", testID)

		return
	}

	s.set[testID] = struct{}{}

	_, ok = s.testCases[testID]
	if !ok {
		tr.Status = Failed
		err = fmt.Errorf("ID (%s) doesn't exist", testID)
		return
	}

	applied, err := s.Run(testID, s.testCases)

	if err != nil {
		tr.Status = Failed
		err = gerr.Wrap(err, "failed to apply test ")
		return
	}

	defer func() {
		//TODO here need to be handle different, might lead to goroutine leak
		go s.Clean(applied)
	}()

	tr, err = s.Check(testID, s.timeout, s.expectations)
	if err != nil {
		err = gerr.Wrap(err, "failed to run checker")
	}

	return
}

func (s *Processor) ReloadTestCaseReg() {
	s.mux.Lock()
	newTc, err := pkg.LoadTestCases(s.dataDir)
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
		tr.Status = Failed
		tr.Error = fmt.Errorf("ID (%s) doesn't exist", testID).Error()

		fmt.Fprint(w, tr.String())
		return
	}

	tr.Details = c

	fmt.Fprint(w, tr.String())

	return
}
