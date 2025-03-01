#!/bin/bash

# Benchmark script for comparing original and component-based validator implementations
# This script helps with running tests and benchmarking the two implementations

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print section header
print_header() {
  echo -e "\n${YELLOW}==== $1 ====${NC}\n"
}

# Function to run tests
run_tests() {
  print_header "Running Tests"
  
  echo -e "${GREEN}Running original validator tests...${NC}"
  swift test --filter "ValidatorTests"
  
  echo -e "\n${GREEN}Running component-based validator tests...${NC}"
  swift test --filter "ValidatorV2Tests"
}

# Function to run benchmarks
run_benchmarks() {
  print_header "Running Benchmarks"
  
  # Create benchmark directory if it doesn't exist
  mkdir -p benchmarks
  
  # Run original validator benchmark
  echo -e "${GREEN}Benchmarking original validator...${NC}"
  swift run -c release BenchmarkTool --validator original > benchmarks/original_results.txt
  
  # Run component-based validator benchmark
  echo -e "${GREEN}Benchmarking component-based validator...${NC}"
  swift run -c release BenchmarkTool --validator component > benchmarks/component_results.txt
  
  # Compare results
  echo -e "\n${GREEN}Benchmark Results:${NC}"
  echo -e "${YELLOW}Original Validator:${NC}"
  cat benchmarks/original_results.txt
  
  echo -e "\n${YELLOW}Component-Based Validator:${NC}"
  cat benchmarks/component_results.txt
}

# Function to run validation comparison
run_validation_comparison() {
  print_header "Validation Comparison"
  
  echo -e "${GREEN}Comparing validation results...${NC}"
  swift run -c release ValidationComparisonTool
}

# Main script
case "$1" in
  "tests")
    run_tests
    ;;
  "benchmarks")
    run_benchmarks
    ;;
  "compare")
    run_validation_comparison
    ;;
  *)
    print_header "Validator Benchmark Tool"
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  tests      Run tests for both validator implementations"
    echo "  benchmarks Run performance benchmarks"
    echo "  compare    Compare validation results between implementations"
    echo ""
    echo "Example: $0 benchmarks"
    ;;
esac

# Note: You'll need to create the BenchmarkTool and ValidationComparisonTool
# executables to use the benchmarks and compare commands. 