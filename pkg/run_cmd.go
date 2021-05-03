package pkg

import (
	"fmt"
	"os"
	"strings"

	"github.com/go-cmd/cmd"
)

// RunCMD execute long running script with disabling output buffering, and enabling streaming.
// return the exit code of the script process.
func RunCMD(scriptName string) int {
	cmdOptions := cmd.Options{
		Buffered:  false,
		Streaming: true,
	}

	// Create Cmd with options
	envCmd := cmd.NewCmdOptions(cmdOptions, "/bin/sh", scriptName)

	// cmdDone will be set to true whenever the "E2E CANARY TEST - DONE" line is outputted, meaning the script is done
	// This is to work around the exit code returns -1 even though the script is done correctly
	cmdDone := false

	// Print STDOUT and STDERR lines streaming from Cmd
	doneChan := make(chan struct{})

	go func() {
		defer func() {
			close(doneChan)
		}()

		// Done when both channels have been closed
		for envCmd.Stdout != nil || envCmd.Stderr != nil {
			select {
			case line, open := <-envCmd.Stdout:
				if !open {
					envCmd.Stdout = nil

					continue
				}

				fmt.Println(line)

				if strings.Contains(line, "E2E CANARY TEST -") {
					if strings.Contains(line, "E2E CANARY TEST - DONE") {
						cmdDone = true
					}

					// For some reason, the Stdout and Stderr channels are not closed even after the script is done.
					// Workaround: echo "E2E CANARY TEST - ***" as the last line of the script.
					// Stop the cmd when standard output contains such keywords
					envCmd.Stop()

					continue
				}

			case line, open := <-envCmd.Stderr:
				if !open {
					envCmd.Stderr = nil

					continue
				}

				fmt.Fprintln(os.Stderr, line)
			}
		}
	}()

	// start the command asynchronously
	statusChan := envCmd.Start()

	// Wait for goroutine to print everything
	<-doneChan

	finalStatus := <-statusChan
	fmt.Println("Script: ", scriptName, ", Runtime: ", finalStatus.Runtime, " Seconds", ", ExitCode: ", finalStatus.Exit, ", cmdDone: ", cmdDone)

	if cmdDone {
		return 0
	}

	return finalStatus.Exit
}
