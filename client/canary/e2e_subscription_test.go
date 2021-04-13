package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("e2e-git-subscription-test", func() {
	It("[P1][Sev1][app-lifecycle] Test subscription with Git release tag", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-003") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("[P1][Sev1][app-lifecycle] Test subscription with Git commit", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-004") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
})
