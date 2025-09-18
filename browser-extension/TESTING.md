# Browser Extension Testing Checklist

## Pre-Testing Setup

- [ ] PostgreSQL running: `brew services list | grep postgresql@17`
- [ ] Database accessible: `psql -U $USER -d longterm_memory -c "SELECT 1;"`
- [ ] Ollama running: `curl http://localhost:11434/api/tags`
- [ ] Backend test passed: `python3 test_native_host.py`

## Installation Testing

### Chrome
- [ ] Run `./install_extension.sh` successfully
- [ ] Verify native host manifest created: `ls -la ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/com.longtermmemory.host.json`
- [ ] Load extension in `chrome://extensions/`
- [ ] Copy extension ID
- [ ] Update native host manifest with extension ID
- [ ] Restart Chrome

### Perplexity Comet
- [ ] Copy native host manifest to Comet directory (if different from Chrome)
- [ ] Load extension
- [ ] Update manifest with Comet extension ID
- [ ] Restart Comet

### GPT Atlas
- [ ] Copy native host manifest to Atlas directory (if different from Chrome)
- [ ] Load extension
- [ ] Update manifest with Atlas extension ID
- [ ] Restart Atlas

## Feature Testing

### Popup UI
- [ ] Click extension icon - popup opens
- [ ] Page title displays correctly
- [ ] Page URL displays correctly
- [ ] Type note in textarea
- [ ] Click "Save" - success message appears
- [ ] Verify in database:
  ```sql
  SELECT * FROM observations
  WHERE source_type = 'browser_extension'
  ORDER BY created_at DESC LIMIT 1;
  ```

### Full Page Capture
- [ ] Click extension icon
- [ ] Click "Capture Page" button
- [ ] Success message appears
- [ ] Verify page content saved in database
- [ ] Check content is meaningful (not just scripts/styles)

### Context Menu (Selection)
- [ ] Select text on any webpage
- [ ] Right-click selected text
- [ ] See "Save to Longterm Memory" option
- [ ] Click menu item
- [ ] Verify selected text saved with page context

### Different Content Types
- [ ] Test on article page (e.g., Medium, blog)
- [ ] Test on documentation page (e.g., MDN, GitHub)
- [ ] Test on social media (Twitter/X, LinkedIn)
- [ ] Test on video page (YouTube)
- [ ] Test on code repository (GitHub)

## Database Verification

### Check Saved Observations
```sql
-- Count observations from extension
SELECT COUNT(*) FROM observations
WHERE source_type = 'browser_extension';

-- View recent captures with domains
SELECT
    e.name as domain,
    substring(o.observation_text, 1, 100) as preview,
    o.created_at
FROM observations o
JOIN entities e ON o.entity_id = e.id
WHERE o.source_type = 'browser_extension'
ORDER BY o.created_at DESC
LIMIT 5;
```

### Check Entities Created
```sql
-- View domains captured
SELECT
    name,
    entity_type,
    observation_count,
    metadata
FROM entities
WHERE source_type = 'browser_extension'
ORDER BY created_at DESC;
```

## Embedding Generation

- [ ] Wait for daily cron job (4:00 AM) OR run manually:
  ```bash
  cd scripts
  python3 ollama_embeddings.py embed
  ```
- [ ] Verify embeddings generated:
  ```sql
  SELECT COUNT(*) FROM observations
  WHERE source_type = 'browser_extension'
  AND embedding IS NOT NULL;
  ```
- [ ] Test semantic search with captured content:
  ```bash
  cd scripts
  python3 ollama_embeddings.py search "topic from captured page"
  ```

## Error Handling

### Native Host Disconnected
- [ ] Cause: Wrong extension ID in manifest
- [ ] Error appears in extension popup
- [ ] Fix: Update manifest, restart browser

### Database Connection Failed
- [ ] Cause: PostgreSQL not running
- [ ] Error appears in popup
- [ ] Fix: `brew services start postgresql@17`

### No Response from Native Host
- [ ] Cause: Python script not executable
- [ ] Fix: `chmod +x browser-extension/native-host/longterm_memory_host.py`

## Performance Testing

- [ ] Capture 10 pages in quick succession
- [ ] Verify all saved successfully
- [ ] Check memory usage in Activity Monitor
- [ ] Verify PostgreSQL performance: `SELECT * FROM pg_stat_activity;`

## Cross-Browser Testing

### Chrome Variants
- [ ] Google Chrome
- [ ] Chromium
- [ ] Microsoft Edge (if available)
- [ ] Brave (if available)

### AI-Integrated Browsers
- [ ] Perplexity Comet
- [ ] GPT Atlas
- [ ] Arc (if available)

## Integration Testing

### With MCP
- [ ] Capture content via extension
- [ ] Open Claude Desktop
- [ ] Query longterm-memory MCP for recent captures
- [ ] Verify Claude can see captured content

### With Sync
- [ ] Capture content on Mac #1
- [ ] Wait for iCloud sync (or trigger manually)
- [ ] Verify content appears on Mac #2
- [ ] Query from Mac #2 via MCP

## Security Testing

- [ ] Verify no credentials in extension code
- [ ] Check native host uses `.pgpass` (no hardcoded passwords)
- [ ] Verify only allowed extension IDs in manifest
- [ ] Test with wrong extension ID - should fail

## Cleanup (After Testing)

### Remove Test Data
```sql
-- Remove test observations
DELETE FROM observations
WHERE source_type = 'browser_extension'
AND observation_text LIKE '%Test observation%';

-- Or keep them as real data!
```

### Uninstall (Optional)
- [ ] Remove extension from browser
- [ ] Delete native host manifest
- [ ] Keep database data (it's useful!)

## Known Issues

Document any issues found during testing:

1. **Issue**:
   **Browser**:
   **Steps to Reproduce**:
   **Expected**:
   **Actual**:
   **Workaround**:

## Test Results

**Date**: ___________
**Tester**: ___________
**Branch**: feature/browser-extension
**Commit**: d12e1ed

### Summary
- **Browsers Tested**:
- **Total Tests**:
- **Passed**:
- **Failed**:
- **Blocked**:

### Notes
