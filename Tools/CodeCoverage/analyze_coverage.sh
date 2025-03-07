#!/bin/bash

# This script analyzes the test coverage report and identifies gaps in test coverage

# Check if coverage.lcov exists
if [ ! -f "coverage.lcov" ]; then
    echo "Error: coverage.lcov not found. Run run_coverage.sh first."
    exit 1
fi

# Check if lcov is installed
if ! command -v lcov &> /dev/null; then
    echo "Error: lcov not installed. Install with 'brew install lcov'."
    exit 1
fi

# Create output directory
mkdir -p Tools/CodeCoverage/analysis

# Generate summary report
lcov --summary coverage.lcov > Tools/CodeCoverage/analysis/summary.txt

# Extract coverage by component
echo "Extracting coverage by component..."

# Lexer
lcov --extract coverage.lcov "**/Lexer/*" --output-file Tools/CodeCoverage/analysis/lexer_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/lexer_coverage.lcov > Tools/CodeCoverage/analysis/lexer_summary.txt

# Parser
lcov --extract coverage.lcov "**/Parser/*" --output-file Tools/CodeCoverage/analysis/parser_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/parser_coverage.lcov > Tools/CodeCoverage/analysis/parser_summary.txt

# AST
lcov --extract coverage.lcov "**/AST/*" --output-file Tools/CodeCoverage/analysis/ast_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/ast_coverage.lcov > Tools/CodeCoverage/analysis/ast_summary.txt

# Validator
lcov --extract coverage.lcov "**/Validator/*" --output-file Tools/CodeCoverage/analysis/validator_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/validator_coverage.lcov > Tools/CodeCoverage/analysis/validator_summary.txt

# Symbol Resolution
lcov --extract coverage.lcov "**/Symbol*" --output-file Tools/CodeCoverage/analysis/symbol_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/symbol_coverage.lcov > Tools/CodeCoverage/analysis/symbol_summary.txt

# Import Resolution
lcov --extract coverage.lcov "**/Import*" --output-file Tools/CodeCoverage/analysis/import_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/import_coverage.lcov > Tools/CodeCoverage/analysis/import_summary.txt

# Descriptor Generation
lcov --extract coverage.lcov "**/Descriptor*" --output-file Tools/CodeCoverage/analysis/descriptor_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/descriptor_coverage.lcov > Tools/CodeCoverage/analysis/descriptor_summary.txt

# Source Info Generation
lcov --extract coverage.lcov "**/SourceInfo*" --output-file Tools/CodeCoverage/analysis/sourceinfo_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/sourceinfo_coverage.lcov > Tools/CodeCoverage/analysis/sourceinfo_summary.txt

# Configuration
lcov --extract coverage.lcov "**/Configuration*" --output-file Tools/CodeCoverage/analysis/configuration_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/configuration_coverage.lcov > Tools/CodeCoverage/analysis/configuration_summary.txt

# Public API
lcov --extract coverage.lcov "**/ProtoParser.swift" --output-file Tools/CodeCoverage/analysis/api_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/api_coverage.lcov > Tools/CodeCoverage/analysis/api_summary.txt

# Error Handling
lcov --extract coverage.lcov "**/*Error*" --output-file Tools/CodeCoverage/analysis/error_coverage.lcov
lcov --summary Tools/CodeCoverage/analysis/error_coverage.lcov > Tools/CodeCoverage/analysis/error_summary.txt

echo "Coverage analysis complete. Results are in Tools/CodeCoverage/analysis/"

# Generate HTML reports for each component
for component in lexer parser ast validator symbol import descriptor sourceinfo configuration api error; do
    genhtml Tools/CodeCoverage/analysis/${component}_coverage.lcov --output-directory Tools/CodeCoverage/analysis/${component}_report
    echo "HTML report for ${component} generated at Tools/CodeCoverage/analysis/${component}_report/index.html"
done

echo "All HTML reports generated." 