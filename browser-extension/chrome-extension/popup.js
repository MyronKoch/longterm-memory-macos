// Popup script for Longterm Memory Capture
let currentTab = null;

// Auto-detect category based on URL patterns
function detectCategory(url) {
  try {
    const hostname = new URL(url).hostname.toLowerCase();

    // Documentation sites
    if (hostname.match(/(docs?\.|developer\.|api\.|reference\.)/)) return 'documentation';
    if (hostname.includes('stackoverflow') || hostname.includes('github')) return 'code';
    if (hostname.includes('mdn') || hostname.includes('devdocs')) return 'documentation';

    // AI/ML resources
    if (hostname.match(/(anthropic|openai|huggingface|arxiv)/)) return 'research';

    // Social media
    if (hostname.match(/(twitter|x\.com|facebook|linkedin|reddit|instagram|threads)/)) return 'social';

    // News sites
    if (hostname.match(/(news|cnn|bbc|nytimes|reuters|techcrunch|theverge|arstechnica)/)) return 'news';

    // Wikipedia and reference
    if (hostname.includes('wikipedia') || hostname.includes('britannica')) return 'reference';

    // YouTube, podcasts
    if (hostname.match(/(youtube|spotify|podcasts)/)) return 'media';

    // Default to article
    return 'article';
  } catch {
    return 'article';
  }
}

// Get importance suggestion based on category
function suggestImportance(category) {
  const importanceMap = {
    'documentation': 0.7,
    'research': 0.8,
    'code': 0.7,
    'reference': 0.6,
    'article': 0.5,
    'news': 0.4,
    'social': 0.3,
    'media': 0.4,
    'personal': 0.6,
  };
  return importanceMap[category] || 0.5;
}

// Load current tab info
chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
  currentTab = tabs[0];
  document.getElementById('pageTitle').textContent = currentTab.title;
  document.getElementById('pageUrl').textContent = new URL(currentTab.url).hostname;

  // Auto-detect category
  const detected = detectCategory(currentTab.url);
  const categorySelect = document.getElementById('category');

  // Set detected category
  Array.from(categorySelect.options).forEach(option => {
    if (option.value === detected) {
      option.selected = true;
    }
  });

  // Update importance suggestion
  updateImportanceSuggestion();
});

// Update importance when category changes
document.getElementById('category').addEventListener('change', updateImportanceSuggestion);

function updateImportanceSuggestion() {
  const category = document.getElementById('category').value;
  const importance = suggestImportance(category);
  document.getElementById('importanceValue').textContent = `${Math.round(importance * 100)}%`;
  document.getElementById('importance').value = importance;
}

// Gather metadata from form
function getMetadata() {
  const category = document.getElementById('category').value;
  const tagsInput = document.getElementById('tags').value.trim();
  const tags = tagsInput ? tagsInput.split(',').map(t => t.trim()).filter(t => t) : [];
  const importance = parseFloat(document.getElementById('importance').value);

  return {
    category: category === 'auto' ? detectCategory(currentTab.url) : category,
    tags: tags,
    importance: importance,
    captured_at: new Date().toISOString()
  };
}

// Save function
async function saveNote() {
  const content = document.getElementById('content').value.trim();

  if (!content && !currentTab) {
    showStatus('Please enter some content or wait for page to load', 'error');
    return;
  }

  try {
    showStatus('Saving...', 'success');

    const metadata = getMetadata();
    const hasNotes = content.length > 0;

    const response = await chrome.runtime.sendMessage({
      action: 'saveToMemory',
      data: {
        content: content || `Visited: ${currentTab.title}`,
        url: currentTab.url,
        title: currentTab.title,
        type: hasNotes ? 'note' : 'visit',
        metadata: metadata
      }
    });

    if (response.success) {
      const data = response.data || {};
      const imp = data.importance ? `${Math.round(data.importance * 100)}%` : '';
      const type = data.observation_type || '';
      showStatus(`✓ Saved! (${type}${imp ? ', ' + imp : ''})`, 'success');
      document.getElementById('content').value = '';
      document.getElementById('tags').value = '';
      setTimeout(() => window.close(), 1500);
    } else {
      showStatus(`Error: ${response.error}`, 'error');
    }
  } catch (error) {
    showStatus(`Error: ${error.message}`, 'error');
  }
}

// Save button
document.getElementById('saveBtn').addEventListener('click', saveNote);

// Keyboard shortcut (Cmd/Ctrl + Enter)
document.addEventListener('keydown', (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
    saveNote();
  }
});

// Capture full page button
document.getElementById('captureBtn').addEventListener('click', async () => {
  try {
    showStatus('Capturing page...', 'success');

    // Get page content from content script
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const response = await chrome.tabs.sendMessage(tab.id, { action: 'getPageContent' });

    if (response && response.content) {
      const metadata = getMetadata();

      const saveResponse = await chrome.runtime.sendMessage({
        action: 'saveToMemory',
        data: {
          content: response.content,
          url: tab.url,
          title: tab.title,
          type: 'page',
          metadata: metadata
        }
      });

      if (saveResponse.success) {
        const data = saveResponse.data || {};
        const imp = data.importance ? `${Math.round(data.importance * 100)}%` : '';
        showStatus(`✓ Page captured! (${imp})`, 'success');
        setTimeout(() => window.close(), 1500);
      } else {
        showStatus(`Error: ${saveResponse.error}`, 'error');
      }
    } else {
      showStatus('Could not extract page content', 'error');
    }
  } catch (error) {
    showStatus(`Error: ${error.message}`, 'error');
  }
});

function showStatus(message, type) {
  const statusEl = document.getElementById('status');
  statusEl.textContent = message;
  statusEl.className = `status-message ${type}`;
}

// Importance slider update
document.getElementById('importance').addEventListener('input', function () {
  document.getElementById('importanceValue').textContent = Math.round(this.value * 100) + '%';
});

// Quick tag buttons
document.querySelectorAll('.quick-tag').forEach(tag => {
  tag.addEventListener('click', function () {
    const tagsInput = document.getElementById('tags');
    const currentTags = tagsInput.value.trim();
    const newTag = this.dataset.tag;

    if (currentTags) {
      if (!currentTags.split(',').map(t => t.trim()).includes(newTag)) {
        tagsInput.value = currentTags + ', ' + newTag;
      }
    } else {
      tagsInput.value = newTag;
    }
  });
});

// ============================================
// SETTINGS MANAGEMENT
// ============================================

// Load settings on popup open
chrome.storage.local.get(['showMemoryBadge'], (data) => {
  // Default to false (opt-in) - only true if explicitly set
  document.getElementById('showMemoryBadge').checked = data.showMemoryBadge === true;
});

// Save settings when changed
document.getElementById('showMemoryBadge').addEventListener('change', function() {
  chrome.storage.local.set({ showMemoryBadge: this.checked });
  // Notify all tabs to update
  chrome.tabs.query({}, (tabs) => {
    tabs.forEach(tab => {
      chrome.tabs.sendMessage(tab.id, { 
        action: 'updateSettings', 
        settings: { showMemoryBadge: this.checked }
      }).catch(() => {}); // Ignore errors for tabs without content script
    });
  });
});
