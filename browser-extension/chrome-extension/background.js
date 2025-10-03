// Background service worker for Longterm Memory Capture
const NATIVE_HOST = 'com.longtermmemory.host';
const DASHBOARD_URL = 'http://localhost:5555';

// ============================================
// CONTEXT MENUS
// ============================================

chrome.runtime.onInstalled.addListener(() => {
  // Parent menu item - clearly branded
  chrome.contextMenus.create({
    id: 'longtermMemoryParent',
    title: '🧠 Longterm Memory Database',
    contexts: ['selection', 'page']
  });
  
  // Sub-menu: Quick save selection
  chrome.contextMenus.create({
    id: 'saveLongtermMemory',
    parentId: 'longtermMemoryParent',
    title: 'Save Selection',
    contexts: ['selection']
  });
  
  // Sub-menu: Save selection with context
  chrome.contextMenus.create({
    id: 'saveLongtermMemoryWithContext',
    parentId: 'longtermMemoryParent',
    title: 'Save Selection + Context',
    contexts: ['selection']
  });
  
  // Sub-menu: Save entire page
  chrome.contextMenus.create({
    id: 'saveLongtermMemoryPage',
    parentId: 'longtermMemoryParent',
    title: 'Save Entire Page',
    contexts: ['selection', 'page']
  });
  
  // Separator
  chrome.contextMenus.create({
    id: 'longtermMemorySeparator',
    parentId: 'longtermMemoryParent',
    type: 'separator',
    contexts: ['selection', 'page']
  });
  
  // Sub-menu: Open dashboard
  chrome.contextMenus.create({
    id: 'openLongtermMemoryDashboard',
    parentId: 'longtermMemoryParent',
    title: 'Open Dashboard',
    contexts: ['selection', 'page']
  });
});

// Handle context menu clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === 'saveLongtermMemory') {
    // Quick save - just the selection
    const response = await saveToMemory({
      content: info.selectionText || '',
      url: tab.url,
      title: tab.title,
      type: 'selection',
      metadata: {
        category: detectCategoryFromUrl(tab.url),
        tags: ['selection'],
        captured_at: new Date().toISOString()
      }
    });
    
    if (response.success) {
      showToast(tab.id, 'Saved to Longterm Memory', `Importance: ${(response.data?.importance * 100).toFixed(0)}%`);
    } else {
      showToast(tab.id, 'Save Failed', response.error || 'Unknown error', true);
    }
    
  } else if (info.menuItemId === 'saveLongtermMemoryWithContext') {
    // Save selection plus surrounding context
    try {
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        function: extractSelectionWithContext
      });
      
      const content = result.result;
      const response = await saveToMemory({
        content: content,
        url: tab.url,
        title: tab.title,
        type: 'selection_with_context',
        metadata: {
          category: detectCategoryFromUrl(tab.url),
          tags: ['selection', 'with-context'],
          selection_text: info.selectionText?.slice(0, 500),
          captured_at: new Date().toISOString()
        }
      });
      
      if (response.success) {
        showToast(tab.id, 'Saved with Context', `Importance: ${(response.data?.importance * 100).toFixed(0)}%`);
      } else {
        showToast(tab.id, 'Save Failed', response.error || 'Unknown error', true);
      }
    } catch (error) {
      showToast(tab.id, 'Error', error.message, true);
    }
    
  } else if (info.menuItemId === 'saveLongtermMemoryPage') {
    // Save entire page
    try {
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        function: extractPageContent
      });
      
      const response = await saveToMemory({
        content: result.result,
        url: tab.url,
        title: tab.title,
        type: 'page',
        metadata: {
          category: detectCategoryFromUrl(tab.url),
          tags: ['full-page'],
          captured_at: new Date().toISOString()
        }
      });
      
      if (response.success) {
        showToast(tab.id, 'Page Saved', `Importance: ${(response.data?.importance * 100).toFixed(0)}%`);
      } else {
        showToast(tab.id, 'Save Failed', response.error || 'Unknown error', true);
      }
    } catch (error) {
      showToast(tab.id, 'Error', error.message, true);
    }
    
  } else if (info.menuItemId === 'openLongtermMemoryDashboard') {
    chrome.tabs.create({ url: DASHBOARD_URL });
  }
});

// Extract selection with surrounding paragraph context
function extractSelectionWithContext() {
  const selection = window.getSelection();
  if (!selection.rangeCount) return '';
  
  const range = selection.getRangeAt(0);
  const selectedText = selection.toString().trim();
  
  // Find containing block element
  let container = range.commonAncestorContainer;
  if (container.nodeType === 3) container = container.parentElement;
  
  const blockElement = container.closest('p, div, article, section, li, td, blockquote') || container;
  const contextText = blockElement.textContent?.trim() || '';
  
  // Build content with clear sections
  let content = `SELECTED TEXT:\n${selectedText}`;
  
  if (contextText && contextText !== selectedText && contextText.length > selectedText.length) {
    content += `\n\nSURROUNDING CONTEXT:\n${contextText.slice(0, 1000)}`;
  }
  
  return content;
}

// Show in-page toast notification
async function showToast(tabId, title, message, isError = false) {
  try {
    await chrome.scripting.executeScript({
      target: { tabId },
      func: (title, message, isError) => {
        // Remove existing toast
        const existing = document.getElementById('ltm-toast');
        if (existing) existing.remove();
        
        const toast = document.createElement('div');
        toast.id = 'ltm-toast';
        toast.innerHTML = `
          <style>
            #ltm-toast {
              position: fixed;
              bottom: 20px;
              right: 20px;
              z-index: 2147483647;
              background: ${isError ? '#ef4444' : '#6366f1'};
              color: white;
              padding: 12px 16px;
              border-radius: 8px;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              font-size: 13px;
              box-shadow: 0 4px 12px rgba(0,0,0,0.15);
              animation: ltm-toast-in 0.2s ease-out;
              display: flex;
              align-items: center;
              gap: 10px;
            }
            @keyframes ltm-toast-in {
              from { opacity: 0; transform: translateY(10px); }
              to { opacity: 1; transform: translateY(0); }
            }
            #ltm-toast-icon { font-size: 18px; }
            #ltm-toast-content { display: flex; flex-direction: column; gap: 2px; }
            #ltm-toast-title { font-weight: 600; }
            #ltm-toast-message { opacity: 0.9; font-size: 12px; }
          </style>
          <span id="ltm-toast-icon">${isError ? '⚠️' : '🧠'}</span>
          <div id="ltm-toast-content">
            <div id="ltm-toast-title">${title}</div>
            <div id="ltm-toast-message">${message}</div>
          </div>
        `;
        document.body.appendChild(toast);
        
        setTimeout(() => {
          toast.style.opacity = '0';
          toast.style.transition = 'opacity 0.2s';
          setTimeout(() => toast.remove(), 200);
        }, 3000);
      },
      args: [title, message, isError]
    });
  } catch (e) {
    // Fall back to Chrome notification
    showNotification(title, message);
  }
}

// Detect category from URL
function detectCategoryFromUrl(url) {
  try {
    const hostname = new URL(url).hostname.toLowerCase();
    if (/github|gitlab|bitbucket/.test(hostname)) return 'code';
    if (/stackoverflow|stackexchange/.test(hostname)) return 'code';
    if (/docs\.|documentation|readme|wiki/.test(hostname)) return 'documentation';
    if (/arxiv|scholar|research|paper|journal/.test(hostname)) return 'research';
    if (/youtube|vimeo|spotify/.test(hostname)) return 'media';
    if (/twitter|x\.com|linkedin|facebook/.test(hostname)) return 'social';
    if (/anthropic|openai|huggingface/.test(hostname)) return 'ai';
    if (/news|bbc|cnn|nytimes/.test(hostname)) return 'news';
    return 'article';
  } catch {
    return 'article';
  }
}


// ============================================
// TAB EVENTS: Check for memories on navigation
// ============================================

// Cache to prevent hammering API on tab switching
const urlCheckCache = new Map(); // tabId -> { url, timestamp }
const CACHE_TTL_MS = 30000; // 30 seconds

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url) {
    checkForMemories(tab);
  }
});

chrome.tabs.onActivated.addListener(async (activeInfo) => {
  const tab = await chrome.tabs.get(activeInfo.tabId);
  if (tab.url) {
    checkForMemories(tab);
  }
});


// ============================================
// BI-DIRECTIONAL SYNC: Check for memories
// ============================================

async function checkForMemories(tab) {
  if (!tab.url || tab.url.startsWith('chrome://')) return;
  
  // Don't show memory badge on our own dashboard
  if (tab.url.includes('localhost:5555') || tab.url.includes('127.0.0.1:5555')) return;
  
  // Check cache - skip API call if same URL checked recently
  const cached = urlCheckCache.get(tab.id);
  const now = Date.now();
  if (cached && cached.url === tab.url && (now - cached.timestamp) < CACHE_TTL_MS) {
    return; // Skip - already checked this URL recently
  }
  
  // Check if memory badge is enabled - NOW OPT-IN (default false)
  const { showMemoryBadge } = await chrome.storage.local.get('showMemoryBadge');
  if (showMemoryBadge !== true) {
    // Badge is disabled (opt-in), clear any existing badge
    chrome.action.setBadgeText({ text: '', tabId: tab.id });
    return;
  }
  
  // Update cache before API call
  urlCheckCache.set(tab.id, { url: tab.url, timestamp: now });
  
  try {
    // Use precise URL matching endpoint instead of loose domain matching
    const response = await fetch(`${DASHBOARD_URL}/api/memories/url?url=${encodeURIComponent(tab.url)}&limit=10`);
    
    if (response.ok) {
      const data = await response.json();
      
      // Only show if we have actual matches for this specific URL/path
      if (data.count > 0) {
        // Update toolbar badge
        chrome.action.setBadgeText({ text: data.count.toString(), tabId: tab.id });
        chrome.action.setBadgeBackgroundColor({ color: '#0A84FF' }); // Apple Blue
        
        // Notify content script to show floating badge
        try {
          await chrome.tabs.sendMessage(tab.id, {
            action: 'memoryIndicator',
            data: {
              count: data.count,
              memories: data.memories,
              matching: data.matching
            }
          });
        } catch (e) {}
      } else {
        chrome.action.setBadgeText({ text: '', tabId: tab.id });
      }
    }
  } catch (e) {
    // Dashboard not running, that's ok
    chrome.action.setBadgeText({ text: '', tabId: tab.id });
  }
}


// ============================================
// MESSAGE HANDLING
// ============================================

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'saveToMemory') {
    saveToMemory(request.data)
      .then(response => sendResponse(response))
      .catch(error => sendResponse({success: false, error: error.message}));
    return true;
  }
  
  if (request.action === 'dismissDomain') {
    chrome.storage.local.get('dismissedDomains', (data) => {
      const dismissed = data.dismissedDomains || [];
      dismissed.push(request.domain);
      chrome.storage.local.set({ dismissedDomains: dismissed });
    });
    sendResponse({ success: true });
    return true;
  }
  
  if (request.action === 'getMemories') {
    fetch(`${DASHBOARD_URL}/api/memories/domain/${encodeURIComponent(request.domain)}?limit=20`)
      .then(res => res.json())
      .then(data => sendResponse(data))
      .catch(err => sendResponse({ error: err.message }));
    return true;
  }
  
  if (request.action === 'openDashboard') {
    chrome.tabs.create({ url: `${DASHBOARD_URL}/?search=${encodeURIComponent(request.query || '')}` });
    sendResponse({ success: true });
    return true;
  }
});


// ============================================
// NATIVE MESSAGING
// ============================================

function extractPageContent() {
  const clone = document.cloneNode(true);
  const scripts = clone.querySelectorAll('script, style, noscript, iframe');
  scripts.forEach(el => el.remove());

  const mainSelectors = ['main', 'article', '[role="main"]', '.main-content', '#main-content', '.content', '#content'];
  let mainContent = null;
  for (const selector of mainSelectors) {
    mainContent = clone.querySelector(selector);
    if (mainContent) break;
  }

  const source = mainContent || clone.body;
  let text = source.innerText || source.textContent || '';
  text = text.replace(/\n\s*\n\s*\n/g, '\n\n').replace(/[ \t]+/g, ' ').trim();
  
  const MAX_LENGTH = 50000;
  if (text.length > MAX_LENGTH) {
    text = text.substring(0, MAX_LENGTH) + '\n\n[Content truncated...]';
  }
  return text;
}

function showNotification(title, message) {
  chrome.notifications.create({
    type: 'basic',
    iconUrl: 'icons/icon48.png',
    title: title,
    message: message
  });
}

async function saveToMemory(data) {
  return new Promise((resolve, reject) => {
    console.log('Connecting to native host:', NATIVE_HOST);
    
    let port;
    try {
      port = chrome.runtime.connectNative(NATIVE_HOST);
    } catch (error) {
      console.error('Failed to connect to native host:', error);
      reject(new Error(`Failed to connect: ${error.message}`));
      return;
    }

    let responseReceived = false;

    port.onMessage.addListener((response) => {
      console.log('Response from native host:', response);
      responseReceived = true;
      resolve({success: response.success, data: response, error: response.error});
    });

    port.onDisconnect.addListener(() => {
      console.log('Native host disconnected');
      if (!responseReceived) {
        const error = chrome.runtime.lastError;
        console.error('Disconnect error:', error);
        reject(new Error(error?.message || 'Native host disconnected unexpectedly'));
      }
    });

    const message = {
      action: 'save',
      data: {
        content: data.content,
        url: data.url,
        title: data.title,
        type: data.type,
        metadata: data.metadata || {},
        timestamp: new Date().toISOString()
      }
    };
    
    console.log('Sending to native host:', message);
    port.postMessage(message);
  });
}
