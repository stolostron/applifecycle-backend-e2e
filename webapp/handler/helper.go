package handler

import (
	"fmt"
	"net/http"
)

func (s *Processor) HelperHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	handlers := map[string]string{
		"/run?id=":          "run test case by id",
		"/run/stage?id=":    "run stage by id",
		"/results?id=":      "show results by id",
		"/clusters":         "show all the registered cluster info",
		"/clusters?id=":     "show all the registered cluster info by id",
		"/testcases":        "show all the registered test cases",
		"/testcases?id=":    "show all the registered test case by id",
		"/expectations":     "show all the registered expectations",
		"/expectations?id=": "show all the registered expectation by id",
		"/stages":           "show all the registered stages",
		"/stages?id=":       "show all the registered stage by id",
	}

	tr := &TResponse{
		TestID:  "helper",
		Name:    "registered handler",
		Details: handlers,
	}

	fmt.Fprint(w, tr.String())
	return
}
