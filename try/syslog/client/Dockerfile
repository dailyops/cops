# As syslog client to forward logs
FROM lab/ruby

RUN mv /etc/rsyslog.d/50-default.conf /etc/rsyslog.d/50-default.conf.bak
COPY conf/forward_log.conf /etc/rsyslog.d/forward_log.conf

ADD try /try
WORKDIR /try

CMD ["rsyslogd", "-n"]
