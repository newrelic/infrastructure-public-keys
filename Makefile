IMAGE_VERSION ?= dev
IMAGE_NAME = newrelic-infra-public-keys
PKG_VERSION ?= 0.0.0
BUILDER_IMG_TAG = infrastructure-public-keys-builder

.PHONY: clean
clean:
	@rm -f pkg/*.deb

.PHONY: build-container
build-container:
	@docker build -t $(IMAGE_NAME):$(IMAGE_VERSION) .


.PHONY: build
build: clean build-container
	@docker run -v $(CURDIR)/pkg:/fpm/pkg $(IMAGE_NAME):$(IMAGE_VERSION) --version $(PKG_VERSION) .

.PHONY: ci/deps
ci/deps:
	@docker build -t $(BUILDER_IMG_TAG) -f $(CURDIR)/build/Dockerfile $(CURDIR)

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
