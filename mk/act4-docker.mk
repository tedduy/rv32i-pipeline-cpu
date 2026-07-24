# Dedicated ACT4 environment using the official RISC-V image.

ACT4_IMAGE ?= ghcr.io/riscv/act4-build:act4
ACT4_SOURCE_DIR ?= $(CURDIR)/.tools/act4-source
# Match the official image's Sail 0.12 toolchain. Newer ACT4 source revisions
# require Sail 0.13 and are not compatible with this published image.
ACT4_REV ?= 31b41cccdf01398ed72d1a6c788189a2b34544c6
ACT4_DOCKER_WORK_DIR ?= $(CURDIR)/.act4-work

.PHONY: act4-pull act4-source mount-act4 act4-generate-container act4-test

act4-pull:
	@$(DOCKER) pull "$(ACT4_IMAGE)"

act4-source:
	@if [ ! -d "$(ACT4_SOURCE_DIR)/.git" ]; then \
		mkdir -p "$(dir $(ACT4_SOURCE_DIR))"; \
		git clone https://github.com/riscv/riscv-arch-test.git \
			"$(ACT4_SOURCE_DIR)"; \
	fi
	@git -C "$(ACT4_SOURCE_DIR)" cat-file -e \
		"$(ACT4_REV)^{commit}" 2>/dev/null || \
		git -C "$(ACT4_SOURCE_DIR)" fetch --quiet origin "$(ACT4_REV)"
	@git -C "$(ACT4_SOURCE_DIR)" checkout --quiet --detach "$(ACT4_REV)"

mount-act4: act4-pull act4-source
	@mkdir -p "$(ACT4_DOCKER_WORK_DIR)"
	@$(DOCKER) run --rm -it \
		-v "$(CURDIR):/workspace" \
		-v "$(ACT4_SOURCE_DIR):/act4" \
		-w /workspace \
		-e ACT_ROOT=/act4 \
		-e ACT_WORK_DIR=/workspace/.act4-work \
		-e ACT_USE_SYSTEM_TOOLS=1 \
		"$(ACT4_IMAGE)" \
		bash -lc 'mkdir -p /tmp/tdrv32-act-bin; \
			ln -sf "$$(command -v riscv64-unknown-elf-gcc)" \
				/tmp/tdrv32-act-bin/riscv32-none-elf-gcc; \
			ln -sf "$$(command -v riscv64-unknown-elf-objdump)" \
				/tmp/tdrv32-act-bin/riscv32-none-elf-objdump; \
			export PATH="/tmp/tdrv32-act-bin:$$PATH"; \
			exec bash'

act4-generate-container: act4-pull act4-source
	@mkdir -p "$(ACT4_DOCKER_WORK_DIR)"
	@$(DOCKER) run --rm \
		-v "$(CURDIR):/workspace" \
		-v "$(ACT4_SOURCE_DIR):/act4" \
		-w /workspace \
		-e ACT_ROOT=/act4 \
		-e ACT_WORK_DIR=/workspace/.act4-work \
		-e ACT_USE_SYSTEM_TOOLS=1 \
		"$(ACT4_IMAGE)" \
		bash -lc 'mkdir -p /tmp/tdrv32-act-bin; \
			ln -sf "$$(command -v riscv64-unknown-elf-gcc)" \
				/tmp/tdrv32-act-bin/riscv32-none-elf-gcc; \
			ln -sf "$$(command -v riscv64-unknown-elf-objdump)" \
				/tmp/tdrv32-act-bin/riscv32-none-elf-objdump; \
			export PATH="/tmp/tdrv32-act-bin:$$PATH"; \
			make act-generate'

# Generate with the official ACT4 image, then execute only the resulting ACT4
# ELFs with the TDRV32 simulation image.
act4-test: act4-generate-container
	@$(DOCKER) pull "$(CI_IMAGE)"
	@$(DOCKER) run --rm \
		-v "$(CURDIR):/workspace" \
		-w /workspace \
		"$(CI_IMAGE)" make act-regression \
			ACT_WORK_DIR=/workspace/.act4-work
