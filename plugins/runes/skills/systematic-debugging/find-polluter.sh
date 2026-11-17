#!/usr/bin/env bash
# Bisection script to find which test creates unwanted files/state
# Usage: ./find-polluter.sh <file_or_dir_to_check> <test_pattern>
# Example: ./find-polluter.sh '.git' 'src/**/*.test.ts'
#
# Run from the project root. The pattern is matched against paths below the
# current directory, with or without a leading "./". As in a shell glob,
# "**/" matches zero or more directories.
# Exit codes: 0 = no polluter, 1 = polluter found, 2 = nothing could be tested.

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <file_to_check> <test_pattern>"
  echo "Example: $0 '.git' 'src/**/*.test.ts'"
  exit 1
fi

POLLUTION_CHECK="$1"
TEST_PATTERN="${2#./}"  # find prints paths as ./...; accept the pattern either way

echo "🔍 Searching for test that creates: $POLLUTION_CHECK"
echo "Test pattern: $TEST_PATTERN"
echo ""

# Every test would be skipped, and the run would wrongly report "clean".
if [ -e "$POLLUTION_CHECK" ]; then
  echo "❌ $POLLUTION_CHECK already exists. Remove it, then run again." >&2
  exit 2
fi

# In `find -path`, `*` also matches "/", so "**/" alone would require at least
# one directory. Matching the pattern with "**/" removed as well covers zero.
TEST_FILES=$(find . \( -path "./$TEST_PATTERN" -o -path "./${TEST_PATTERN//\*\*\//}" \) | sort -u)
if [ -z "$TEST_FILES" ]; then
  echo "❌ No test files match: ./$TEST_PATTERN" >&2
  exit 2
fi
TOTAL=$(printf '%s\n' "$TEST_FILES" | wc -l | tr -d ' ')

echo "Found $TOTAL test files"
echo ""

COUNT=0
for TEST_FILE in $TEST_FILES; do
  COUNT=$((COUNT + 1))
  echo "[$COUNT/$TOTAL] Testing: $TEST_FILE"

  # Run the test
  npm test "$TEST_FILE" > /dev/null 2>&1 || true

  # Check if pollution appeared
  if [ -e "$POLLUTION_CHECK" ]; then
    echo ""
    echo "🎯 FOUND POLLUTER!"
    echo "   Test: $TEST_FILE"
    echo "   Created: $POLLUTION_CHECK"
    echo ""
    echo "Pollution details:"
    ls -la "$POLLUTION_CHECK"
    echo ""
    echo "To investigate:"
    echo "  npm test $TEST_FILE    # Run just this test"
    echo "  cat $TEST_FILE         # Review test code"
    exit 1
  fi
done

echo ""
echo "✅ No polluter found - all tests clean!"
exit 0
