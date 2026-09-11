# ==============================================================================
# macharden - Makefile
# Automated build, test, lint, install, and audit targets
# ==============================================================================

SHELL := /bin/bash
PREFIX ?= /usr/local
USER_PREFIX ?= $(HOME)/.local
BIN_NAME := macharden
PROJECT_DIR := $(shell pwd)
EXEC_SOURCE := $(PROJECT_DIR)/bin/$(BIN_NAME)

.PHONY: all test lint scan install uninstall clean help

# Default target
all: test

# Run full test runner (syntax verification and unit test suite)
test:
	@chmod +x bin/macharden tests/test_runner.sh tests/test_checks.sh
	@./tests/test_runner.sh

# Run shell linters (ShellCheck and syntax check)
lint:
	@echo "Running ShellCheck linting..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck --severity=error bin/macharden lib/*.sh tests/*.sh; \
		echo "ShellCheck completed successfully."; \
	else \
		echo "Notice: shellcheck not installed. Run 'brew install shellcheck' for static analysis."; \
	fi
	@echo "Checking syntax with zsh -n and bash -n..."
	@for f in bin/macharden lib/*.sh tests/*.sh; do \
		zsh -n "$$f" || exit 1; \
		bash -n "$$f" || exit 1; \
	done
	@echo "All shell scripts passed syntax checks."

# Execute live security audit scan on current macOS host
scan:
	@chmod +x bin/macharden
	@./bin/macharden

# Install symlink to system or user bin directory
install:
	@chmod +x $(EXEC_SOURCE)
	@if [ -w "$(PREFIX)/bin" ]; then \
		mkdir -p "$(PREFIX)/bin"; \
		ln -sf "$(EXEC_SOURCE)" "$(PREFIX)/bin/$(BIN_NAME)"; \
		echo "Installed symlink: $(PREFIX)/bin/$(BIN_NAME) -> $(EXEC_SOURCE)"; \
	else \
		mkdir -p "$(USER_PREFIX)/bin"; \
		ln -sf "$(EXEC_SOURCE)" "$(USER_PREFIX)/bin/$(BIN_NAME)"; \
		echo "Installed symlink: $(USER_PREFIX)/bin/$(BIN_NAME) -> $(EXEC_SOURCE)"; \
		echo "Ensure $(USER_PREFIX)/bin is in your PATH: export PATH=\"$(USER_PREFIX)/bin:\$$PATH\""; \
	fi

# Remove installed symlink
uninstall:
	@rm -f "$(PREFIX)/bin/$(BIN_NAME)" "$(USER_PREFIX)/bin/$(BIN_NAME)"
	@echo "Uninstalled $(BIN_NAME) symlinks."

# Clean generated reports and temporary files
clean:
	@rm -f report.json report.md report.txt report_*.json report_*.md report_*.txt
	@rm -f fix_hardening.sh macharden_remediation_*.sh test_fix.sh test_remediation.sh
	@rm -rf .tmp .test_tmp .runtime tmp
	@echo "Cleaned report and temporary files."

# Display help information
help:
	@echo "macharden Makefile targets:"
	@echo "  make test      - Run automated unit test suite and shell syntax checks"
	@echo "  make lint      - Run ShellCheck and syntax validation"
	@echo "  make scan      - Run macharden security audit on local macOS host"
	@echo "  make install   - Install symlink to $(PREFIX)/bin or $(USER_PREFIX)/bin"
	@echo "  make uninstall - Remove installed symlink"
	@echo "  make clean     - Clean generated reports and fix scripts"
