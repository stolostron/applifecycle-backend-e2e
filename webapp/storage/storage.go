package storage

import (
	"embed"
	"fmt"
	"io/fs"
	"io/ioutil"
	"os"
	"path/filepath"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

type Store struct {
	fsName   string
	rootPath string //this one would be the directory which include, expectations/ stages/ testcases/
	embedFS  embed.FS
	fs       fs.FS
}

type Option func(*Store)

func NewStorage(opts ...Option) *Store {
	s := &Store{}

	for _, opt := range opts {
		opt(s)
	}

	return s
}

func WithEmbedTestData(embedStore embed.FS) Option {
	// this is the ClientOption function type
	return func(s *Store) {
		s.fsName = "embed.FS"
		s.embedFS = embedStore
		s.rootPath = "testdata"
		s.fs = embedStore
	}
}

func WithInputTestDataDir(path string) Option {
	str := filepath.Base(path)
	rp := "testdata"
	if str != "." {
		rp = str
	}

	return func(s *Store) {
		s.fsName = "os"
		s.rootPath = rp
		parentDir := filepath.Dir(path)
 		s.fs = os.DirFS(parentDir)
	}
}

func (e *Store) ReadFile(filename string) ([]byte, error) {
	if e.fsName == "os" {
		file, err := e.fs.Open(filename)
		if err != nil {
			return []byte{}, err
		}
		return ioutil.ReadAll(file)
	}

	return e.embedFS.ReadFile(filename)
}

func (e *Store) LoadTestCases() (pkg.TestCasesReg, error) {
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

func (e *Store) LoadExpectations() (pkg.ExpctationReg, error) {
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

func (e *Store) LoadStages() (pkg.StageReg, error) {
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
