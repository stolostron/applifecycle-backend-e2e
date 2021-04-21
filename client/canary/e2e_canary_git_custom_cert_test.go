package client_test

import (
	"fmt"
	"testing"

	"github.com/onsi/gomega"
	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

func Test_Git_Custom_Cert_E2E(t *testing.T) {
	g := gomega.NewGomegaWithT(t)

	fmt.Println("e2e-server")

	fmt.Println("[P1][Sev1][app-lifecycle] Install test Git repo server with custom certificate")

	ret := pkg.RunCMD("./scripts/gitServer/install.sh")
	g.Expect(ret).To(gomega.Equal(true))

	fmt.Println("[P1][Sev1][app-lifecycle] Test subscribing to Git repo with custom certificate")

	ret = pkg.RunCMD("./scripts/git_custom_certs.sh")
	g.Expect(ret).To(gomega.Equal(true))

	fmt.Println("[P1][Sev1][app-lifecycle] Uninstall test Git repo server")

	ret = pkg.RunCMD("./scripts/gitServer/uninstall.sh")
	g.Expect(ret).To(gomega.Equal(true))
}
