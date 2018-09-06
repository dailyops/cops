#!/usr/bin/env bash
set -e

[ -d /etc/rsyslog.d ] || { echo No found rsyslog && exit; } 

flog_conf=/etc/rsyslog.d/forward_flog.conf
flog_server=${SYSLOG_SERVER:-log.logserver.ip}
flog_port=${SYSLOG_PORT:-1514}
flog_facility=${SYSLOG_FACILITY:-local0}

mv /etc/rsyslog.d /etc/rsyslog.d.bak
mkdir -p /etc/rsyslog.d 

# use tcp protocol, rather than default udp marked as @
rule="$flog_facility.*  @@$flog_server:$flog_port"
echo $rule > $flog_conf
echo config rsyslog: update rule $rule into $flog_conf

service rsyslog start
echo ==rsyslog has started
