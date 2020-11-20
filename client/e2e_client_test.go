package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("helmrelease-test", func() {
	It("release-001", func() {
		Expect(DefaultRunner.run("release-001")).Should(Succeed())
	})
})

var _ = FDescribe("channel-test", func() {
	It("chn-003", func() {
		Expect(DefaultRunner.run("release-001")).Should(Succeed())
	})
})
