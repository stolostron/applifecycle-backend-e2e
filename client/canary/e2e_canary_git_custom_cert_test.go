package client_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

var _ = Describe("e2e-server", func() {
	It("[P1][Sev1][app-lifecycle] Install test Git repo server with custom certificate", func() {
		ret := pkg.RunCMD("./scripts/gitServer/install.sh")

		Expect(ret).To(Equal(0))
	})

	It("[P1][Sev1][app-lifecycle] Test subscribing to Git repo with custom certificate", func() {
		ret := pkg.RunCMD("./scripts/git_custom_certs.sh")

		Expect(ret).To(Equal(0))
	})

	It("[P1][Sev1][app-lifecycle] Uninstall test Git repo server", func() {
		ret := pkg.RunCMD("./scripts/gitServer/uninstall.sh")

		Expect(ret).To(Equal(0))
	})
})
