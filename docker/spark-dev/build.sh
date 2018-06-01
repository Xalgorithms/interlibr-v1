#!/bin/bash

. .vars

wget --continue $SCALA_PKG_URL
wget --continue $SBT_PKG_URL
wget --continue $SPARK_PKG_URL

docker build \
  --build-arg SCALA_PKG_NAME=$SCALA_PKG_NAME \
  --build-arg SBT_PKG_NAME=$SBT_PKG_NAME     \
  --build-arg SPARK_PKG_NAME=$SPARK_PKG_NAME \
  -t xalgorithms/spark-dev:$SPARK_VER-$VER   \
  -t xalgorithms/spark-dev:latest \
  .
