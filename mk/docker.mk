# Interactive development shell using the published CI tool image.

DOCKER ?= docker
CI_IMAGE ?= ghcr.io/tedduy/tdrv32:ci-main

.PHONY: mount

mount:
	@$(DOCKER) pull "$(CI_IMAGE)"
	@$(DOCKER) run --rm -it \
		-v "$(CURDIR):/workspace" \
		-w /workspace \
		"$(CI_IMAGE)" bash
