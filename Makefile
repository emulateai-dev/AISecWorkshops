# AISecWorkshops — PyRIT submodule helpers
#
# After clone: run `make init` (or `make`) to fetch the PyRIT submodule.
# To pull upstream PyRIT changes with merge: `make merge`

PYRIT_SUBMODULE := labs/setup/pyrit/PyRIT

.PHONY: help init merge submodule-init submodule-merge all

help:
	@echo "AISecWorkshops Makefile"
	@echo ""
	@echo "  make / make init   Initialize and checkout git submodules (PyRIT)"
	@echo "  make merge         Update PyRIT submodule from remote with merge"
	@echo ""
	@echo "Submodule path: $(PYRIT_SUBMODULE)"

# Default: same as init
all: init

init: submodule-init

submodule-init:
	git submodule update --init --recursive

merge: submodule-merge

submodule-merge:
	git submodule update --remote --merge $(PYRIT_SUBMODULE)
