#!/bin/bash
# This composition is for testing ALL THE services live
if [ "$1" = "up" ]; then
    docker-compose -f docker-compose-core.yml -f docker-compose-revisions.yml -f docker-compose-execute.yml -f docker-compose-schedule.yml -f docker-compose-query.yml -f docker-compose-events.yml up
elif [ "$1" = "down" ]; then
    docker-compose -f docker-compose-core.yml -f docker-compose-revisions.yml -f docker-compose-execute.yml -f docker-compose-schedule.yml -f docker-compose-query.yml -f docker-compose-events.yml down
else
    echo "invalid action: $1"
fi
