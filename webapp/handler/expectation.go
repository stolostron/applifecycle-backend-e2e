package handler

import (
	"fmt"
	"net/http"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg/e2e"
)

func (s *TServer) dispatchExpectation(testID string, exps e2e.Expectations) (*TResponse, error) {
	s.logger.Info(fmt.Sprintf("running test id %s", testID))

	for _, e := range exps {
		s.logger.V(DebugLevel).Info(fmt.Sprintf("running test id %s, expectation %s", testID, e.Desc))

		cName := e.TargetCluster
		cUnit, ok := s.configs[cName]
		if !ok {
			err := fmt.Errorf("unregister cluster name: (%s)", cName)
			return &TResponse{TestID: e.TestID, Name: e.Desc,
				Status: Fialed, Error: err.Error()}, err
		}

		mName := e.Matcher
		matcher := s.getMatcher(mName)
		if matcher == nil {
			err := fmt.Errorf("unregister matcher: (%s)", mName)
			return &TResponse{TestID: e.TestID, Name: e.Desc,
				Status: Fialed, Error: err.Error()}, err
		}

		if err := matcher.Match(cUnit.Clt, e, s.logger); err != nil {
			return &TResponse{TestID: e.TestID, Name: e.Desc,
				Status: Fialed, Error: err.Error()}, err
		}
	}

	return &TResponse{
		TestID: testID,
		Status: Succeed,
	}, nil
}

func (s *TServer) ExpectationCheckerHandler(w http.ResponseWriter, r *http.Request) {
	// make sure we can dynamically change the expectations records when the
	// endpoint is called
	tr := &TResponse{
		TestID: "",
		Name:   "list registered expectation",
	}

	s.mux.Lock()
	newExps, err := s.expectations.Load(s.defaultDir)
	if err != nil {
		tr.Status = Fialed
		tr.Error = fmt.Errorf("failed reload the expectations").Error()

		fmt.Fprint(w, tr.String())
		return
	}

	s.expectations = newExps

	s.mux.Unlock()

	testID := r.URL.Query().Get("id")
	w.Header().Set("Content-Type", "application/json")

	exps, ok := s.expectations[testID]

	if !ok {
		tr.Status = Fialed
		tr.Error = fmt.Errorf("ID (%s) doesn't exist", testID).Error()
		fmt.Fprint(w, tr.String())
		return
	}

	tr, err = s.dispatchExpectation(testID, exps)
	if err == nil {
		tr.Status = Succeed
		tr.Details = exps
	} else {
		tr.Status = Fialed
		tr.Error = err.Error()
	}

	fmt.Fprint(w, tr.String())

	return
}

func (s *TServer) ReloadExpectationReg() {
	s.mux.Lock()

	newExps, err := s.expectations.Load(s.defaultDir)
	if err != nil {
		return
	}

	s.expectations = newExps
	s.mux.Unlock()
}

func (s *TServer) DisplayExpectationHandler(w http.ResponseWriter, r *http.Request) {
	s.ReloadExpectationReg()

	tr := &TResponse{Name: "list expectations"}

	testID := r.URL.Query().Get("id")
	w.Header().Set("Content-Type", "application/json")

	if testID == "" {
		tr.Status = Succeed
		tr.Details = s.expectations
		fmt.Fprint(w, tr.String())
		return
	}

	c, ok := s.expectations[testID]
	if !ok {
		tr.Status = Unknown
		tr.Error = fmt.Errorf("ID (%s) doesn't exist", testID).Error()

		fmt.Fprint(w, tr.String())
		return
	}

	tr.Status = Succeed
	tr.Details = c
	fmt.Fprint(w, tr.String())

	return
}
