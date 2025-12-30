#!/bin/bash
# Nexus Protocol - Slither Analysis Script

set -e

CONTRACTS_DIR="../../contracts"
OUTPUT_DIR="./reports"
CONFIG_FILE="./slither.config.json"

mkdir -p "$OUTPUT_DIR"

echo "=== Nexus Protocol - Slither Security Analysis ==="
echo ""

# Change to contracts directory
cd "$CONTRACTS_DIR"

# Run slither with different output formats
echo "Running Slither analysis..."

# Human-readable output
echo "Generating human-readable report..."
slither . --config-file ../security/slither/slither.config.json \
  > ../security/slither/reports/slither-report.txt 2>&1 || true

# JSON output for CI/CD integration
echo "Generating JSON report..."
slither . --config-file ../security/slither/slither.config.json \
  --json ../security/slither/reports/slither-report.json 2>/dev/null || true

# Markdown output for documentation
echo "Generating Markdown report..."
slither . --config-file ../security/slither/slither.config.json \
  --checklist --markdown-root . \
  > ../security/slither/reports/slither-checklist.md 2>&1 || true

# Function summary
echo "Generating function summary..."
slither . --config-file ../security/slither/slither.config.json \
  --print human-summary \
  > ../security/slither/reports/human-summary.txt 2>&1 || true

# Contract summary
echo "Generating contract summary..."
slither . --config-file ../security/slither/slither.config.json \
  --print contract-summary \
  > ../security/slither/reports/contract-summary.txt 2>&1 || true

# Inheritance graph
echo "Generating inheritance graph..."
slither . --config-file ../security/slither/slither.config.json \
  --print inheritance-graph \
  > ../security/slither/reports/inheritance.dot 2>&1 || true

# Call graph
echo "Generating call graph..."
slither . --config-file ../security/slither/slither.config.json \
  --print call-graph \
  > ../security/slither/reports/call-graph.dot 2>&1 || true

echo ""
echo "=== Analysis Complete ==="
echo "Reports generated in: $OUTPUT_DIR"
echo ""
echo "Files:"
ls -la ../security/slither/reports/
