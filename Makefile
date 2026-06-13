# Pureflow Makefile

# Resolve the Dart executable. Prefers the fvm-pinned SDK, then fvm, then PATH.
DART ?= $(shell \
	if [ -x "$(CURDIR)/.fvm/flutter_sdk/bin/dart" ]; then echo "$(CURDIR)/.fvm/flutter_sdk/bin/dart"; \
	elif command -v fvm >/dev/null 2>&1; then echo "fvm dart"; \
	else echo dart; fi)

BENCHMARK_DIR := benchmark
BENCHMARK_ENTRY := $(BENCHMARK_DIR)/bin/run_benchmarks.dart

.PHONY: help benchmark benchmark-deps

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

benchmark-deps: ## Fetch benchmark dependencies
	cd $(BENCHMARK_DIR) && $(DART) pub get

benchmark: benchmark-deps ## Run all benchmarks and regenerate BENCHMARK_README.md
	$(DART) run $(BENCHMARK_ENTRY)
