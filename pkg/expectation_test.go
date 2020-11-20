package pkg

import (
	"fmt"
	"testing"
)

func TestParseExpectation(t *testing.T) {
	var tests = []struct {
		name     string
		expected Expectations
		given    []byte
	}{
		{"name", Expectations{}, []byte(`
[{
		"test_id": "1",
		"target_cluster": "hub",
		"desc": "should have a channel on hub",
		"apiversion": "apps.open-cluster-management.io/v1",
		"kind": "channel",
		"name": "git",
		"namespace": "ch-git",
		"matcher": "byname",
		"args": {}
	},
	{
		"test_id": "1",
		"target_cluster": "hub",
		"desc": "should have a configmap on hub",
		"apiversion": "v1",
		"kind": "configmap",
		"name": "guestbook",
		"namespace": "ch-git",
		"matcher": "byname",
		"args": {}
	},
	{
		"test_id": "1",
		"target_cluster": "spoke",
		"desc": "should have a mirror subscription on spoke",
		"apiversion": "apps.open-cluster-management.io/v1",
		"kind": "subscription",
		"name": "git-sub",
		"namespace": "git-sub-ns",
		"matcher": "byannotation",
		"args": {
			"apps.open-cluster-management.io/git-path": "git-ops/bookinfo/guestbook"
		}
	},
	{
		"test_id": "1",
		"target_cluster": "spoke",
		"desc": "should have 3 deployment on spoke",
		"apiversion": "apps/v1",
		"kind": "deployment",
		"name": "git-sub",
		"namespace": "git-sub-ns",
		"matcher": "byannotationcount",
		"args": {
			"apps.open-cluster-management.io/hosting-subscription": "git-sub-ns/git-sub",
			"count": "3"
		}
	}
]`)},
	}
	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			actual, _ := parseExpectations(tt.given)
			for _, item := range *actual {
				fmt.Printf("izhang ======  item = %+v\n", item)
			}

		})
	}
}
