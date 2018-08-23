#!/bin/bash
VERSION=`cat .version`
ENVIRONMENTS="development production"

for en in $ENVIRONMENTS; do
    docker build --squash -t "xalgorithms/xadf-base-image-ruby:latest-$en" -t "xalgorithms/xadf-base-image-ruby:$VERSION-$en" -f "Dockerfile.$en" .
    docker push "xalgorithms/xadf-base-image-ruby:latest-$en"
    docker push "xalgorithms/xadf-base-image-ruby:$VERSION-$en"
done

