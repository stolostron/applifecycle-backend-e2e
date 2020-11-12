package e2e

type Stage struct {
	groupID string `json:"groupid"`
	order   int    `json:"run_order"`
	caseID  string `json:"case_id"`
	clean   string `json:"clean"`
}

type Stages []Stage

type runner func(id string, tCases TestCasesReg) (rCase TestCase, err error)
type cleaner func(tCase TestCase)
type checker func(id string, exps ExpctationReg) error

type StageReg struct {
	group   map[string]Stages
	caseReg TestCasesReg
	expReg  ExpctationReg
}

// we can provide a stage endpoint
// each stage will link to a test unit run the stage in numeric order, if any
// stage failed the will fail the test

func (st *StageReg) Run(groupID string, run runner, check checker, clean cleaner) error {
	a := TestCases{}

	defer func() {
		for _, c := range a {
			clean(c)
		}
	}()

	for _, s := range st.group[groupID] {
		applied, rerr := run(s.caseID, st.caseReg)
		if rerr != nil {
			return rerr
		}

		a = append(a, applied)

		err := check(s.caseID, st.expReg)

		if s.clean == "true" {
			clean(applied)
		}

		if err != nil {
			return err
		}
	}

	return nil
}
