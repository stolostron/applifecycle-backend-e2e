package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("e2e-git-subscription-test", func() {
	It("sub-003", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-003") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("sub-004", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-004") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
})
