# As a try syslog server to aggregate logs from app nodes
FROM upos

COPY conf/ports.conf /etc/rsyslog.d/ports.conf

CMD ["rsyslogd", "-n"]
