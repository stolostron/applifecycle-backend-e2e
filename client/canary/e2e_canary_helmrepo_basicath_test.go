package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stolostron/applifecycle-backend-e2e/pkg"
)

var _ = Describe("RHACM4K-2350: e2e-server", func() {
	It("[P1][Sev1][app-lifecycle] Test subscribing to Helm repo with basic authentication", func() {
		ret := pkg.RunCMD("./scripts/helmrepo_basicath.sh")
		//ret := 0
		Expect(ret).To(Equal(0))
	})
})
