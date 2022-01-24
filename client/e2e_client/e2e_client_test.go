package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("helmrelease-test", func() {
	It("release-001", func() {
		Eventually(func() error { return DefaultRunner.Run("release-001") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
})

var _ = Describe("channel-test", func() {
	It("chn-001", func() {
		Eventually(func() error { return DefaultRunner.Run("chn-001") }, 5*pullInterval, pullInterval).Should(Succeed())
	})

	It("chn-002", func() {
		Eventually(func() error { return DefaultRunner.Run("chn-002") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
})

var _ = Describe("subscription-test", func() {
	It("sub-001", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-001") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("sub-002", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-002") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
})
