# AISecWorkshops — git submodule helpers (PyRIT, pyrit_cli)
#
# After clone: run `make submodules-init` (or `make`) to fetch submodules.
# To pull upstream changes with merge: `make submodules-update`

PYRIT_SUBMODULE := labs/setup/pyrit/PyRIT

.PHONY: help submodules-init submodules-update all

help:
	@echo "AISecWorkshops Makefile"
	@echo ""
	@echo "  make / make submodules-init   Initialize and checkout git submodules (PyRIT, pyrit_cli)"
	@echo "  make submodules-update        Update tracked-branch submodules from remote with merge"
	@echo ""
	@echo "Submodule paths: $(PYRIT_SUBMODULE), labs/setup/pyrit/pyrit_cli"

# Default: same as submodules-init
all: submodules-init

submodules-init:
	git submodule update --init --recursive

submodules-update:
	git submodule update --remote --merge
