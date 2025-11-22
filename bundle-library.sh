#!/bin/bash
# bundle-library.sh - Bundle libmygramclient with Perl module
#
# Usage:
#   ./bundle-library.sh [mygram-db-path]
#
# Example:
#   ./bundle-library.sh ../mygram-db

set -e

MYGRAM_DB_PATH="${1:-../mygram-db}"
VENDOR_DIR="vendor"

echo "========================================="
echo "Bundling libmygramclient"
echo "========================================="
echo "Source: $MYGRAM_DB_PATH"
echo "Target: $VENDOR_DIR"
echo ""

# Check if source exists
if [ ! -d "$MYGRAM_DB_PATH" ]; then
    echo "Error: MygramDB source directory not found: $MYGRAM_DB_PATH"
    echo ""
    echo "Usage: $0 [mygram-db-path]"
    exit 1
fi

# Create directories
echo "Creating vendor directories..."
mkdir -p "$VENDOR_DIR/lib" "$VENDOR_DIR/include/mygramdb"

# Copy headers
echo "Copying headers..."
if [ -d "$MYGRAM_DB_PATH/src/client" ]; then
    # From source tree
    cp "$MYGRAM_DB_PATH/src/client/"*.h "$VENDOR_DIR/include/mygramdb/" 2>/dev/null || true
    echo "  Copied from source: $MYGRAM_DB_PATH/src/client/*.h"
fi

if [ -d "/usr/local/include/mygramdb" ]; then
    # From installation
    cp /usr/local/include/mygramdb/*.h "$VENDOR_DIR/include/mygramdb/" 2>/dev/null || true
    echo "  Copied from installation: /usr/local/include/mygramdb/*.h"
fi

# Copy library files
echo "Copying library files..."
FOUND_LIB=0

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "  Platform: macOS"

    # Try build directory first
    if [ -f "$MYGRAM_DB_PATH/build/lib/libmygramclient.a" ]; then
        cp "$MYGRAM_DB_PATH/build/lib/libmygramclient.a" "$VENDOR_DIR/lib/"
        echo "    Copied: libmygramclient.a (from build)"
        FOUND_LIB=1
    fi

    if [ -f "$MYGRAM_DB_PATH/build/lib/libmygramclient.dylib" ]; then
        cp "$MYGRAM_DB_PATH/build/lib/libmygramclient.dylib" "$VENDOR_DIR/lib/"
        echo "    Copied: libmygramclient.dylib (from build)"
        FOUND_LIB=1
    fi

    # Try system installation
    if [ -f "/usr/local/lib/libmygramclient.a" ]; then
        cp /usr/local/lib/libmygramclient.a "$VENDOR_DIR/lib/"
        echo "    Copied: libmygramclient.a (from /usr/local)"
        FOUND_LIB=1
    fi

    if [ -f "/usr/local/lib/libmygramclient.dylib" ]; then
        cp /usr/local/lib/libmygramclient.dylib "$VENDOR_DIR/lib/"
        echo "    Copied: libmygramclient.dylib (from /usr/local)"
        FOUND_LIB=1
    fi
else
    # Linux
    echo "  Platform: Linux"

    # Try build directory first
    if [ -f "$MYGRAM_DB_PATH/build/lib/libmygramclient.a" ]; then
        cp "$MYGRAM_DB_PATH/build/lib/libmygramclient.a" "$VENDOR_DIR/lib/"
        echo "    Copied: libmygramclient.a (from build)"
        FOUND_LIB=1
    fi

    if ls "$MYGRAM_DB_PATH/build/lib/libmygramclient.so"* 1> /dev/null 2>&1; then
        cp "$MYGRAM_DB_PATH/build/lib/libmygramclient.so"* "$VENDOR_DIR/lib/"
        echo "    Copied: libmygramclient.so* (from build)"
        FOUND_LIB=1
    fi

    # Try system installation
    if [ -f "/usr/local/lib/libmygramclient.a" ]; then
        cp /usr/local/lib/libmygramclient.a "$VENDOR_DIR/lib/"
        echo "    Copied: libmygramclient.a (from /usr/local)"
        FOUND_LIB=1
    fi

    if ls /usr/local/lib/libmygramclient.so* 1> /dev/null 2>&1; then
        cp /usr/local/lib/libmygramclient.so* "$VENDOR_DIR/lib/"
        echo "    Copied: libmygramclient.so* (from /usr/local)"
        FOUND_LIB=1
    fi
fi

# Check if we found any library
if [ $FOUND_LIB -eq 0 ]; then
    echo ""
    echo "Error: No library files found!"
    echo "Please build and install MygramDB first:"
    echo "  cd $MYGRAM_DB_PATH"
    echo "  make"
    echo "  sudo make install"
    exit 1
fi

# Verify bundled files
echo ""
echo "Verifying bundled files..."
echo "Headers:"
find "$VENDOR_DIR/include" -type f -name "*.h" | sed 's/^/  /'

echo ""
echo "Libraries:"
find "$VENDOR_DIR/lib" -type f | sed 's/^/  /'

# Check header file
if [ ! -f "$VENDOR_DIR/include/mygramdb/mygramclient_c.h" ]; then
    echo ""
    echo "Warning: mygramclient_c.h not found in vendor/include/mygramdb/"
    echo "The bundle may be incomplete."
    exit 1
fi

echo ""
echo "========================================="
echo "Bundle complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  perl Makefile.PL    # Should detect bundled library"
echo "  make"
echo "  make test"
echo ""
echo "To create a distribution with bundled library:"
echo "  make dist"
echo ""
