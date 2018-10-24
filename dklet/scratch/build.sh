#!/bin/sh
apt-get -y update
apt-get -y install build-essential
cd /build
gcc -o hello -static -nostartfiles hello.c
