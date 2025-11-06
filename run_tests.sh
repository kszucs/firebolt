#!/bin/bash
#
# Run tests, see https://forum.modular.com/t/proposal-deprecating-mojo-test/2371
set -e

# Get test directory from first argument, default to firebolt if not provided
test_dir="${1:-.}"

echo "### ------------------------------------------------------------- ###"
echo "Running tests in: $test_dir"

# Find all test files and run them
# Use a temporary file to track failures since pipe creates subshell
tmpfile=$(mktemp)
trap "rm -f $tmpfile" EXIT

find "$test_dir" -name "test_*.mojo" -type f -not -path "*/.pixi/*" | sort | while IFS= read -r test_file; do
  echo "Running: $test_file"
  if ! mojo run -I . "$test_file"; then
    echo "1" >"$tmpfile"
  fi
  echo "### ------------------------------------------------------------- ###"
done

# Check if any tests failed
if [ -f "$tmpfile" ] && [ -s "$tmpfile" ]; then
  exit 1
fi
