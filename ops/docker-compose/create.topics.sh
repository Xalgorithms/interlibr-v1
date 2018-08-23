#!/bin/bash
TOPICS="il.verify.rule_execution il.emit.audit"

for t in $TOPICS; do
    echo "creating $t"
    docker exec dev_kafka_1 kafka-topics --create --zookeeper zookeeper:2181 --replication-factor 1 --partitions 1 --topic "$t"
done
