#!/usr/bin/env bash

if [ -d ./test ]; then
    echo "Removing test repo dir"
    rm -rf test/
fi

if [ ./ca.pem ]; then
    echo "Removing CA file"
    rm ca.pem
fi

if [ ./child.kubeconfig ]; then
    echo "Removing child kubeconfig file"
    rm child.kubeconfig
fi

if [ ./kind.yaml ]; then
    echo "Removing kind config file"
    rm kind.yaml
fi

if [ ./repo.yaml ]; then
    echo "Removing repo file"
    rm repo.yaml
fi
