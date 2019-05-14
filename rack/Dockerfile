FROM ruby:2.5-alpine
LABEL maintainer=ruijiancao
ARG TIMEZONE=Asia/Shanghai
ARG PKG_MIRROR=mirrors.aliyun.com
ARG PKGS=""
RUN cp /etc/apk/repositories /etc/apk/repositories.bak && \
    sed -i "s=dl-cdn.alpinelinux.org=$PKG_MIRROR=g" /etc/apk/repositories && \
    apk add --no-cache tzdata $PKGS && \
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "Timezone set to: $TIMEZONE" && \
    echo "${TIMEZONE}" > /etc/Timezone

EXPOSE 9292
WORKDIR /app
COPY Gemfile Gemfile.lock ./
ARG GEM_MIRROR=https://gems.ruby-china.com/
ENV RACKUP_CONFIG=config.ru
RUN echo using mirrors gem: $GEM_MIRROR, npm: $NPM_MIRROR && \
    bundle config mirror.https://rubygems.org $GEM_MIRROR && \
    echo ==rackup config: $RACKUP_CONFIG && \
    bundle install --verbose
CMD rackup --host 0.0.0.0 $RACKUP_CONFIG
COPY . .