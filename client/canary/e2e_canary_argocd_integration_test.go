package client_test

import (
	"fmt"
	"testing"

	"github.com/onsi/gomega"
	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

func Test_Argocd_Integration_E2E(t *testing.T) {
	g := gomega.NewGomegaWithT(t)

	fmt.Println("e2e-server")
	fmt.Println("[P1][Sev1][app-lifecycle] Test argocd integration")

	ret := pkg.RunCMD("./scripts/argocd_integration.sh")

	g.Expect(ret).To(gomega.Equal(true))
}
