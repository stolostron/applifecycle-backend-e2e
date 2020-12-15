package client_test

import (
	"fmt"
	"os"

	. "github.com/onsi/ginkgo"
)

var _ = Describe("e2e-server", func() {
	It("hello-world", func() {
		fmt.Fprintln(os.Stdout, "the applifecycle-backend-e2e is running fine")
		fmt.Fprintln(os.Stdout, ">>>>>hello-world<<<<<")
		fmt.Fprintln(os.Stdout, "the applifecycle-backend-e2e is running fine")
	})
})
