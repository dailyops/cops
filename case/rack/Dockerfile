FROM ruby:2.5-alpine

# timzone: https://www.ivankrizsan.se/2015/10/31/time-in-docker-containers/
RUN apk --no-cache add tzdata
ARG CONTAINER_TIMEZONE=Asia/Shanghai
RUN cp /usr/share/zoneinfo/${CONTAINER_TIMEZONE} /etc/localtime && \
    echo "${CONTAINER_TIMEZONE}" >  /etc/timezone && \
    echo "Container timezone set to: $CONTAINER_TIMEZONE"

# rack app
RUN mkdir -p /app /app/log
WORKDIR /app
COPY Gemfile Gemfile.lock ./
EXPOSE 9292
ARG GEM_SOURCE
ENV RACKUP_CONFIG=config.ru
RUN echo ==using gem source: $GEM_SOURCE, && \
    echo ==rackup config: $RACKUP_CONFIG && \
    bundle install --verbose
CMD rackup --host 0.0.0.0 $RACKUP_CONFIG
COPY . .
