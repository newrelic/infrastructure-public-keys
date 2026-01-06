FROM ruby:3-alpine3.15

RUN apk add --update ruby-dev gcc make musl-dev libffi-dev xz-dev tar rpm && \
    gem install fpm

RUN mkdir -p /fpm/opt/newrelic-infra-public-keys/keyrings
COPY ./deb/.fpm /fpm
COPY ./gpg/keyrings /fpm/opt/newrelic-infra-public-keys/keyrings
COPY ./deb/newrelic-infra-public-keys /fpm/newrelic-infra-public-keys
COPY ./deb/remove-keyring /fpm/remove-keyring

WORKDIR /fpm

ENTRYPOINT ["fpm"]
CMD ["."]
