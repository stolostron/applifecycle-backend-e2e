//go:generate go run generator.go
package storage

import (
	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

type embedData struct {
	store map[string][]byte
}

// Create new box for embed files
func newEmbedData() *embedData {
	return &embedData{store: make(map[string][]byte)}
}

// Add a file to box
func (e *embedData) Add(file string, content []byte) {
	e.store[file] = content
}

// Get file's content
// Always use / for looking up
// For example: /init/README.md is actually configs/init/README.md
func (e *embedData) Get(file string) []byte {
	if f, ok := e.store[file]; ok {
		return f
	}
	return nil
}

// Find for a file
func (e *embedData) Has(file string) bool {
	if _, ok := e.store[file]; ok {
		return true
	}
	return false
}

// Embed TestCase
var DefaultTestCaseStore = newEmbedData()

func LoadTestCases() (pkg.TestCasesReg, error) {
	out := pkg.TestCasesReg{}
	if len(DefaultTestCaseStore.store) == 0 {
		return out, nil
	}

	for _, b := range DefaultTestCaseStore.store {
		tc, err := pkg.BytesToTestCases(b)
		if err != nil {
			return out, err
		}

		out = pkg.ToTcReg(out, tc)
	}

	return out, nil
}

// Embed Expectation
var DefaultExpectationStore = newEmbedData()

func LoadExpectations() (pkg.ExpctationReg, error) {
	out := pkg.ExpctationReg{}
	if len(DefaultExpectationStore.store) == 0 {
		return out, nil
	}

	for _, b := range DefaultExpectationStore.store {
		tc, err := pkg.BytesToExpectations(b)
		if err != nil {
			return out, err
		}

		out = pkg.ToExpReg(out, tc)
	}

	return out, nil
}

// Embed Stage
var DefaultStageStore = newEmbedData()

func LoadStages() (pkg.StageReg, error) {
	out := pkg.StageReg{}
	if len(DefaultStageStore.store) == 0 {
		return out, nil
	}

	for _, b := range DefaultStageStore.store {
		st, err := pkg.BytesToStages(b)
		if err != nil {
			return out, err
		}

		out = pkg.ToStageReg(out, st)
	}

	return out, nil
}
