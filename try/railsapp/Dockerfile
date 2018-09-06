FROM ruby:2.5

RUN apt-get -y update && \
    apt-get -y install build-essential patch zlib1g-dev liblzma-dev && \
    apt-get -y install libpq-dev imagemagick git-core && \
    apt-get -y install libcurl3 libcurl4-openssl-dev && \
    apt-get -y install nodejs && \
    [ -e /usr/bin/node ] || ln -s `which nodejs` /usr/bin/node && \
    mkdir -p /tmp/bundler && \
    apt-get -y autoclean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/bundler
COPY Gemfile /tmp/bundler
RUN bundle install --verbose --without development test

CMD bash
