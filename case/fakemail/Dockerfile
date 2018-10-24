#ref https://github.com/schickling/dockerfiles/tree/master/mailcatcher
FROM daocloud.io/ruby:2.3.0

#RUN rm  -rf /etc/apt/sources.list /etc/apt/sources.list.d
#COPY conf/apt-sources.list /etc/apt/sources.list

ADD install.sh install.sh
RUN chmod +x install.sh
RUN ./install.sh  
RUN rm install.sh

# smtp port
EXPOSE 1025

# webserver port
EXPOSE 1080

#--foreground --ip 0.0.0.0 --http-port 1026 --verbose --browse
CMD ["mailcatcher", "--foreground", "--ip=0.0.0.0", "--verbose"]
