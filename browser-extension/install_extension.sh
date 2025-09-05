#!/bin/bash
# Installation script for Longterm Memory Chrome Extension

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_HOST_DIR="$SCRIPT_DIR/native-host"
CHROME_NATIVE_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
CHROMIUM_NATIVE_DIR="$HOME/Library/Application Support/Chromium/NativeMessagingHosts"

echo "🔧 Installing Longterm Memory Chrome Extension"
echo ""

# Check Python dependencies
echo "📦 Checking Python dependencies..."
if ! python3 -c "import psycopg2" 2>/dev/null; then
    echo "Installing psycopg2-binary..."
    pip3 install psycopg2-binary --break-system-packages
fi

# Get Python path
PYTHON_PATH=$(which python3)
echo "Using Python: $PYTHON_PATH"

# Update Python shebang in host script
echo "📝 Updating Python path in native host script..."
sed -i '' "1s|.*|#!$PYTHON_PATH|" "$NATIVE_HOST_DIR/longterm_memory_host.py"

# Create native messaging host directories
echo "📁 Creating native messaging host directories..."
mkdir -p "$CHROME_NATIVE_DIR/longterm-memory"
mkdir -p "$CHROMIUM_NATIVE_DIR/longterm-memory"

# Copy native host script to Chrome directory (required for Chrome security)
echo "📋 Installing native messaging host for Chrome..."
cp "$NATIVE_HOST_DIR/longterm_memory_host.py" "$CHROME_NATIVE_DIR/longterm-memory/host.py"
chmod +x "$CHROME_NATIVE_DIR/longterm-memory/host.py"

# Create manifest for Chrome
cat > "$CHROME_NATIVE_DIR/com.longtermmemory.host.json" << EOF
{
  "name": "com.longtermmemory.host",
  "description": "Longterm Memory native messaging host",
  "path": "$CHROME_NATIVE_DIR/longterm-memory/host.py",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://EXTENSION_ID_PLACEHOLDER/"
  ]
}
EOF

# Copy native host script to Chromium directory
echo "📋 Installing native messaging host for Chromium browsers..."
cp "$NATIVE_HOST_DIR/longterm_memory_host.py" "$CHROMIUM_NATIVE_DIR/longterm-memory/host.py"
chmod +x "$CHROMIUM_NATIVE_DIR/longterm-memory/host.py"

# Create manifest for Chromium
cat > "$CHROMIUM_NATIVE_DIR/com.longtermmemory.host.json" << EOF
{
  "name": "com.longtermmemory.host",
  "description": "Longterm Memory native messaging host",
  "path": "$CHROMIUM_NATIVE_DIR/longterm-memory/host.py",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://EXTENSION_ID_PLACEHOLDER/"
  ]
}
EOF

echo ""
echo "✅ Installation complete!"
echo ""
echo "📌 Next steps:"
echo ""
echo "1. Load the extension in Chrome:"
echo "   • Open chrome://extensions/"
echo "   • Enable 'Developer mode' (top right)"
echo "   • Click 'Load unpacked'"
echo "   • Select: $SCRIPT_DIR/chrome-extension/"
echo ""
echo "2. Update the native host manifest with your extension ID:"
echo "   • After loading, copy the extension ID from chrome://extensions/"
echo "   • Edit: $CHROME_NATIVE_DIR/com.longtermmemory.host.json"
echo "   • Replace EXTENSION_ID_PLACEHOLDER with your actual ID"
echo ""
echo "3. Restart Chrome to activate native messaging"
echo ""
echo "🎯 The extension works in all Chromium browsers:"
echo "   • Google Chrome"
echo "   • Chromium"
echo "   • Microsoft Edge"
echo "   • Brave"
echo "   • Arc"
echo "   • Perplexity Comet"
echo "   • GPT Atlas"
echo ""
echo "For other Chromium browsers, copy the manifest to their NativeMessagingHosts directory."
echo ""
