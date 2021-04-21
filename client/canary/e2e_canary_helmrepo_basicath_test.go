package client_test

import (
	"fmt"
	"testing"

	"github.com/onsi/gomega"
	"github.com/open-cluster-management/applifecycle-backend-e2e/pkg"
)

func Test_Helmrepo_Basic_Auth_E2E(t *testing.T) {
	g := gomega.NewGomegaWithT(t)

	fmt.Println("RHACM4K-2350: e2e-server")
	fmt.Println("[P1][Sev1][app-lifecycle] Test subscribing to Helm repo with basic authentication")

	ret := pkg.RunCMD("./scripts/helmrepo_basicath.sh")

	g.Expect(ret).To(gomega.Equal(true))
}
