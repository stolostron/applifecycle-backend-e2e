package e2e

import (
	"encoding/json"
	"fmt"
	"io/ioutil"

	gerr "github.com/pkg/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/types"
)

const (
	expDirSuffix      = "expectations"
	testCaseDirSuffix = "testcases"
)

//TestCase contains an id and a ULR pointing to it's raw content
type TestCase struct {
	CaseID        string `json:"test_id"`
	Desc          string `json:"desc"`
	URL           string `json:"url"`
	TargetCluster string `json:"target_cluster"`
}

type TestCases []TestCase

type TestCasesReg map[string]TestCases

func LoadTestCases(dir string) (TestCasesReg, error) {
	tDir := fmt.Sprintf("%s%s", dir, testCaseDirSuffix)
	files, err := ioutil.ReadDir(tDir)

	if err != nil {
		return TestCasesReg{}, err
	}

	out := TestCasesReg{}
	for _, file := range files {
		p := fmt.Sprintf("%s/%s", tDir, file.Name())
		c, err := ioutil.ReadFile(p)
		if err != nil {
			return out, gerr.Wrap(err, "failed to load test cases")
		}

		tc := &TestCases{}
		err = json.Unmarshal(c, tc)
		if err != nil {
			return out, gerr.Wrap(err, "failed to load test cases")
		}

		for _, t := range *tc {
			out[t.CaseID] = append(out[t.CaseID], t)
		}
	}

	return out, nil
}

type Expectation struct {
	TestID        string            `json:"test_id"`
	TargetCluster string            `json:"target_cluster"`
	Desc          string            `json:"desc"`
	APIVersion    string            `json:"apiversion"`
	Kind          string            `json:"kind"`
	Name          string            `json:"name"`
	Namepsace     string            `json:"namespace"`
	Matcher       string            `json:"matcher"`
	Args          map[string]string `json:"args"`
}

func (e *Expectation) String() string {
	return fmt.Sprintf("id %s, desc %s, on cluster %s, kind %s, resource %s/%s\n",
		e.TestID, e.Desc, e.TargetCluster, e.Kind, e.Namepsace, e.Name)
}

type Expectations []Expectation

type ExpctationReg map[string]Expectations

func parseExpectations(in []byte) (*Expectations, error) {
	exps := &Expectations{}
	if err := json.Unmarshal(in, exps); err != nil {
		return exps, err
	}

	return exps, nil
}

func (e ExpctationReg) Load(dir string) (ExpctationReg, error) {
	tDir := fmt.Sprintf("%s%s", dir, expDirSuffix)
	files, err := ioutil.ReadDir(tDir)

	if err != nil {
		return ExpctationReg{}, err
	}

	out := ExpctationReg{}
	for _, file := range files {
		p := fmt.Sprintf("%s/%s", tDir, file.Name())
		c, err := ioutil.ReadFile(p)
		if err != nil {
			return out, gerr.Wrap(err, "failed to load expectations")
		}

		exps, err := parseExpectations(c)
		if err != nil {
			return out, err
		}

		for _, e := range *exps {
			out[e.TestID] = append(out[e.TestID], e)
		}
	}

	return out, nil
}

func (e Expectation) GetInstance() *unstructured.Unstructured {
	ins := &unstructured.Unstructured{}
	ins.SetAPIVersion(e.APIVersion)
	ins.SetKind(e.Kind)
	ins.SetName(e.Name)
	if e.Namepsace == "" {
		e.Namepsace = "default"
	}

	ins.SetNamespace(e.Namepsace)

	return ins
}

func (e Expectation) GetInstanceList() *unstructured.UnstructuredList {
	ins := &unstructured.UnstructuredList{}
	ins.SetAPIVersion(e.APIVersion)
	ins.SetKind(e.Kind)

	return ins
}

func (e Expectation) GetKey() types.NamespacedName {
	if e.Namepsace == "" {
		e.Namepsace = "default"
	}

	return types.NamespacedName{Name: e.Name, Namespace: e.Namepsace}
}

func (e Expectation) IsEqual(b Expectation) bool {
	if e.APIVersion != b.APIVersion {
		return false
	}

	if e.Kind != b.Kind {
		return false
	}

	if e.Name != b.Name {
		return false
	}

	if e.Namepsace != b.Namepsace {
		return false
	}

	if e.Matcher != b.Matcher {
		return false
	}

	return true
}
