#!/bin/bash
VERSION=`cat .version`
ENVIRONMENTS="development production"

for en in $ENVIRONMENTS; do
    docker build --squash -t "xalgorithms/xadf-base-image-node:latest-$en" -t "xalgorithms/xadf-base-image-node:$VERSION-$en" -f "Dockerfile.$en" .
    docker push "xalgorithms/xadf-base-image-node:latest-$en"
    docker push "xalgorithms/xadf-base-image-node:$VERSION-$en"
done

