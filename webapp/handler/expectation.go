package handler

import (
	"fmt"
	"net/http"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

func (s *Processor) dispatchExpectation(testID string, exps pkg.Expectations) (*TResponse, error) {
	s.logger.Info(fmt.Sprintf("running test id %s", testID))

	tr := &TResponse{
		TestID: testID,
		Name:   "checked expectations",
	}

	var err error

	out := pkg.Expectations{}

	defer func() {
		tr.Details = out
	}()

	for _, e := range exps {
		s.logger.V(DebugLevel).Info(fmt.Sprintf("running test id %s, expectation %s", testID, e.Desc))

		cName := e.TargetCluster
		cUnit, ok := s.configs[cName]
		if !ok {
			err = fmt.Errorf("unregister cluster name: (%s)", cName)
			tr.Error = err.Error()
			tr.Status = Failed

			return tr, err
		}

		mName := e.Matcher
		matcher := s.getMatcher(mName)
		if matcher == nil {
			err := fmt.Errorf("unregister matcher: (%s)", mName)
			tr.Status = Failed
			tr.Error = err.Error()
			return tr, err
		}

		if nerr := matcher.Match(cUnit.Clt, e, s.logger); nerr != nil {
			tr.Status = Failed
			tr.Error = nerr.Error()

			return tr, nerr
		}

		out = append(out, e)
	}

	tr.Status = Succeed
	return tr, err
}

func (s *Processor) ExpectationCheckerHandler(w http.ResponseWriter, r *http.Request) {
	// make sure we can dynamically change the expectations records when the
	// endpoint is called
	tr := &TResponse{
		TestID: "",
		Name:   "list registered expectation",
	}

	s.mux.Lock()
	newExps, err := s.expectations.Load(s.dataDir)
	if err != nil {
		tr.Status = Failed
		tr.Error = fmt.Errorf("failed reload the expectations").Error()

		fmt.Fprint(w, tr.String())
		return
	}

	s.expectations = newExps

	s.mux.Unlock()

	testID := r.URL.Query().Get("id")

	s.logger.Info(fmt.Sprintf("Start checking test ID %s", testID))
	defer s.logger.Info(fmt.Sprintf("Done checking test ID %s", testID))

	defer w.Header().Set("Content-Type", "application/json")

	exps, ok := s.expectations[testID]

	if !ok {
		tr.Status = Failed
		tr.Error = fmt.Errorf("ID (%s) doesn't exist", testID).Error()
		fmt.Fprint(w, tr.String())
		return
	}

	tr, err = s.dispatchExpectation(testID, exps)
	if err == nil {
		tr.Status = Succeed
	} else {
		tr.Status = Failed
		tr.Error = err.Error()
	}

	fmt.Fprint(w, tr.String())

	return
}

func (s *Processor) DisplayExpectationHandler(w http.ResponseWriter, r *http.Request) {
	tr := &TResponse{Name: "expectations list"}

	testID := r.URL.Query().Get("id")
	s.logger.Info(fmt.Sprintf("Start display expectations testID (%s)", testID))
	defer s.logger.Info(fmt.Sprintf("Done display expectations testID (%s)", testID))

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
