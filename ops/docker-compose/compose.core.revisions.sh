#!/bin/bash
# This composition is for testing the core compute services. The core
# services are brought up along with the revisions-github
# service. Since we're usually DIRECTLY ACCESSING Kakfka from
# service-schedule in this configuration, then Kafka is brought up
# advertising itself as localhost, instead of the internal kafka
# container.
if [ "$1" = "up" ]; then
    docker-compose -f core.yml -f revisions.yml -f values-core-expose-kafka.yml up
elif [ "$1" = "down" ]; then
    docker-compose -f core.yml -f revisions.yml -f values-core-expose-kafka.yml down
else
    echo "invalid action: $1"
fi
