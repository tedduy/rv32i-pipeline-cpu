# OpenLane 2 ASIC implementation environment.

OPENLANE_IMAGE ?= ghcr.io/efabless/openlane2:2.3.10
OPENLANE_PDK_VOLUME ?= tdrv32-openlane-pdk

.PHONY: mount-openlane openlane-pull

openlane-pull:
	@$(DOCKER) pull "$(OPENLANE_IMAGE)"

mount-openlane: openlane-pull
	@$(DOCKER) run --rm -it \
		--entrypoint bash \
		-v "$(CURDIR):/workspace" \
		-v "$(OPENLANE_PDK_VOLUME):/pdk" \
		-e PDK_ROOT=/pdk \
		-w /workspace \
		"$(OPENLANE_IMAGE)"
