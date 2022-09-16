FROM ruby:3-alpine3.15

RUN apk add --update ruby-dev gcc make musl-dev libffi-dev xz-dev tar && \
    gem install fpm


RUN mkdir -p /fpm/opt/newrelic-infra-public-keys/keyrings
COPY .fpm /fpm
COPY gpg/keyrings /fpm/opt/newrelic-infra-public-keys/keyrings
COPY newrelic-infra-public-keys /fpm/newrelic-infra-public-keys
COPY remove-keyring /fpm/remove-keyring

WORKDIR /fpm

ENTRYPOINT ["fpm"]
CMD ["."]
