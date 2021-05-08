#! /bin/bash

# keep scanning the local 8080 port to avoid argocd server port forward time out
while true ; do nc -vz 127.0.0.1 8080 ; sleep 10 ; done
