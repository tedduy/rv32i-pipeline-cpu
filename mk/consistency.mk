# Repository structure and single-source-of-truth checks.

.PHONY: consistency

consistency:
	@$(SYSTEM_PYTHON) scripts/check_project_consistency.py
