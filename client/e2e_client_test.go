package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("helmrelease-test", func() {
	It("release-001", func() {
		Expect(DefaultRunner.Run("release-001")).Should(Succeed())
	})
})

var _ = Describe("channel-test", func() {
	It("chn-003", func() {
		Expect(DefaultRunner.Run("chn-003")).Should(Succeed())
	})
})
