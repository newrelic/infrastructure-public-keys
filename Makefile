IMAGE_VERSION ?= dev
IMAGE_NAME = newrelic-infra-public-keys
PKG_VERSION ?= 0.0.0
BUILDER_IMG_TAG = infrastructure-public-keys-builder

gpg/keyrings/newrelic-infra-keyring.gpg: gpg/keys/current/newrelic* gpg/keys/next/newrelic*
	./scripts/generate_keyring.sh gpg/keys/current/newrelic* gpg/keys/next/newrelic*

.PHONY: clean
clean:
	@rm -f pkg/*.deb

.PHONY: generate-keyring
generate-keyring: gpg/keyrings/newrelic-infra-keyring.gpg

.PHONY: build-container
build-container:
	@docker build -t $(IMAGE_NAME):$(IMAGE_VERSION) .


.PHONY: build
build: clean generate-keyring build-container
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
