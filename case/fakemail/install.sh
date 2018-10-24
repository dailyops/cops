#!/usr/bin/env bash
set -e

apt-get update -y 
apt-get install --force-yes -y build-essential libsqlite3-dev sqlite3

gem install mailcatcher --no-ri --no-rdoc

# cleanup package manager
apt-get remove --purge -y build-essential libsqlite3-dev 
apt-get autoclean && apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
