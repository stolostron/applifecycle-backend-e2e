package pkg

import (
	"fmt"
	"os"
	"strings"

	"github.com/go-cmd/cmd"
)

// RunCMD execute long running script with disabling output buffering, and enabling streaming.
func RunCMD(scriptName string) bool {
	cmdOptions := cmd.Options{
		Buffered:  false,
		Streaming: true,
	}

	// Create Cmd with options
	envCmd := cmd.NewCmdOptions(cmdOptions, "/bin/sh", scriptName)

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

				if strings.Contains(line, "E2E CANARY TEST DONE -") {
					// For some reason, the Stdout and Stderr channels are not closed even after the script is done.
					// Workaround: echo "E2E CANARY TEST DONE - ***" as the last line of the script.
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
	fmt.Println("Script: ", scriptName, ", Runtime: ", finalStatus.Runtime, " Seconds")

	return true
}
