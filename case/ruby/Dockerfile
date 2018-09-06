FROM ruby:2.5-alpine
RUN apk --no-cache add build-base nodejs postgresql-dev

# timzone: https://www.ivankrizsan.se/2015/10/31/time-in-docker-containers/
RUN apk --no-cache add tzdata
ARG CONTAINER_TIMEZONE=Asia/Shanghai
RUN cp /usr/share/zoneinfo/${CONTAINER_TIMEZONE} /etc/localtime && \
    echo "${CONTAINER_TIMEZONE}" >  /etc/timezone && \
    echo "Container timezone set to: $CONTAINER_TIMEZONE"

CMD irb
