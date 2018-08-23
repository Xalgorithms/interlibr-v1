#!/bin/bash
VERSION=`cat .version`
ENVIRONMENTS="development production"

for en in $ENVIRONMENTS; do
    docker build --squash -t "xalgorithms/il-cli:latest-$en" -t "xalgorithms/il-cli:$VERSION-$en" -f "Dockerfile.$en" .
    docker push "xalgorithms/il-cli:latest-$en"
    docker push "xalgorithms/il-cli:$VERSION-$en"
done

