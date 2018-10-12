#!/bin/bash
# This composition is for testing ALL THE services live, based on published versions
if [ "$1" = "up" ]; then
    docker-compose \
        -f core.yml \
        -f revisions.yml -f revisions.published.yml \
        -f execute.yml -f execute.published.yml \
        -f schedule.yml -f schedule.published.yml \
        -f query.yml -f query.published.yml \
        -f events.yml -f events.published.yml \
        up
elif [ "$1" = "down" ]; then
    docker-compose \
        -f core.yml \
        -f revisions.yml -f revisions.published.yml \
        -f execute.yml -f execute.published.yml \
        -f schedule.yml -f schedule.published.yml \
        -f query.yml -f query.published.yml \
        -f events.yml -f events.published.yml \
        down
else
    echo "invalid action: $1"
fi
