package handler

import (
	"fmt"
	"net/http"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg/e2e"
)

func (s *Processor) ReloadClusterReg() {
	s.mux.Lock()
	cfgs, err := e2e.LoadKubeConfigs(s.cfgDir)
	if err != nil {
		return
	}

	s.configs = cfgs

	s.mux.Unlock()
}

func (s *Processor) DisplayClusterHandler(w http.ResponseWriter, r *http.Request) {
	s.ReloadClusterReg()

	testID := r.URL.Query().Get("id")
	w.Header().Set("Content-Type", "application/json")

	tr := &TResponse{
		TestID: testID,
		Name:   "kubeconfig list",
		Status: Succeed,
	}

	if testID == "" {
		tr.Details = s.configs
		fmt.Fprint(w, tr.String())
		return
	}

	c, ok := s.configs[testID]

	if !ok {
		tr.Status = Fialed
		tr.Error = fmt.Errorf("ID (%s) doesn't exist", testID).Error()
	}

	tr.Details = c

	fmt.Fprint(w, tr.String())
	return
}
