#!/bin/bash
VERSION=`cat .version`
#ENVIRONMENTS="development production"
ENVIRONMENTS="development"

for en in $ENVIRONMENTS; do
    docker build --squash -t "xalgorithms/jupyterhub-live:latest-$en" -t "xalgorithms/jupyterhub-live:$VERSION-$en" -f "Dockerfile.$en" .
    docker push "xalgorithms/jupyterhub-live:latest-$en"
    docker push "xalgorithms/jupyterhub-live:$VERSION-$en"
done

