#!/bin/bash

. .vars

docker push xalgorithms/spark-dev:$SPARK_VER-$VER
docker push xalgorithms/spark-dev:latest
