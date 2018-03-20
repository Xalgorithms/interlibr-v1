#!/bin/bash
VERSION=`cat .version`
ENVIRONMENTS="development production"

for en in $ENVIRONMENTS; do
    docker build --squash -t "xalgorithms/xadf-cli:latest-$en" -t "xalgorithms/xadf-cli:$VERSION-$en" -f "Dockerfile.$en" .
    docker push "xalgorithms/xadf-cli:latest-$en"
    docker push "xalgorithms/xadf-cli:$VERSION-$en"
done

