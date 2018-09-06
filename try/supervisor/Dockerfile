FROM upos

RUN mv /etc/supervisor/conf.d /etc/supervisor/conf.d.bak
ADD conf /etc/supervisor/conf.d

CMD ["/usr/bin/supervisord", "-n"]
