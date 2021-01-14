package handler

import (
	"bytes"
	"fmt"
	"net/http"
	"os/exec"
	"time"

	"github.com/go-logr/logr"
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

func processResources(urls []string, kCfgDir string, subCmd ocCommand, logger logr.Logger) error {
	for _, url := range urls {
		if err := processResource(url, kCfgDir, subCmd); err != nil {
			return gerr.Wrapf(err, "failed to apply url: %s", url)
		}

		logger.Info(fmt.Sprintf("%s URL %s\n", subCmd, url))
	}

	return nil
}

func (s *Processor) CasesRunnerHandler(w http.ResponseWriter, r *http.Request) {
	testID := r.URL.Query().Get("id")

	s.logger.Info(fmt.Sprintf("Start running %s", testID))
	defer s.logger.Info(fmt.Sprintf("Done running %s", testID))

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
		s.Clean(applied)
		time.Sleep(10 * time.Second)
	}()

	tr, err = s.Check(testID, s.timeout, s.expectations)
	if err != nil {
		err = gerr.Wrap(err, "failed to run checker")
	}

	return
}

func (s *Processor) DisplayTestCasesHandler(w http.ResponseWriter, r *http.Request) {
	testID := r.URL.Query().Get("id")
	s.logger.Info(fmt.Sprintf("Start display testcase testID (%s)", testID))
	defer s.logger.Info(fmt.Sprintf("Done display testcase testID (%s)", testID))

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
