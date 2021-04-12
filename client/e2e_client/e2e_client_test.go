package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("helmrelease-test", func() {
	It("RHACM4K-2346", func() {
		Eventually(func() error { return DefaultRunner.Run("RHACM4K-2346") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-1680", func() {
		Eventually(func() error { return DefaultRunner.Run("RHACM4K-1680") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-1701", func() {
		Eventually(func() error { return DefaultRunner.Run("RHACM4K-1701") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-2352", func() {
		Eventually(func() error { return DefaultRunner.Run("RHACM4K-2352") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-2347", func() {
		Eventually(func() error { return DefaultRunner.Run("RHACM4K-2347") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-2570", func() {
		Eventually(func() error { return DefaultRunner.Run("RHACM4K-2570") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-2569", func() {
		Eventually(func() error { return DefaultRunner.Run("RHACM4K-2569") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-2348", func() {
		Eventually(func() error { return StageRunner.Run("RHACM4K-2348") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-1732", func() {
		Eventually(func() error { return StageRunner.Run("RHACM4K-1732") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-2566", func() {
		Eventually(func() error { return StageRunner.Run("RHACM4K-2566") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-2568", func() {
		Eventually(func() error { return StageRunner.Run("RHACM4K-2568") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("RHACM4K-2585", func() {
		Eventually(func() error { return StageRunner.Run("RHACM4K-2585") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
})

var _ = Describe("channel-test", func() {
	It("chn-001", func() {
		Eventually(func() error { return DefaultRunner.Run("chn-001") }, 5*pullInterval, pullInterval).Should(Succeed())
	})

	It("chn-002", func() {
		Eventually(func() error { return DefaultRunner.Run("chn-002") }, 5*pullInterval, pullInterval).Should(Succeed())
	})

	It("chn-003", func() {
		Eventually(func() error { return DefaultRunner.Run("chn-003") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("chn-004", func() {
		Eventually(func() error { return DefaultRunner.Run("chn-004") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
})

var _ = Describe("subscription-test", func() {
	It("sub-001", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-001") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("sub-002", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-002") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("Test subscription with Git release tag", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-003") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
	It("Test subscription with Git commit", func() {
		Eventually(func() error { return DefaultRunner.Run("sub-004") }, 5*pullInterval, pullInterval).Should(Succeed())
	})
})
