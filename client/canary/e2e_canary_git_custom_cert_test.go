package client_test

import (
	"fmt"
	"os/exec"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("e2e-server", func() {
	It("[P1][Sev1][app-life-cycle] Install test Git repo server with custom certificate", func() {
		Eventually(
			func() error {
				cmd := exec.Command("/bin/sh", "./scripts/gitServer/install.sh")

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
	It("[P1][Sev1][app-life-cycle] Test subscribing to Git repo with custom certificate", func() {
		Eventually(
			func() error {
				cmd := exec.Command("/bin/sh", "./scripts/git_custom_certs.sh")

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
	It("[P1][Sev1][app-life-cycle] Uninstall test Git repo server", func() {
		Eventually(
			func() error {
				cmd := exec.Command("/bin/sh", "./scripts/gitServer/uninstall.sh")

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
