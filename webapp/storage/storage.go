package storage

import (
	"embed"
	"fmt"
	"io/fs"
	"os"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

type store struct {
	fsName   string
	rootPath string //this one would be the directory which include, expectations/ stages/ testcases/
	embedFS  embed.FS
	fs       fs.FS
}

func NewStorage(p string, embedStore embed.FS) *store {
	if p != "" {
		return &store{fsName: "os", embedFS: embedStore, rootPath: p, fs: os.DirFS(p)}
	}

	return &store{fsName: "embed.FS", embedFS: embedStore, rootPath: "testdata", fs: embedStore}
}

func (e *store) ReadFile(filename string) ([]byte, error) {
	if e.fsName == "os" {
		return os.ReadFile(filename)
	}

	return e.embedFS.ReadFile(filename)
}

func (e *store) getTestPath() string {
	//	if e.fsName == "os" {
	//		return fmt.Sprintf("testcases")
	//	}

	return fmt.Sprintf("%s/testcases", e.rootPath)
}

func (e *store) getExpectationPath() string {
	//	if e.fsName == "os" {
	//		return fmt.Sprintf("expectations")
	//	}

	return fmt.Sprintf("%s/expectations", e.rootPath)
}

func (e *store) getStagePath() string {
	//	if e.fsName == "os" {
	//		return fmt.Sprintf("stages")
	//	}

	return fmt.Sprintf("%s/stages", e.rootPath)
}

func (e *store) LoadTestCases() (pkg.TestCasesReg, error) {
	out := pkg.TestCasesReg{}
	wFunc := func(path string, d fs.DirEntry, err error) error {
		fmt.Println("izhang >>>>>", path, d)
		if d == nil || d.IsDir() {
			return nil
		}

		b, err := e.ReadFile(path)
		if err != nil {
			return err
		}

		t, err := pkg.BytesToTestCases(b)
		if err != nil {
			return err
		}

		out = pkg.ToTcReg(out, t)

		return nil
	}

	if err := fs.WalkDir(e.fs, e.getTestPath(), wFunc); err != nil {
		return out, err
	}

	return out, nil
}

func (e *store) LoadExpectations() (pkg.ExpctationReg, error) {
	out := pkg.ExpctationReg{}

	wFunc := func(path string, d fs.DirEntry, err error) error {
		if d == nil || d.IsDir() {
			return nil
		}

		b, err := e.ReadFile(path)
		if err != nil {
			return err
		}

		t, err := pkg.BytesToExpectations(b)
		if err != nil {
			return err
		}

		out = pkg.ToExpReg(out, t)

		return nil
	}

	if err := fs.WalkDir(e.fs, e.getExpectationPath(), wFunc); err != nil {
		return out, err
	}

	return out, nil
}

func (e *store) LoadStages() (pkg.StageReg, error) {
	out := pkg.StageReg{}
	wFunc := func(path string, d fs.DirEntry, err error) error {
		if d == nil || d.IsDir() {
			return nil
		}

		b, err := e.ReadFile(path)
		if err != nil {
			return err
		}

		t, err := pkg.BytesToStages(b)
		if err != nil {
			return err
		}

		out = pkg.ToStageReg(out, t)

		return nil
	}

	if err := fs.WalkDir(e.fs, e.getStagePath(), wFunc); err != nil {
		return out, err
	}

	return out, nil
}
