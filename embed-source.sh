#!/bin/bash
# embed-source.sh - Embed libmygramclient source code
#
# This script copies the necessary source files from MygramDB into the
# Perl module so it can be built standalone without requiring MygramDB
# to be installed.
#
# Usage:
#   ./embed-source.sh [mygram-db-path]
#
# Example:
#   ./embed-source.sh ../mygram-db

set -e

MYGRAM_DB_PATH="${1:-../mygram-db}"
SRC_DIR="src"

echo "========================================="
echo "Embedding libmygramclient source"
echo "========================================="
echo "Source: $MYGRAM_DB_PATH"
echo "Target: $SRC_DIR"
echo ""

# Check if source exists
if [ ! -d "$MYGRAM_DB_PATH" ]; then
    echo "Error: MygramDB source directory not found: $MYGRAM_DB_PATH"
    echo ""
    echo "Usage: $0 [mygram-db-path]"
    exit 1
fi

if [ ! -d "$MYGRAM_DB_PATH/src/client" ]; then
    echo "Error: MygramDB client source not found: $MYGRAM_DB_PATH/src/client"
    exit 1
fi

# Create directory
echo "Creating source directory..."
mkdir -p "$SRC_DIR/mygramdb"

# Copy client source files
echo "Copying client source files..."
cp "$MYGRAM_DB_PATH/src/client/mygramclient.h" "$SRC_DIR/mygramdb/"
cp "$MYGRAM_DB_PATH/src/client/mygramclient.cpp" "$SRC_DIR/"
cp "$MYGRAM_DB_PATH/src/client/mygramclient_c.h" "$SRC_DIR/mygramdb/"
cp "$MYGRAM_DB_PATH/src/client/mygramclient_c.cpp" "$SRC_DIR/"
cp "$MYGRAM_DB_PATH/src/client/search_expression.h" "$SRC_DIR/mygramdb/"
cp "$MYGRAM_DB_PATH/src/client/search_expression.cpp" "$SRC_DIR/"
echo "  Copied client source files"

# Copy utility headers and sources
echo "Copying utility files..."
mkdir -p "$SRC_DIR/utils"
cp "$MYGRAM_DB_PATH/src/utils/error.h" "$SRC_DIR/utils/"
cp "$MYGRAM_DB_PATH/src/utils/expected.h" "$SRC_DIR/utils/"
cp "$MYGRAM_DB_PATH/src/utils/string_utils.h" "$SRC_DIR/utils/"
cp "$MYGRAM_DB_PATH/src/utils/string_utils.cpp" "$SRC_DIR/"
cp "$MYGRAM_DB_PATH/src/utils/network_utils.h" "$SRC_DIR/utils/"
cp "$MYGRAM_DB_PATH/src/utils/network_utils.cpp" "$SRC_DIR/"
echo "  Copied utility files"

# Verify embedded files
echo ""
echo "Verifying embedded files..."
REQUIRED_FILES=(
    "$SRC_DIR/mygramdb/mygramclient.h"
    "$SRC_DIR/mygramclient.cpp"
    "$SRC_DIR/mygramdb/mygramclient_c.h"
    "$SRC_DIR/mygramclient_c.cpp"
    "$SRC_DIR/mygramdb/search_expression.h"
    "$SRC_DIR/search_expression.cpp"
    "$SRC_DIR/utils/error.h"
    "$SRC_DIR/utils/expected.h"
    "$SRC_DIR/utils/string_utils.h"
    "$SRC_DIR/string_utils.cpp"
    "$SRC_DIR/utils/network_utils.h"
    "$SRC_DIR/network_utils.cpp"
)

ALL_FOUND=1
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
        ALL_FOUND=0
    fi
done

if [ $ALL_FOUND -eq 0 ]; then
    echo ""
    echo "Error: Some required files are missing!"
    exit 1
fi

echo ""
echo "========================================="
echo "Embed complete!"
echo "========================================="
echo ""
echo "Files embedded:"
find "$SRC_DIR" -type f | wc -l | awk '{print "  " $1 " files"}'
echo ""
echo "Next steps:"
echo "  perl Makefile.PL    # Should detect embedded source"
echo "  make"
echo "  make test"
echo ""
echo "To create a standalone distribution:"
echo "  make dist"
echo ""
echo "The resulting tarball will be completely self-contained"
echo "and can be built without MygramDB installed."
echo ""
