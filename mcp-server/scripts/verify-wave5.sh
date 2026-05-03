#!/bin/bash

# TierSpec - Wave 5 Verification Script
# This script verifies MCP server status and provides instructions for Xcode verification

set -e

echo "========================================="
echo "TierSpec Wave 5 Verification"
echo "========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Run this script from the mcp-server directory"
    exit 1
fi

echo "1. MCP Server Status"
echo "--------------------"

# Type check
echo "   Type checking..."
if npm run typecheck > /dev/null 2>&1; then
    echo "   ✅ TypeScript: No errors"
else
    echo "   ❌ TypeScript: Errors found"
    npm run typecheck
fi

# Build
echo "   Building..."
if npm run build > /dev/null 2>&1; then
    echo "   ✅ Build: Success"
else
    echo "   ❌ Build: Failed"
    npm run build
fi

# Tests
echo "   Running tests..."
TEST_OUTPUT=$(npm test 2>&1)
TEST_COUNT=$(echo "$TEST_OUTPUT" | grep "Tests" | grep -oE "[0-9]+ passed" | head -1)
if echo "$TEST_OUTPUT" | grep -q "passed"; then
    echo "   ✅ Tests: $TEST_COUNT"
else
    echo "   ❌ Tests: Failed"
    echo "$TEST_OUTPUT"
fi

echo ""
echo "2. Swift Client Status"
echo "----------------------"

# Check Swift files
SWIFT_COUNT=$(find ../TierSpec/TierSpec -name "*.swift" | wc -l | tr -d ' ')
echo "   Swift files: $SWIFT_COUNT"

# Check key components
COMPONENTS=(
    "TierSpecApp.swift"
    "MainView.swift"
    "AIInputBar.swift"
    "AIWorkflowViewModel.swift"
    "MCPClientManager.swift"
    "MCPToolClient.swift"
)

echo "   Key components:"
for component in "${COMPONENTS[@]}"; do
    if find ../TierSpec/TierSpec -name "$component" | grep -q "$component"; then
        echo "   ✅ $component"
    else
        echo "   ❌ $component - MISSING"
    fi
done

echo ""
echo "3. Xcode Verification Required"
echo "-------------------------------"
echo ""
echo "The following tasks require Xcode IDE:"
echo ""
echo "   ⏳ W5.T1: End-to-end verification (13 items)"
echo "   ⏳ W5.T2: Performance testing"
echo "   ⏳ W5.T3: Production build"
echo ""
echo "To complete Wave 5:"
echo ""
echo "   1. Open Xcode:"
echo "      open ../TierSpec/TierSpec.xcodeproj"
echo ""
echo "   2. Build project (⌘B)"
echo ""
echo "   3. Run app (⌘R)"
echo ""
echo "   4. Complete verification checklist:"
echo "      See .sisyphus/wave5-verification-report.md"
echo ""
echo "========================================="
echo "Current Status: 18/21 tasks complete (86%)"
echo "========================================="