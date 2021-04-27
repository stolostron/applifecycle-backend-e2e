package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

var _ = Describe("e2e-server", func() {
	It("[P1][Sev1][app-lifecycle] Test argocd integration", func() {
		ret := pkg.RunCMD("./scripts/argocd_integration.sh")

		Expect(ret).To(Equal(0))
	})
})
