#!/bin/bash
set -e

# TierSpec Node.js Bundling Script
# Bundles Node.js runtime and MCP server into the app bundle

echo "🔧 TierSpec: Bundling Node.js and MCP server..."

# Configuration
APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
MCP_SERVER_SRC="${PROJECT_DIR}/../mcp-server"
MCP_SERVER_DEST="${MACOS_DIR}/tierspec-mcp-server"

# Detect Node.js binary
if [ -f "/opt/homebrew/bin/node" ]; then
    NODE_BINARY="/opt/homebrew/bin/node"
elif [ -f "/usr/local/bin/node" ]; then
    NODE_BINARY="/usr/local/bin/node"
elif command -v node &> /dev/null; then
    NODE_BINARY=$(command -v node)
else
    echo "❌ Error: Node.js not found. Please install Node.js."
    exit 1
fi

echo "📦 Found Node.js: ${NODE_BINARY}"
NODE_VERSION=$(${NODE_BINARY} --version)
echo "   Version: ${NODE_VERSION}"

# Create directories
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy Node.js binary
echo "📋 Copying Node.js binary..."
cp "${NODE_BINARY}" "${MACOS_DIR}/node"
chmod +x "${MACOS_DIR}/node"

# Build MCP server if needed
if [ ! -d "${MCP_SERVER_SRC}/dist" ]; then
    echo "🔨 Building MCP server..."
    cd "${MCP_SERVER_SRC}"
    npm install --production
    npm run build
fi

# Copy MCP server
echo "📋 Copying MCP server..."
rm -rf "${MCP_SERVER_DEST}"
mkdir -p "${MCP_SERVER_DEST}"

# Copy compiled server
cp -R "${MCP_SERVER_SRC}/dist" "${MCP_SERVER_DEST}/"

# Copy node_modules (production only)
if [ -d "${MCP_SERVER_SRC}/node_modules" ]; then
    cp -R "${MCP_SERVER_SRC}/node_modules" "${MCP_SERVER_DEST}/"
else
    echo "⚠️  Warning: node_modules not found, installing..."
    cd "${MCP_SERVER_SRC}"
    npm install --production
    cp -R "${MCP_SERVER_SRC}/node_modules" "${MCP_SERVER_DEST}/"
fi

# Copy package.json
cp "${MCP_SERVER_SRC}/package.json" "${MCP_SERVER_DEST}/"

# Verify bundling
if [ ! -f "${MACOS_DIR}/node" ]; then
    echo "❌ Error: Node.js binary not copied"
    exit 1
fi

if [ ! -f "${MCP_SERVER_DEST}/dist/index.js" ]; then
    echo "❌ Error: MCP server not copied"
    exit 1
fi

echo "✅ Node.js and MCP server bundled successfully"
echo "   Node.js: ${MACOS_DIR}/node"
echo "   MCP Server: ${MCP_SERVER_DEST}/dist/index.js"
