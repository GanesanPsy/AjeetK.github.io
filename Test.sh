#!/bin/bash

# Timestamp Function
timestamp() {
    date +"%T"
}

# Temporary file for stderr redirects
tmpfile=$(mktemp)

# Go build
build () {
    echo "    $(timestamp): started build script..."
    echo "   $(timestamp): building cicdexample"
    go build 2>tmpfile
    if [ -s tmpfile ]; then
        cat tmpfile
        echo "   $(timestamp): compilation error, exiting"
        rm tmpfile
        exit 0
    fi
}

# Deploy to Minikube using kubectl
deploy() {
    echo "  $(timestamp): deploying to Minikube"
    kubectl apply -f deploy.yml
}

# Orchestrate
echo " Welcome to the Builder v0.2, written by github.com/cishiv"
if [[ $1 = "build" ]]; then
    if [[ $2 = "docker" ]]; then
        build
        buildDocker
        echo "    $(timestamp): complete."
        echo " $(timestamp): exiting..."
    elif [[ $2 = "bin" ]]; then
        build
        echo "   $(timestamp): complete."
        echo "  $(timestamp): exiting..."
    else
        echo "   $(timestamp): missing build argument"
    fi
else
    if [[ $1 = "--help" ]]; then
        echo "build - start a build to produce artifacts"
        echo "  docker - produces docker images"
        echo "  bin - produces executable binaries"
    else
        echo "$(timestamp): no arguments passed, type --help for a list of arguments"
    fi
fi
