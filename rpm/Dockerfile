FROM ruby:3-alpine3.15

RUN apk add --update ruby-dev gcc make musl-dev libffi-dev xz-dev tar rpm && \
    gem install fpm


RUN mkdir -p /fpm/opt/newrelic-infra-public-keys/keys
COPY ./rpm/.fpm /fpm
COPY ./gpg/keys /fpm/opt/newrelic-infra-public-keys/keys
COPY ./rpm/newrelic-infra-public-keys /fpm/newrelic-infra-public-keys
COPY ./rpm/remove-keys /fpm/remove-keys

WORKDIR /fpm

ENTRYPOINT ["fpm"]
CMD ["."]
