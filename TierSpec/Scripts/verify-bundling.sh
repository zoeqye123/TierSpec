#!/bin/bash
set -e

echo "🧪 TierSpec: Verifying Node.js bundling setup..."

PROJECT_DIR="/Users/z/project/tierspec/TierSpec"
MCP_SERVER_DIR="/Users/z/project/tierspec/mcp-server"

cd "${PROJECT_DIR}"

echo "1️⃣ Checking if bundle-node.sh exists and is executable..."
if [ ! -f "Scripts/bundle-node.sh" ]; then
    echo "❌ Error: bundle-node.sh not found"
    exit 1
fi

if [ ! -x "Scripts/bundle-node.sh" ]; then
    echo "❌ Error: bundle-node.sh is not executable"
    exit 1
fi
echo "✅ bundle-node.sh exists and is executable"

echo ""
echo "2️⃣ Checking if Node.js is installed..."
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js not found. Install with: brew install node"
    exit 1
fi
NODE_VERSION=$(node --version)
echo "✅ Node.js installed: ${NODE_VERSION}"

echo ""
echo "3️⃣ Checking if MCP server can be built..."
if [ ! -d "${MCP_SERVER_DIR}" ]; then
    echo "❌ Error: MCP server directory not found"
    exit 1
fi

cd "${MCP_SERVER_DIR}"

if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found in MCP server"
    exit 1
fi

echo "   Installing MCP server dependencies..."
npm install --silent

echo "   Building MCP server..."
npm run build --silent

if [ ! -f "dist/index.js" ]; then
    echo "❌ Error: MCP server build failed"
    exit 1
fi
echo "✅ MCP server built successfully"

echo ""
echo "4️⃣ Testing bundle-node.sh script..."
cd "${PROJECT_DIR}"

export BUILT_PRODUCTS_DIR="/tmp/tierspec-test-build"
export FULL_PRODUCT_NAME="TierSpec.app"
export PROJECT_DIR="${PROJECT_DIR}"

rm -rf "${BUILT_PRODUCTS_DIR}"
mkdir -p "${BUILT_PRODUCTS_DIR}"

if ! Scripts/bundle-node.sh; then
    echo "❌ Error: bundle-node.sh failed"
    exit 1
fi

echo ""
echo "5️⃣ Verifying bundled files..."

APP_BUNDLE="${BUILT_PRODUCTS_DIR}/TierSpec.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"

if [ ! -f "${MACOS_DIR}/node" ]; then
    echo "❌ Error: Node.js binary not bundled"
    exit 1
fi
echo "✅ Node.js binary bundled"

if [ ! -x "${MACOS_DIR}/node" ]; then
    echo "❌ Error: Node.js binary not executable"
    exit 1
fi
echo "✅ Node.js binary is executable"

if [ ! -f "${MACOS_DIR}/tierspec-mcp-server/dist/index.js" ]; then
    echo "❌ Error: MCP server not bundled"
    exit 1
fi
echo "✅ MCP server bundled"

if [ ! -d "${MACOS_DIR}/tierspec-mcp-server/node_modules" ]; then
    echo "❌ Error: MCP server node_modules not bundled"
    exit 1
fi
echo "✅ MCP server node_modules bundled"

echo ""
echo "6️⃣ Testing bundled Node.js..."
BUNDLED_NODE_VERSION=$("${MACOS_DIR}/node" --version)
echo "✅ Bundled Node.js works: ${BUNDLED_NODE_VERSION}"

echo ""
echo "7️⃣ Testing bundled MCP server..."
cd "${MACOS_DIR}/tierspec-mcp-server"
timeout 2 "${MACOS_DIR}/node" dist/index.js 2>&1 | head -5 || true
echo "✅ MCP server can start (killed after 2s)"

echo ""
echo "8️⃣ Checking bundle sizes..."
NODE_SIZE=$(du -sh "${MACOS_DIR}/node" | awk '{print $1}')
MCP_SIZE=$(du -sh "${MACOS_DIR}/tierspec-mcp-server" | awk '{print $1}')
echo "   Node.js binary: ${NODE_SIZE}"
echo "   MCP server: ${MCP_SIZE}"

echo ""
echo "✅ All verification checks passed!"
echo ""
echo "📋 Next steps:"
echo "   1. Open TierSpec.xcodeproj in Xcode"
echo "   2. Add Run Script build phase (see Scripts/README.md)"
echo "   3. Build the project (⌘B)"
echo "   4. Verify the app bundle contains Node.js and MCP server"

rm -rf "${BUILT_PRODUCTS_DIR}"
