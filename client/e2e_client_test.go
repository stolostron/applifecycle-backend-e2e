package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("helmrelease-test", func() {
	It("release-001", func() {
		Eventually(DefaultRunner.Run("release-001"), 5*pullInterval, pullInterval).Should(Succeed())
	})
})

var _ = Describe("channel-test", func() {
	It("chn-003", func() {
		Eventually(DefaultRunner.Run("chn-003"), 5*pullInterval, pullInterval).Should(Succeed())
	})
})

var _ = Describe("subscription-test", func() {
	It("sub-001", func() {
		Eventually(DefaultRunner.Run("sub-001"), 5*pullInterval, pullInterval).Should(Succeed())
	})
})
