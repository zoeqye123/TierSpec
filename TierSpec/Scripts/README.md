# Node.js Bundling Setup for TierSpec

## Overview

This directory contains the build script that bundles Node.js runtime and the MCP server into the TierSpec.app bundle.

## Files

- `bundle-node.sh` - Main bundling script that copies Node.js and MCP server

## Manual Setup Instructions

Since Xcode project files are binary/complex, you need to manually add the build phase:

### Step 1: Open Xcode Project

```bash
open /Users/z/project/tierspec/TierSpec/TierSpec.xcodeproj
```

### Step 2: Add Run Script Build Phase

1. Select the **TierSpec** project in the navigator
2. Select the **TierSpec** target
3. Go to **Build Phases** tab
4. Click **+** button → **New Run Script Phase**
5. Drag the new phase to run **after "Compile Sources"** but **before "Copy Bundle Resources"**
6. Name it: **"Bundle Node.js and MCP Server"**
7. Paste this script:

```bash
"${PROJECT_DIR}/Scripts/bundle-node.sh"
```

8. Check **"Show environment variables in build log"** for debugging

### Step 3: Verify Setup

Build the project (⌘B) and check the build log for:

```
🔧 TierSpec: Bundling Node.js and MCP server...
📦 Found Node.js: /opt/homebrew/bin/node
   Version: v25.9.0
📋 Copying Node.js binary...
📋 Copying MCP server...
✅ Node.js and MCP server bundled successfully
```

### Step 4: Verify Bundle Contents

After building, verify the app bundle contains:

```bash
# Check Node.js binary
ls -lh "$(xcodebuild -showBuildSettings | grep BUILT_PRODUCTS_DIR | awk '{print $3}')/TierSpec.app/Contents/MacOS/node"

# Check MCP server
ls -lh "$(xcodebuild -showBuildSettings | grep BUILT_PRODUCTS_DIR | awk '{print $3}')/TierSpec.app/Contents/MacOS/tierspec-mcp-server/dist/index.js"
```

## Troubleshooting

### Error: Node.js not found

Install Node.js via Homebrew:
```bash
brew install node
```

### Error: MCP server not built

Build the MCP server manually:
```bash
cd /Users/z/project/tierspec/mcp-server
npm install
npm run build
```

### Error: Permission denied

Make the script executable:
```bash
chmod +x /Users/z/project/tierspec/TierSpec/Scripts/bundle-node.sh
```

## Automated Verification

Run the verification script to check if bundling works:

```bash
./verify-bundling.sh
```

This will:
1. Build the app
2. Check if Node.js is bundled
3. Check if MCP server is bundled
4. Test if the bundled Node.js works
5. Test if the MCP server can start

## CI/CD Integration

For automated builds, ensure:
1. Node.js is installed on the build machine
2. MCP server dependencies are installed (`npm install` in mcp-server/)
3. MCP server is built (`npm run build` in mcp-server/)
4. The build script has execute permissions

## Bundle Size

Expected bundle additions:
- Node.js binary: ~50MB
- MCP server + node_modules: ~30-40MB
- Total: ~80-90MB additional to app bundle

This is acceptable compared to Electron apps (~400MB+).
