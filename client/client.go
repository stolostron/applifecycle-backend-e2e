package client

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	"github.com/stolostron/applifecycle-backend-e2e/webapp/handler"
)

func IsSeverUp(addr, cluster string) error {
	URL := fmt.Sprintf("http://%s%s", addr, cluster)
	resp, err := http.Get(URL)

	if err != nil {
		return err
	}

	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("e2e server is not up")
	}

	return nil
}

type Runner struct {
	Addr     string
	Endpoint string
}

func NewRunner(url, endpoint string) *Runner {
	return &Runner{
		Addr:     url,
		Endpoint: endpoint,
	}
}
func (r *Runner) Run(runID string) error {
	URL := fmt.Sprintf("http://%s%s?id=%s", r.Addr, r.Endpoint, runID)
	resp, err := http.Get(URL)

	if err != nil {
		return err
	}

	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		bodyBytes, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return err
		}

		res := &handler.TResponse{}

		if err := json.Unmarshal(bodyBytes, res); err != nil {
			return err
		}

		if res.Status != handler.Succeed {
			return fmt.Errorf("failed test on %s, with status %s err: %s", res.TestID, res.Status, res.Status)
		}

		return nil
	}

	return fmt.Errorf("incorrect response code %v", resp.StatusCode)
}
