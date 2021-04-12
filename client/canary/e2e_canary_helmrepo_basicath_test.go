package client_test

import (
	"fmt"
	"os/exec"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("RHACM4K-2350: e2e-server", func() {
	It("[P1][Sev1][app-life-cycle] Test subscribing to Helm repo with basic authentication", func() {
		Eventually(
			func() error {
				cmd := exec.Command("/bin/sh", "./scripts/helmrepo_basicath.sh")

				out, err := cmd.CombinedOutput()

				fmt.Printf("Combined Output:\n%s\n", string(out))

				if err != nil {
					fmt.Printf("error: %s\n", err)
					if exitError, ok := err.(*exec.ExitError); ok {
						fmt.Printf("exit code: %d\n", exitError.ExitCode())
					}
					return err
				}
				return nil
			}).Should(Succeed())
	})
})
