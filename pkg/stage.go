package pkg

import (
	"encoding/json"
	"fmt"
	"io/ioutil"

	gerr "github.com/pkg/errors"
)

type Stage struct {
	ID     string `json:"id"`
	Order  int    `json:"run_order"`
	CaseID string `json:"case_id"`
	Clean  string `json:"clean"`
}

type Stages []Stage

type StageReg map[string]Stages

func LoadStages(dir string) (StageReg, error) {
	tDir := fmt.Sprintf("%s/%s", dir, stagesDirSuffix)
	out := StageReg{}

	files, err := ioutil.ReadDir(tDir)
	if err != nil {
		return out, err
	}

	for _, file := range files {
		p := fmt.Sprintf("%s/%s", tDir, file.Name())

		c, err := ioutil.ReadFile(p)
		if err != nil {
			return out, gerr.Wrapf(err, "failed to load test cases at file %s", p)
		}

		st := &Stages{}
		err = json.Unmarshal(c, st)
		if err != nil {
			return out, gerr.Wrap(err, "failed to load test cases")
		}

		for _, t := range *st {
			out[t.ID] = append(out[t.ID], t)
		}
	}

	return out, nil
}
