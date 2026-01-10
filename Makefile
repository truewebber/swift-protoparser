.PHONY: test format lint coverage

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
	swift test --enable-code-coverage --parallel --disable-swift-testing
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
