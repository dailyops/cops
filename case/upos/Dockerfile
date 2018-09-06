FROM ubuntu:16.04
MAINTAINER cao7113@hotmail.com

ENV DEBIAN_FRONTEND noninteractive
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV TZ Asia/Shanghai

RUN locale-gen $LANGUAGE && \
    dpkg-reconfigure locales && \
    dpkg-reconfigure -f noninteractive tzdata  && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#ADD bootstrap /bootstrap

# recommend use China apt source!
RUN sed -i 's/archive.ubuntu/cn.archive.ubuntu/' /etc/apt/sources.list
RUN apt-get -y update && apt-get install -y curl && \ 
    apt-get -y clean && \
    rm -rf /usr/share/doc/* && \
    rm -rf /usr/share/locale/* && \
    rm -rf /usr/share/man/* && \
    rm -rf /var/cache/debconf/*-old && \
    rm -rf /var/lib/apt/lists/*

CMD bash
