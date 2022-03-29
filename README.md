---
tags: redhat, test
---

Table of Contents
=================

   * [Design](#design)
   * [Usage](#usage)
   * [Expand the server](#expand-the-server)
      * [Define and integrate your own test case and expectation](#define-and-integrate-your-own-test-case-and-expectation)
         * [Form Inputs](#form-inputs)
      * [Test the output and put your case into test server](#test-the-output-and-put-your-case-into-test-server)
      * [Share your tests](#share-your-tests)
   * [Leverage the new test case in an operator](#leverage-the-new-test-case-in-an-operator)
   * [Leverage the new test case in canary](#leverage-the-new-test-case-in-canary)
      * [Canary integeration overview:](#canary-integeration-overview)
      * [Add your test case to canary](#add-your-test-case-to-canary)
   * [Beyond a single operator](#beyond-a-single-operator)
   * [Progress](#progress)

Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc)


# Design 

https://hackmd.io/d50Lam9hS2eM4w-PburJWA?view

# Usage
`applifecyce-backend-e2e` is a web server which provides a few endpoints, to help you ease the test burden and serve some automation needs.  
```
Usage of applifecycle-backend-e2e: 
-cfg string
the path to clusters config files (default "default-kubeconfigs")
-data string
the path to clusters config files
-t int
timeout for running each expectation unit (default 15)
-v int
log level (default 1)
```


- Run test server

    To run the test server(at background), you can: 

    ```go
    go get github.com/stolostron/applifecycle-backend-e2e@v0.1.6

    # With default test cases 
    applifecycle-backend-e2e -cfg cluster_config &
    
    # With your own test cases defined in testdata
    applifecycle-backend-e2e -cfg cluster_config -data testdata &
    ```
    **Note: Your own `testdata` directory should have the same structure as the default one.**
    


    **Note: The above is how the operator e2e test runs the test server**
 [Subscription e2e test](https://github.com/stolostron/multicloud-operators-subscription/blob/master/build/run-e2e-tests.sh)
 
- Query test server for running/checking tests

    Once you start the test server, you can query test server via `curl`, or query it within your `ginkgo suite`, or via your browser.

    For example, run it in your browser:
    ```
    http://localhost:8765/run?id=chn-001

    {
        "test_id": "chn-001",
        "name": "checked expectations",
        "run_status": "succeed",
        "error": "",
        "details": [
            {
                "test_id": "chn-001",
                "target_cluster": "hub",
                "desc": "should have a channel on hub",
                "apiversion": "apps.open-cluster-management.io/v1",
                "kind": "channel",
                "name": "git",
                "namespace": "ch-git",
                "matcher": "byname",
                "args": {}
            }
        ]
    }
    ```



    Similar idea applied to the other endpoints.

    ```
    {
        "test_id": "helper",
        "name": "registered handler",
        "run_status": "",
        "error": "",
        "details": {
            "/clusters": "show all the registered cluster info",
            "/clusters?id=": "show all the registered cluster info by id",
            "/expectations": "show all the registered expectations",
            "/expectations?id=": "show all the registered expectation by id",
            "/results?id=": "show results by id",
            "/run/stage?id=": "run stage by id",
            "/run?id=": "run test case by id",
            "/stages": "show all the registered stages",
            "/stages?id=": "show all the registered stage by id",
            "/testcases": "show all the registered test cases",
            "/testcases?id=": "show all the registered test case by id"
        }
    }
    ```

# Expand the server
## Define and integrate your own test case and expectation

### Form Inputs 
- define app yamls
```
❯ cat default-e2e-test-data/testcases/release-operator-e2e.json
[
{
  "test_id": "release-001",
  "desc": "helmrelease install test: guestbook deploy",
  "urls": ["https://raw.githubusercontent.com/stolostron/multicloud-operators-subscription-release/e2e-test-setup/examples/test-guestbook010.yaml"],
  "target_cluster": "hub"
}
]
```

- define app expectations
```
❯ cat default-e2e-test-data/expectations/release-e2e.json
[
{
                "test_id": "release-001",
                "target_cluster": "hub",
                "desc": "should have a helmrelease on hub",
                "apiversion": "apps.open-cluster-management.io/v1",
                "kind": "HelmRelease",
                "name": "guestbook-010",
                "namespace": "helmrelease-test",
                "matcher": "byname",
                "args": {}
        },
{
                "test_id": "release-001",
                "target_cluster": "hub",
                "desc": "should have a frontend deployment on hub",
                "apiversion": "apps/v1",
                "kind": "deployment",
                "name": "guestbook-010-gbapp-frontend",
                "namespace": "helmrelease-test",
                "matcher": "byname",
                "args": {}
        },

etc.
```

## Test the output and put your test case into the test server

You can test your new test case by doing:(assuming you install the server)
1. start the server with your new test case locations

      `applifecycle-backend-e2e -cfg <your kubeconfig> -data default-e2e-test-data`
2. run your new test cases
    `http://localhost:8765/run?id=<new case ID>`
    
    You can check other parameters such as if the case is parsed correctly or not, by hitting different endpoints.
    
3. added your test case to binary data files by run `make gen`
    
    You need to run `make gen`, which will put your testcase to the default binary data file. Doing so, the client of test server can your tests directly.

4. add your test case to the test server e2e-test suite, so travis of the test server can run it for you
    just add another entry to the following:
    
    https://github.com/stolostron/applifecycle-backend-e2e/blob/main/client/e2e_client/e2e_client_test.go

5. PR your changes, after the PR merge, you can tag it  with semVer syntac(eg, `v0.1.x`), which will give us better dependency control when use your test cases



## Share your tests

Once your test case is tagged, you can point to the specific tag in a repo and consume it.


# Leverage the new test case in an operator
1. in our operator point to the new test server tag, by modify the `run-e2e-tests.sh`
    
    [run-e2e-tests.sh](https://github.com/stolostron/multicloud-operators-subscription/blob/master/build/run-e2e-tests.sh#L112)

2. adding the new test case id to the `testIDs` array

    The following example would work on the `channel`, `subscription` and `subscription-release` repos for now.
    
    for example:

    https://github.com/stolostron/multicloud-operators-subscription-release/blob/master/e2e/e2e_test.go

    ```go
    func TestE2ESuite(t *testing.T) {
        if err := isSeverUp(); err != nil {
            t.Fatal(err)
        }

        testIDs := []string{"release-001"}

        for _, tID := range testIDs {
            if err := runner(tID); err != nil {
                t.Fatal(err)
            }
        }

        t.Logf("helm release e2e tests %v passed", testIDs)
    }
    ```
3. test the added case by run `make e2e` in your repo, if everything works fine, then PR the repo.



# Leverage the new test case in canary

## Canary integeration overview:
- entry point: the canary env give us an entry point at:

    https://github.com/stolostron/canary-scripts/tree/2.2-integration/squad-tests

    As you can see per squad per folder, in the folder, there's `run_test.sh`, which will run a given test image via `docker run` command.

    For our team, the `run_test.sh` is defined as the following,

    https://github.com/stolostron/applifecycle-backend-e2e/blob/main/client/e2e_client/e2e_client_test.go

    As the canary will only accept `JUnit` format output and the output needs to be in `$root_dir/results`.

- work with entry point:
    1. we mapped the out test result at docker level in the `run_test.sh` by 
    `--volume $root_dir/results:/opt/e2e/client/canary/results \`

    2. in the test server, we had the `NewJUnitReporter` to generate the result at the `Junit` format.

        https://github.com/stolostron/applifecycle-backend-e2e/blob/main/client/canary/e2e_canary_hello_world_suite_test.go

    ```go=
    func TestAppLifecycle_API_E2E(t *testing.T) {
        RegisterFailHandler(Fail)

        RunSpecsWithDefaultAndCustomReporters(t,
            "Applifecycle-API-Test",
            []Reporter{printer.NewlineReporter{}, reporters.NewJUnitReporter(JUnitResult)})
    }
    ```

    3. we set up specific tests for canary

        https://github.com/stolostron/applifecycle-backend-e2e/blob/main/client/canary/e2e_canary_hello_world_test.go
        
    I added `KUBE_DIR` as kubeconfig directroy for canary, for better docker command set up... not sure it's a valid argument... might need to get rid of this logic


## Add your test case to canary
1. test your cases in your local env, generate the binary data, then you need to add your test case to 

    https://github.com/stolostron/applifecycle-backend-e2e/blob/main/client/canary/e2e_canary_hello_world_test.go

2. then PR your changes
3. update the Dockerfile to the new tag/version 

    [Dockerfile](https://github.com/stolostron/applifecycle-backend-e2e/blob/0a60d8de754e3d144ebb300c41a480821e5bcfd3/Dockerfile#L19)
4. make sure your change is merged to `release-2.2` branch of test server.



# Beyond a single operator
```
default-e2e-test-data
├── expectations
│   ├── channel-e2e.json
│   ├── release-e2e.json
│   └── subscription-e2e.json
├── stages
│   └── helm-release.json
└── testcases
    ├── channel-operator-e2e.json
    ├── release-operator-e2e.json
    └── subscription-operator-e2e.json
```

# Progress
This repo is set up for testing the following operators:
- [Channel](https://github.com/stolostron/multicloud-operators-channel)
- [Subscription](https://github.com/stolostron/multicloud-operators-subscription)
- [Canary integration](https://github.com/stolostron/canary-scripts)


Initial Set up:
- [x] Canary (staging env)
- [x] Channel
- [x] Subscription
- [x] Subscription-release
- [x] Placementrule
