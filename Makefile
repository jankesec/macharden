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

# Documentation and Shell Completion Paths
MANDIR ?= $(PREFIX)/share/man/man1
USER_MANDIR ?= $(USER_PREFIX)/share/man/man1
ZSH_COMP_DIR ?= $(PREFIX)/share/zsh/site-functions
USER_ZSH_COMP_DIR ?= $(USER_PREFIX)/share/zsh/site-functions
BASH_COMP_DIR ?= $(PREFIX)/share/bash-completion/completions
USER_BASH_COMP_DIR ?= $(USER_PREFIX)/share/bash-completion/completions

.PHONY: all test lint scan install install-bin install-completions install-man uninstall clean help

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
	@echo "Checking completion script syntax..."
	@zsh -n completions/macharden.zsh
	@bash -n completions/macharden.bash
	@echo "Validating manual page formatting..."
	@if command -v mandoc >/dev/null 2>&1; then \
		mandoc -Tlint docs/macharden.1; \
	fi
	@echo "All shell scripts and documentation passed validation checks."

# Execute live security audit scan on current macOS host
scan:
	@chmod +x bin/macharden
	@./bin/macharden

# Install binary symlink to system or user bin directory
install-bin:
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

# Install shell completions for Zsh and Bash
install-completions:
	@echo "Installing shell completions..."
	@if [ -w "$$(dirname "$(ZSH_COMP_DIR)")" ] || ([ -d "$(ZSH_COMP_DIR)" ] && [ -w "$(ZSH_COMP_DIR)" ]); then \
		mkdir -p "$(ZSH_COMP_DIR)"; \
		cp -f completions/macharden.zsh "$(ZSH_COMP_DIR)/_macharden"; \
		chmod 644 "$(ZSH_COMP_DIR)/_macharden"; \
		echo "Installed Zsh completion: $(ZSH_COMP_DIR)/_macharden"; \
	else \
		mkdir -p "$(USER_ZSH_COMP_DIR)"; \
		cp -f completions/macharden.zsh "$(USER_ZSH_COMP_DIR)/_macharden"; \
		chmod 644 "$(USER_ZSH_COMP_DIR)/_macharden"; \
		echo "Installed Zsh completion: $(USER_ZSH_COMP_DIR)/_macharden"; \
		echo "Ensure $(USER_ZSH_COMP_DIR) is in your fpath: fpath=($(USER_ZSH_COMP_DIR) \$$fpath)"; \
	fi
	@if [ -w "$$(dirname "$(BASH_COMP_DIR)")" ] || ([ -d "$(BASH_COMP_DIR)" ] && [ -w "$(BASH_COMP_DIR)" ]); then \
		mkdir -p "$(BASH_COMP_DIR)"; \
		cp -f completions/macharden.bash "$(BASH_COMP_DIR)/macharden"; \
		chmod 644 "$(BASH_COMP_DIR)/macharden"; \
		echo "Installed Bash completion: $(BASH_COMP_DIR)/macharden"; \
	else \
		mkdir -p "$(USER_BASH_COMP_DIR)"; \
		cp -f completions/macharden.bash "$(USER_BASH_COMP_DIR)/macharden"; \
		chmod 644 "$(USER_BASH_COMP_DIR)/macharden"; \
		echo "Installed Bash completion: $(USER_BASH_COMP_DIR)/macharden"; \
	fi

# Install UNIX manual page (groff man format)
install-man:
	@echo "Installing manual page..."
	@if [ -w "$$(dirname "$(MANDIR)")" ] || ([ -d "$(MANDIR)" ] && [ -w "$(MANDIR)" ]); then \
		mkdir -p "$(MANDIR)"; \
		cp -f docs/macharden.1 "$(MANDIR)/macharden.1"; \
		chmod 644 "$(MANDIR)/macharden.1"; \
		echo "Installed man page: $(MANDIR)/macharden.1"; \
	else \
		mkdir -p "$(USER_MANDIR)"; \
		cp -f docs/macharden.1 "$(USER_MANDIR)/macharden.1"; \
		chmod 644 "$(USER_MANDIR)/macharden.1"; \
		echo "Installed man page: $(USER_MANDIR)/macharden.1"; \
		echo "Ensure $(USER_PREFIX)/share/man is in your MANPATH"; \
	fi

# Install all components (binary, completions, man page)
install: install-bin install-completions install-man
	@echo "macharden installation complete."

# Remove installed symlink, completions, and manual pages
uninstall:
	@rm -f "$(PREFIX)/bin/$(BIN_NAME)" "$(USER_PREFIX)/bin/$(BIN_NAME)"
	@rm -f "$(ZSH_COMP_DIR)/_macharden" "$(USER_ZSH_COMP_DIR)/_macharden"
	@rm -f "$(BASH_COMP_DIR)/macharden" "$(USER_BASH_COMP_DIR)/macharden"
	@rm -f "$(MANDIR)/macharden.1" "$(USER_MANDIR)/macharden.1"
	@echo "Uninstalled $(BIN_NAME) binary, completions, and man pages."

# Clean generated reports and temporary files
clean:
	@rm -f report.json report.md report.txt report.html report.sarif report_*.json report_*.md report_*.txt report_*.sarif macharden-report.sarif
	@rm -f fix_hardening.sh macharden_remediation_*.sh test_fix.sh test_remediation.sh
	@rm -rf .tmp .test_tmp .runtime tmp
	@echo "Cleaned report and temporary files."

# Display help information
help:
	@echo "macharden Makefile targets:"
	@echo "  make test                - Run automated unit test suite and shell syntax checks"
	@echo "  make lint                - Run ShellCheck and syntax validation"
	@echo "  make scan                - Run macharden security audit on local macOS host"
	@echo "  make install             - Install binary, shell completions, and man page"
	@echo "  make install-bin         - Install symlink to $(PREFIX)/bin or $(USER_PREFIX)/bin"
	@echo "  make install-completions - Install Zsh and Bash shell autocompletions"
	@echo "  make install-man         - Install UNIX manual page (macharden.1)"
	@echo "  make uninstall           - Remove installed symlink, completions, and man pages"
	@echo "  make clean               - Clean generated reports and fix scripts"
