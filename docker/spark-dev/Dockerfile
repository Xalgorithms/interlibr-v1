FROM openjdk:8-jdk
MAINTAINER Don Kelly <karfai@gmail.com>

ARG SCALA_PKG_NAME
ARG SBT_PKG_NAME
ARG SPARK_PKG_NAME

ARG APPS_ROOT=/apps

ENV SCALA_HOME=${APPS_ROOT}/scala
ENV SBT_HOME=${APPS_ROOT}/sbt
ENV SPARK_HOME=${APPS_ROOT}/spark

ENV PATH=$JAVA_HOME/bin:$SCALA_HOME/bin:$SBT_HOME/bin:$SPARK_HOME/bin:$PATH

RUN mkdir ${APPS_ROOT}
WORKDIR /apps

COPY ${SCALA_PKG_NAME}.tgz .
RUN tar -v -xf ${SCALA_PKG_NAME}.tgz && \
    ln -s ${SCALA_PKG_NAME} scala &&    \
    rm ${SCALA_PKG_NAME}.tgz
    
COPY ${SBT_PKG_NAME}.tgz .
RUN tar -v -xf ${SBT_PKG_NAME}.tgz && \
    ln -s ${SBT_PKG_NAME} sbt &&      \
    rm ${SBT_PKG_NAME}.tgz
    
COPY ${SPARK_PKG_NAME}.tgz .
RUN tar -v -xf ${SPARK_PKG_NAME}.tgz && \
    ln -s ${SPARK_PKG_NAME} spark &&    \
    rm ${SPARK_PKG_NAME}.tgz && \
    cp spark/conf/log4j.properties.template spark/conf/log4j.properties && \
    chown -R root:root $SPARK_HOME

USER root
WORKDIR /root

