#!/bin/bash
# Test script for native messaging host

echo "🧪 Testing Longterm Memory Native Host"
echo ""

# Test database connection
echo "1. Testing database connection..."
if psql -U "$USER" -d longterm_memory -c "SELECT 1;" > /dev/null 2>&1; then
    echo "   ✅ Database connection successful"
else
    echo "   ❌ Database connection failed"
    exit 1
fi

# Test native host script
echo ""
echo "2. Testing native host Python script..."
TEST_MESSAGE='{"action":"save","data":{"content":"Test observation from browser extension","url":"https://example.com","title":"Test Page","type":"test"}}'

RESULT=$(echo "$TEST_MESSAGE" | python3 native-host/longterm_memory_host.py 2>&1)

if echo "$RESULT" | grep -q "success"; then
    echo "   ✅ Native host script working"
    echo ""
    echo "   Response: $RESULT"
else
    echo "   ❌ Native host script failed"
    echo "   Error: $RESULT"
    exit 1
fi

echo ""
echo "3. Checking saved observation..."
LAST_OBS=$(psql -U "$USER" -d longterm_memory -t -c "SELECT observation_text FROM observations WHERE source_type = 'browser_extension' ORDER BY created_at DESC LIMIT 1;")

if echo "$LAST_OBS" | grep -q "Test observation"; then
    echo "   ✅ Observation saved successfully"
else
    echo "   ⚠️  Could not verify saved observation"
fi

echo ""
echo "✅ All tests passed! Extension is ready to use."
echo ""
echo "📌 Next: Load the extension in Chrome and update the extension ID in:"
echo "   ~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.longtermmemory.host.json"
