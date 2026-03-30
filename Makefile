# =============================================================================
# strings - Makefile
# Development shortcuts for the strings library
# =============================================================================

.PHONY: all build test test-all test-unit test-encoding test-unicode test-ops test-string test-integration
.PHONY: clean fmt fmt-check docs dev ci help
.PHONY: bench bench-parallel scale-bench bench-save bench-baseline bench-compare

# Default target
all: build test

# =============================================================================
# Build
# =============================================================================

build:
	zig build

build-release:
	zig build -Doptimize=ReleaseSafe

build-fast:
	zig build -Doptimize=ReleaseFast

build-small:
	zig build -Doptimize=ReleaseSmall

# =============================================================================
# Tests
# =============================================================================

test:
	zig build test --summary all

test-all:
	zig build test-all --summary all

test-unit:
	zig build test --summary all

test-encoding:
	zig build test-encoding --summary all

test-unicode:
	zig build test-unicode --summary all

test-ops:
	zig build test-ops --summary all

test-string:
	zig build test-string --summary all

test-integration:
	zig build test-integration --summary all

# Optimization-specific tests
test-debug:
	zig build test -Doptimize=Debug --summary all

test-release-safe:
	zig build test -Doptimize=ReleaseSafe --summary all

test-release-fast:
	zig build test -Doptimize=ReleaseFast --summary all

test-release-small:
	zig build test -Doptimize=ReleaseSmall --summary all

# =============================================================================
# Benchmarks
# =============================================================================

# Run quick benchmarks
bench:
	@echo "Running benchmarks..."
	@zig build bench -Doptimize=ReleaseFast

# Run parallel operations benchmark
bench-parallel:
	@echo "Running parallel benchmarks..."
	@zig build bench-parallel

# Incremental scale benchmark
scale-bench:
	@echo "Running incremental scale benchmark..."
	@zig build scale-bench 2>/dev/null

# Run scale bench and save results per commit
bench-save:
	@echo "Running scale benchmark and saving results..."
	@zig build scale-bench 2>/dev/null > benchmarks/results/$$(git rev-parse --short HEAD).json
	@echo "Saved to benchmarks/results/$$(git rev-parse --short HEAD).json"

# Save current results as the baseline
bench-baseline:
	@echo "Running scale benchmark and saving as baseline..."
	@zig build scale-bench 2>/dev/null > benchmarks/results/baseline.json
	@echo "Saved to benchmarks/results/baseline.json"

# Compare current results against baseline
bench-compare:
	@echo "Running scale benchmark and comparing against baseline..."
	@zig build scale-bench 2>/dev/null > /tmp/current-bench.json
	@zig build compare-bench -- benchmarks/results/baseline.json /tmp/current-bench.json

# =============================================================================
# Code Quality
# =============================================================================

fmt:
	zig fmt src/ tests/ bench/ examples/ build.zig

fmt-check:
	zig build fmt-check

# =============================================================================
# Documentation
# =============================================================================

docs:
	zig build docs

# =============================================================================
# Clean
# =============================================================================

clean:
	rm -rf zig-out .zig-cache

# =============================================================================
# Development Workflows
# =============================================================================

# Format + check + test
dev: fmt-check test

# Full CI pipeline locally
ci: fmt-check build test-all test-release-safe

# Quick check (format + build + unit tests only)
check: fmt-check build test-unit

# =============================================================================
# Cross-Compilation
# =============================================================================

cross-linux-arm64:
	zig build -Dtarget=aarch64-linux-gnu

cross-linux-arm:
	zig build -Dtarget=arm-linux-gnueabihf

cross-macos-arm64:
	zig build -Dtarget=aarch64-macos

cross-macos-x64:
	zig build -Dtarget=x86_64-macos

cross-windows-x64:
	zig build -Dtarget=x86_64-windows-gnu

cross-windows-arm64:
	zig build -Dtarget=aarch64-windows-gnu

cross-riscv64:
	zig build -Dtarget=riscv64-linux-gnu

cross-all: cross-linux-arm64 cross-linux-arm cross-macos-arm64 cross-macos-x64 cross-windows-x64 cross-windows-arm64 cross-riscv64

# =============================================================================
# Help
# =============================================================================

help:
	@echo "strings - Comprehensive string manipulation library for Zig"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build targets:"
	@echo "  build          Build the library (default debug)"
	@echo "  build-release  Build with ReleaseSafe optimization"
	@echo "  build-fast     Build with ReleaseFast optimization"
	@echo "  build-small    Build with ReleaseSmall optimization"
	@echo ""
	@echo "Test targets:"
	@echo "  test           Run unit tests"
	@echo "  test-all       Run all tests"
	@echo "  test-encoding  Run encoding tests"
	@echo "  test-unicode   Run Unicode tests"
	@echo "  test-ops       Run operations tests"
	@echo "  test-string    Run string type tests"
	@echo "  test-integration Run integration tests"
	@echo ""
	@echo "Benchmark targets:"
	@echo "  bench           Run quick benchmarks (ReleaseFast)"
	@echo "  bench-parallel  Run parallel operations benchmark"
	@echo "  scale-bench     Run incremental scale benchmark"
	@echo "  bench-save      Run scale bench, save to results/<sha>.json"
	@echo "  bench-baseline  Run scale bench, save as baseline"
	@echo "  bench-compare   Run scale bench, compare against baseline"
	@echo ""
	@echo "Quality targets:"
	@echo "  fmt            Format all source files"
	@echo "  fmt-check      Check formatting"
	@echo "  docs           Generate documentation"
	@echo ""
	@echo "Development targets:"
	@echo "  dev            Format check + test"
	@echo "  ci             Full CI pipeline"
	@echo "  check          Quick check (format + build + unit)"
	@echo "  clean          Remove build artifacts"
	@echo ""
	@echo "Cross-compilation targets:"
	@echo "  cross-linux-arm64   Build for Linux ARM64"
	@echo "  cross-macos-arm64   Build for macOS ARM64"
	@echo "  cross-windows-x64   Build for Windows x64"
	@echo "  cross-all           Build for all platforms"
	@echo ""
	@echo "Run 'make help' to see this message"
