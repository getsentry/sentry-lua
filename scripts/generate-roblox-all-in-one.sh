#!/bin/bash
#
# Generate Roblox All-in-One Integration
#
# This script ensures the Roblox all-in-one file is ready for distribution.
# Currently, it validates the existing file since it's manually maintained
# with the proper SDK API integration.
#
# Usage: ./scripts/generate-roblox-all-in-one.sh
#

set -e

echo "🔨 Validating Roblox All-in-One Integration"
echo "=========================================="

OUTPUT_FILE="examples/roblox/sentry-all-in-one.lua"

# Check if the all-in-one file exists
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "❌ All-in-one file not found: $OUTPUT_FILE"
    echo "This file should exist and contain the Roblox integration."
    exit 1
fi

echo "✅ Found existing all-in-one file"

# Validate the file contains key components
if ! grep -q "sentry\.init" "$OUTPUT_FILE"; then
    echo "❌ File missing sentry.init function"
    exit 1
fi

if ! grep -q "sentry\.capture_message" "$OUTPUT_FILE"; then
    echo "❌ File missing sentry.capture_message function"  
    exit 1
fi

if ! grep -q "HttpService" "$OUTPUT_FILE"; then
    echo "❌ File missing Roblox HttpService integration"
    exit 1
fi

if ! grep -q "SENTRY_DSN" "$OUTPUT_FILE"; then
    echo "❌ File missing DSN configuration"
    exit 1
fi

echo "✅ All required components present"

# Get file size
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
FILE_SIZE_KB=$((FILE_SIZE / 1024))
echo "📊 File size: ${FILE_SIZE_KB} KB"

# Check if file has the proper header indicating it uses real SDK API
if grep -q "standard SDK API" "$OUTPUT_FILE"; then
    echo "✅ File uses standard SDK API"
else
    echo "⚠️ File may not use standard SDK API"
fi

echo ""
echo "🎉 Validation completed successfully!"
echo ""
echo "📋 The all-in-one file is ready for use:"
echo "  • Copy $OUTPUT_FILE into Roblox Studio"
echo "  • Update the SENTRY_DSN variable"
echo "  • Uses standard API: sentry.capture_message(), sentry.set_tag(), etc."
echo ""
echo "ℹ️ File is manually maintained to ensure Roblox compatibility"