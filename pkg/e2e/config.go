package e2e

import (
	"fmt"
	"io/ioutil"
	"strings"

	chnapis "github.com/open-cluster-management/multicloud-operators-channel/pkg/apis"
	dplapis "github.com/open-cluster-management/multicloud-operators-deployable/pkg/apis"
	plrapis "github.com/open-cluster-management/multicloud-operators-placementrule/pkg/apis"
	subapis "github.com/open-cluster-management/multicloud-operators-subscription/pkg/apis"

	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/tools/clientcmd"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

const (
	configSuffix = "kubeconfigs"
)

type ConfigUnit struct {
	// mainly for checking expectations
	Clt client.Client
	// mainly for applying resources
	CfgDir string
}

//KubeConfigs have cluster name and it's location for kubeconfig
type KubeConfigs map[string]*ConfigUnit

func LoadKubeConfigs(dir string) (KubeConfigs, error) {
	// use the current context in kubeconfig
	files, err := ioutil.ReadDir(dir)

	if err != nil {
		return KubeConfigs{}, err
	}

	dplapis.AddToScheme(scheme.Scheme)
	chnapis.AddToScheme(scheme.Scheme)
	plrapis.AddToScheme(scheme.Scheme)
	subapis.AddToScheme(scheme.Scheme)

	out := KubeConfigs{}
	for _, file := range files {
		p := fmt.Sprintf("%s/%s", dir, file.Name())
		cfg, err := clientcmd.BuildConfigFromFlags("", p)
		if err != nil {
			return out, err
		}

		ops := client.Options{
			Scheme: scheme.Scheme,
		}

		// creates the clientset
		clt, err := client.New(cfg, ops)
		if err != nil {
			return out, err
		}

		out[file.Name()] = &ConfigUnit{Clt: clt, CfgDir: p}
	}

	return out, nil
}

func (k KubeConfigs) GetClusterNames() string {
	out := []string{}

	for key := range k {
		line := fmt.Sprintf("%s,", key)
		out = append(out, line)
	}

	return "cluster names: " + strings.Join(out, " ")
}
