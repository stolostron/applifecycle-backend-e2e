package pkg

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
	stagesDirSuffix   = "stages"
)

//TestCase contains an id and a ULR pointing to it's raw content
type TestCase struct {
	CaseID        string   `json:"test_id"`
	Desc          string   `json:"desc"`
	URLs          []string `json:"urls"`
	TargetCluster string   `json:"target_cluster"`
}

type TestCases []TestCase

type TestCasesReg map[string]TestCase

func BytesToTestCases(b []byte) (*TestCases, error) {
	tc := &TestCases{}
	if err := json.Unmarshal(b, tc); err != nil {
		return tc, gerr.Wrap(err, "failed to load test cases")
	}

	return tc, nil
}

func ToTcReg(in TestCasesReg, tc *TestCases) TestCasesReg {
	for _, t := range *tc {
		in[t.CaseID] = t
	}
	return in
}

func LoadTestCases(dir string) (TestCasesReg, error) {
	tDir := fmt.Sprintf("%s/%s", dir, testCaseDirSuffix)

	files, err := ioutil.ReadDir(tDir)

	if err != nil {
		return TestCasesReg{}, err
	}

	out := TestCasesReg{}
	for _, file := range files {
		p := fmt.Sprintf("%s/%s", tDir, file.Name())

		c, err := ioutil.ReadFile(p)
		if err != nil {
			return out, gerr.Wrapf(err, "failed to load test cases at file %s", p)
		}

		tc, err := BytesToTestCases(c)
		if err != nil {
			return out, gerr.Wrapf(err, "failed to load test cases at file %s", p)
		}

		out = ToTcReg(out, tc)
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
	Namespace     string            `json:"namespace"`
	Matcher       string            `json:"matcher"`
	Args          map[string]string `json:"args"`
}

func (e *Expectation) String() string {
	return fmt.Sprintf("id %s, desc %s, on cluster %s, kind %s, resource %s/%s\n",
		e.TestID, e.Desc, e.TargetCluster, e.Kind, e.Namespace, e.Name)
}

type Expectations []Expectation

type ExpctationReg map[string]Expectations

func BytesToExpectations(in []byte) (*Expectations, error) {
	exps := &Expectations{}
	if err := json.Unmarshal(in, exps); err != nil {
		return exps, err
	}

	return exps, nil
}

func ToExpReg(in ExpctationReg, exps *Expectations) ExpctationReg {
	for _, e := range *exps {
		in[e.TestID] = append(in[e.TestID], e)
	}

	return in
}

func (e Expectation) GetInstance() *unstructured.Unstructured {
	ins := &unstructured.Unstructured{}
	ins.SetAPIVersion(e.APIVersion)
	ins.SetKind(e.Kind)
	ins.SetName(e.Name)
	if e.Namespace == "" {
		e.Namespace = "default"
	}

	ins.SetNamespace(e.Namespace)

	return ins
}

func (e Expectation) GetInstanceList() *unstructured.UnstructuredList {
	ins := &unstructured.UnstructuredList{}
	ins.SetAPIVersion(e.APIVersion)
	ins.SetKind(e.Kind)

	return ins
}

func (e Expectation) GetKey() types.NamespacedName {
	if e.Namespace == "" {
		e.Namespace = "default"
	}

	return types.NamespacedName{Name: e.Name, Namespace: e.Namespace}
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

	if e.Namespace != b.Namespace {
		return false
	}

	if e.Matcher != b.Matcher {
		return false
	}

	return true
}
