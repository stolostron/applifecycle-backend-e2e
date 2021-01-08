package client_test

import (
	"fmt"
	"os"
	"os/exec"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("App-lifecycle: Install and configure Git server with custom certificate", func() {
	It("git-custom-certs-test", func() {
		cmd := exec.Command("./scripts/gitServer/install.sh")
		stdout, err := cmd.Output()

		fmt.Fprintln(os.Stdout, string(stdout), err.Error())

		Expect(err.Error()).To(BeNil())
	})
})
