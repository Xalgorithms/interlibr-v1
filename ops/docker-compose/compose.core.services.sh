#!/bin/bash
# This composition is for testing ALL THE services live
if [ "$1" = "up" ]; then
    docker-compose -f core.yml -f revisions.yml -f execute.yml -f schedule.yml -f query.yml -f events.yml up
elif [ "$1" = "down" ]; then
    docker-compose -f core.yml -f revisions.yml -f execute.yml -f schedule.yml -f query.yml -f events.yml down
else
    echo "invalid action: $1"
fi
