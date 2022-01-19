package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stolostron/applifecycle-backend-e2e/pkg"
)

var _ = Describe("e2e-subscription-admin-test", func() {
	It("[P1][Sev1][app-lifecycle] Test nested subscriptions with subscription admin", func() {
		ret := pkg.RunCMD("./scripts/subscriptionAdmin/test.sh")
		Expect(ret).To(Equal(0))
	})
})
