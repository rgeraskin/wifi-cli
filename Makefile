.PHONY: install uninstall test help

PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
INSTALL_PATH = $(BINDIR)/wifi-cli

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

install: ## Install wifi-cli to $(BINDIR)
	@echo "Installing wifi-cli to $(INSTALL_PATH)..."
	@mkdir -p $(BINDIR)
	@install -m 755 wifi-cli.swift $(INSTALL_PATH)
	@echo "Installation complete!"
	@echo "You can now use 'wifi-cli' from anywhere"

uninstall: ## Uninstall wifi-cli from $(BINDIR)
	@echo "Uninstalling wifi-cli from $(INSTALL_PATH)..."
	@rm -f $(INSTALL_PATH)
	@echo "Uninstall complete!"

test: ## Run basic tests
	@echo "Running tests..."
	@echo "Testing help command..."
	@./wifi-cli.swift --help > /dev/null && echo "✓ Help command works" || echo "✗ Help command failed"
	@echo "Testing version command..."
	@./wifi-cli.swift --version > /dev/null && echo "✓ Version command works" || echo "✗ Version command failed"
	@echo "Testing power status command..."
	@./wifi-cli.swift power status > /dev/null && echo "✓ Power status command works" || echo "✗ Power status command failed"
	@echo "Testing mac command..."
	@./wifi-cli.swift mac > /dev/null && echo "✓ MAC command works" || echo "✗ MAC command failed"
	@echo "Testing scan command..."
	@./wifi-cli.swift scan > /dev/null && echo "✓ Scan command works" || echo "✗ Scan command failed"
	@echo "Test complete!"

