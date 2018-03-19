#!/bin/bash
dcos package install kafka --cli --yes
dcos kafka topic create xadf.compute.documents --partitions 1 --replication 1
dcos kafka topic create xadf.compute.effective --partitions 1 --replication 1
dcos kafka topic create xadf.compute.applicable --partitions 1 --replication 1
dcos kafka topic create xadf.compute.revision --partitions 1 --replication 1
