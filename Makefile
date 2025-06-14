# Swift ProtoParser Development Makefile

.PHONY: help build test clean format lint status

help: ## Show this help
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

lint:
	@echo "Running swift-format in lint mode..."
	swift format lint -s --configuration .swift-format.json --recursive ./
	@echo "Lint complete."

format:
	@echo "Running swift-format in format mode..."
	swift format --configuration .swift-format.json --recursive -i ./
	@echo "Format complete."

test:
	@echo "Running swift test..."
	swift test --enable-code-coverage --parallel
	@echo "Tests complete."

coverage:
	@echo "Generating code coverage report..."
	xcrun llvm-profdata merge -sparse .build/arm64-apple-macosx/debug/codecov/*.profraw -o .build/arm64-apple-macosx/debug/codecov/merged.profdata
	xcrun llvm-cov report \
		.build/arm64-apple-macosx/debug/SwiftProtoParserPackageTests.xctest/Contents/MacOS/SwiftProtoParserPackageTests \
		-instr-profile=.build/arm64-apple-macosx/debug/codecov/merged.profdata \
		-name-regex="^Sources/SwiftProtoParser/" \
		-ignore-filename-regex=".build|Tests|checkouts" \
		-use-color

status: ## Show current project status
	@echo "=== PROJECT STATUS ==="
	@cat PROJECT_STATUS.md

quick-ref: ## Show quick reference
	@echo "=== QUICK REFERENCE ==="
	@cat docs/QUICK_REFERENCE.md

# Development workflow shortcuts
start-session: status quick-ref ## Start new development session
	@echo "Ready to start development!"

end-session: ## End development session (update status)
