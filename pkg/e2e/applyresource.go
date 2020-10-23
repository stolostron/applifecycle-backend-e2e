package e2e

import (
	"fmt"
	"time"

	gerr "github.com/pkg/errors"
	"sigs.k8s.io/controller-runtime/pkg/client"

	tlogr "github.com/go-logr/logr/testing"
)

const (
	//timeOut = time.Minute * 5
	// test
	timeOut = time.Second * 5
	kubectl = "kubectl"
)

type Unit struct {
	// a path where holds the yaml files
	AppPath    string
	ExpectPath string

	// unit map holds all the unit path

	// the expect resource of the given yamls, on hub, the 1 and 2 level
	// resource
	Expectations map[string]Expectation
}

type Units map[string]*Unit

func (u *Unit) String() string {
	return fmt.Sprintf("appPath: %v, expatation %v\n", u.AppPath, u.Expectations)
}

type Report map[string]string

func SopkeAssert(sClt client.Client, units Units) error {
	visited := map[string]bool{}
	entry := time.Now()

	// I guess we can give 5 for the resource to show up
	for time.Now().Sub(entry) < timeOut {
		for n, u := range units {
			if _, ok := visited[n]; ok {
				continue
			}

			if err := assertExpectations(sClt, u.Expectations); err != nil {
				return err
			}

			visited[n] = true
		}
	}

	unChecked := failedExpectations(visited, units)

	if len(unChecked) == 0 {
		return nil
	}

	return gerr.New(fmt.Sprintf("failed units %v\n", unChecked))
}

func failedExpectations(v map[string]bool, u Units) (res []string) {
	for k, _ := range u {
		if _, ok := v[k]; !ok {
			res = append(res, k)
		}
	}

	return res
}

func assertExpectations(sClt client.Client, ep map[string]Expectation) error {
	set := make(map[string]bool)

	//check up expectation entries
	for k, v := range ep {
		if err := checkExpectation(sClt, v); err != nil {
			return gerr.New(fmt.Sprintf("failed assert %v, %v", v, err))
		}

		set[k] = true
	}

	if len(set) != len(ep) {
		return gerr.New("some object is missing")
	}

	return nil
}

func checkExpectation(clt client.Client, ep Expectation) error {
	fn := MatcherRouter(ep.Matcher)
	if fn == nil {
		return gerr.New(fmt.Sprintf("expectation %v failed to find a matcher", ep))
	}

	t := tlogr.TestLogger{}
	return fn.Match(clt, ep, t)
}
