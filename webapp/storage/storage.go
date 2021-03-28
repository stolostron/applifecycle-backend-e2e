package storage

import (
	"embed"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

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
		str := filepath.Base(p)
		rp := "testdata"
		if str != "." {
			rp = str
		}
		return &store{fsName: "os", embedFS: embedStore, rootPath: rp, fs: os.DirFS(filepath.Dir(p))}
	}

	return &store{fsName: "embed.FS", embedFS: embedStore, rootPath: "testdata", fs: embedStore}
}

func (e *store) ReadFile(filename string) ([]byte, error) {
	if e.fsName == "os" {
		return os.ReadFile(filename)
	}

	return e.embedFS.ReadFile(filename)
}

func (e *store) LoadTestCases() (pkg.TestCasesReg, error) {
	out := pkg.TestCasesReg{}
	wFunc := func(path string, d fs.DirEntry, err error) error {
		if d.IsDir() {
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

	if err := fs.WalkDir(e.fs, fmt.Sprintf("%s/testcases", e.rootPath), wFunc); err != nil {
		return out, err
	}

	return out, nil
}

func (e *store) LoadExpectations() (pkg.ExpctationReg, error) {
	out := pkg.ExpctationReg{}

	wFunc := func(path string, d fs.DirEntry, err error) error {
		if d.IsDir() {
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

	if err := fs.WalkDir(e.fs, fmt.Sprintf("%s/expectations", e.rootPath), wFunc); err != nil {
		return out, err
	}

	return out, nil
}

func (e *store) LoadStages() (pkg.StageReg, error) {
	out := pkg.StageReg{}
	wFunc := func(path string, d fs.DirEntry, err error) error {
		if d.IsDir() {
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

	if err := fs.WalkDir(e.fs, fmt.Sprintf("%s/stages", e.rootPath), wFunc); err != nil {
		return out, err
	}

	return out, nil
}
