IMAGE_VERSION ?= dev
IMAGE_NAME = newrelic-infra-public-keys
PKG_VERSION ?= 0.0.0
BUILDER_IMG_TAG = infrastructure-public-keys-builder

keys := $(wildcard gpg/keys/current/newrelic* gpg/keys/next/newrelic*)

gpg/keyrings/newrelic-infra-keyring.gpg: ./scripts/generate_keyring.sh $(keys)
	./scripts/generate_keyring.sh $(keys)

.PHONY: clean
clean:
	@rm -f pkg/*.deb
	@rm -f pkg/*.rpm

.PHONY: generate-keyring
generate-keyring: gpg/keyrings/newrelic-infra-keyring.gpg

.PHONY: build-container/deb
build-container/deb:
	@docker build --no-cache -t $(IMAGE_NAME):$(IMAGE_VERSION) -f ./deb/Dockerfile .

.PHONY: build-container/rpm
build-container/rpm:
	@docker build --no-cache -t $(IMAGE_NAME):$(IMAGE_VERSION) -f ./rpm/Dockerfile .

.PHONY: build/deb
build/deb: clean generate-keyring build-container/deb
	@docker run -v $(CURDIR)/pkg:/fpm/pkg $(IMAGE_NAME):$(IMAGE_VERSION) --version $(PKG_VERSION) .

.PHONY: build/rpm
build/rpm: clean build-container/rpm
	@docker run -v $(CURDIR)/pkg:/fpm/pkg $(IMAGE_NAME):$(IMAGE_VERSION) --version $(PKG_VERSION) .

.PHONY: ci/deps
ci/deps:
	@docker build -t $(BUILDER_IMG_TAG) -f $(CURDIR)/build/Dockerfile $(CURDIR)

.PHONY: ci/validate
ci/validate: generate-keyring
	@git diff --name-only --exit-code gpg/keyrings/newrelic-infra-keyring.gpg \
		|| (echo "Keyring not up-to-date with the current keys, please run \
./scripts/generate_keyring.sh and commit the generated keyring."; exit 1)

.PHONY : ci/sign
ci/sign: ci/deps
	@docker run --rm -t \
			--name "infrastructure-public-keys" \
			-v $(CURDIR):/home/newrelic/infrastructure-public-keys \
            -w /home/newrelic/infrastructure-public-keys \
			-e GPG_MAIL \
			-e GPG_PASSPHRASE \
			-e GPG_PRIVATE_KEY_BASE64 \
			$(BUILDER_IMG_TAG) ./sign.sh
