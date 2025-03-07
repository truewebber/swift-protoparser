#!/bin/bash

# Run tests with code coverage enabled
swift test --enable-code-coverage

# Generate code coverage report
xcrun llvm-cov export -format="lcov" \
  .build/debug/SwiftProtoParserPackageTests.xctest/Contents/MacOS/SwiftProtoParserPackageTests \
  -instr-profile .build/debug/codecov/default.profdata > coverage.lcov

# Generate HTML report if lcov is installed
if command -v lcov &> /dev/null; then
  lcov --summary coverage.lcov
  genhtml coverage.lcov --output-directory Tools/CodeCoverage/report
  echo "HTML report generated at Tools/CodeCoverage/report/index.html"
else
  echo "lcov not installed. Install with 'brew install lcov' to generate HTML reports."
fi

# Print summary
echo "Code coverage report generated at coverage.lcov" 