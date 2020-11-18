package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("applifecycle-api-test", func() {
	It("chn-001", func() {
		Expect(DefaultRunner.run("release-001")).Should(Succeed())
	})
})
