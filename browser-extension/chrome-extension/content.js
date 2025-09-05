// Content script for Longterm Memory browser extension
// Features: Page content extraction, Memory indicators with Liquid Glass design

// Global state
let memoryPanel = null;
let memoryBadge = null;

// ============================================
// THEME DETECTION
// ============================================

function getThemeMode() {
  // Check system preference
  if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
    return 'dark';
  }
  return 'light';
}

function getThemeColors() {
  const isDark = getThemeMode() === 'dark';
  
  return {
    // Backgrounds
    bgBase: isDark ? '#000000' : '#FFFFFF',
    bgElevated: isDark ? '#1C1C1E' : '#F2F2F7',
    bgCard: isDark ? 'rgba(28, 28, 30, 0.95)' : 'rgba(255, 255, 255, 0.95)',
    
    // Text
    textPrimary: isDark ? 'rgba(255, 255, 255, 0.95)' : 'rgba(0, 0, 0, 0.85)',
    textSecondary: isDark ? 'rgba(255, 255, 255, 0.65)' : 'rgba(0, 0, 0, 0.55)',
    textTertiary: isDark ? 'rgba(255, 255, 255, 0.45)' : 'rgba(0, 0, 0, 0.35)',
    
    // Borders
    border: isDark ? 'rgba(255, 255, 255, 0.12)' : 'rgba(0, 0, 0, 0.08)',
    borderSubtle: isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.04)',
    
    // Brand
    brandPrimary: '#0A84FF',
    
    // Shadows
    shadow: isDark 
      ? '0 8px 32px rgba(0, 0, 0, 0.5)' 
      : '0 8px 32px rgba(0, 0, 0, 0.12)',
    shadowSmall: isDark
      ? '0 2px 8px rgba(0, 0, 0, 0.4)'
      : '0 2px 8px rgba(0, 0, 0, 0.08)'
  };
}

// ============================================
// MESSAGE HANDLING
// ============================================

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'getPageContent') {
    const content = extractPageContent();
    sendResponse({content: content});
  }
  
  if (request.action === 'memoryIndicator') {
    // Check if memory badge is enabled
    chrome.storage.local.get(['showMemoryBadge'], (data) => {
      if (data.showMemoryBadge === true) { // Opt-in: must be explicitly true
        showMemoryIndicator(request.data);
      }
    });
    sendResponse({ success: true });
  }
  
  if (request.action === 'updateSettings') {
    // Handle real-time settings updates
    if (request.settings.showMemoryBadge !== true) {
      // Remove badge and panel if disabled
      const badge = document.getElementById('ltm-memory-badge');
      const panel = document.getElementById('ltm-memory-panel');
      if (badge) badge.remove();
      if (panel) panel.remove();
      memoryBadge = null;
      memoryPanel = null;
    }
    sendResponse({ success: true });
  }
  
  return true;
});

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

// Detect category from URL
function detectCategory(url) {
  const hostname = new URL(url).hostname.toLowerCase();
  if (/github|gitlab|bitbucket/.test(hostname)) return 'code';
  if (/stackoverflow|stackexchange/.test(hostname)) return 'code';
  if (/docs\.|documentation|readme|wiki/.test(hostname)) return 'documentation';
  if (/arxiv|scholar|research|paper|journal/.test(hostname)) return 'research';
  if (/youtube|vimeo|spotify/.test(hostname)) return 'media';
  if (/twitter|x\.com|linkedin|facebook/.test(hostname)) return 'social';
  if (/anthropic|openai|huggingface/.test(hostname)) return 'ai';
  if (/news|bbc|cnn|nytimes/.test(hostname)) return 'article';
  return 'article';
}

// ============================================
// MEMORY INDICATOR - LIQUID GLASS DESIGN
// ============================================

function showMemoryIndicator(data) {
  if (data.count === 0) return;
  
  const colors = getThemeColors();
  
  // Create floating badge
  if (!memoryBadge) {
    memoryBadge = document.createElement('div');
    memoryBadge.id = 'ltm-memory-badge';
    memoryBadge.innerHTML = `
      <style>
        #ltm-memory-badge {
          position: fixed;
          bottom: 24px;
          right: 24px;
          z-index: 2147483646;
          background: ${colors.brandPrimary};
          border-radius: 22px;
          height: 44px;
          padding: 0 16px;
          display: flex;
          align-items: center;
          gap: 8px;
          cursor: pointer;
          box-shadow: ${colors.shadow};
          transition: transform 0.2s ease, box-shadow 0.2s ease;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
        }
        #ltm-memory-badge:hover {
          transform: translateY(-2px);
          box-shadow: 0 12px 40px rgba(10, 132, 255, 0.4);
        }
        #ltm-memory-badge:active {
          transform: translateY(0);
        }
        .ltm-badge-icon {
          width: 20px;
          height: 20px;
        }
        .ltm-badge-count {
          color: white;
          font-weight: 600;
          font-size: 14px;
          letter-spacing: -0.01em;
        }
        
        #ltm-memory-panel {
          position: fixed;
          bottom: 80px;
          right: 24px;
          z-index: 2147483647;
          background: ${colors.bgCard};
          backdrop-filter: blur(20px);
          -webkit-backdrop-filter: blur(20px);
          border: 1px solid ${colors.border};
          border-radius: 14px;
          width: 320px;
          max-height: 420px;
          overflow: hidden;
          box-shadow: ${colors.shadow};
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif;
          display: none;
        }
        
        .ltm-panel-header {
          background: ${colors.bgElevated};
          border-bottom: 1px solid ${colors.borderSubtle};
          padding: 14px 16px;
          display: flex;
          justify-content: space-between;
          align-items: center;
        }
        .ltm-panel-title {
          display: flex;
          align-items: center;
          gap: 8px;
          font-weight: 600;
          font-size: 15px;
          color: ${colors.textPrimary};
        }
        .ltm-panel-close {
          width: 28px;
          height: 28px;
          border-radius: 50%;
          background: ${colors.border};
          border: none;
          color: ${colors.textSecondary};
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: background 0.15s ease;
        }
        .ltm-panel-close:hover {
          background: ${colors.borderSubtle};
        }
        
        .ltm-panel-body {
          max-height: 300px;
          overflow-y: auto;
        }
        
        .ltm-memory-item {
          padding: 14px 16px;
          border-bottom: 1px solid ${colors.borderSubtle};
          cursor: pointer;
          transition: background 0.15s ease;
        }
        .ltm-memory-item:hover {
          background: ${colors.border};
        }
        .ltm-memory-item:last-child {
          border-bottom: none;
        }
        
        .ltm-memory-type {
          font-size: 11px;
          font-weight: 600;
          color: ${colors.brandPrimary};
          text-transform: uppercase;
          letter-spacing: 0.02em;
          margin-bottom: 4px;
        }
        .ltm-memory-text {
          font-size: 13px;
          color: ${colors.textPrimary};
          line-height: 1.4;
          display: -webkit-box;
          -webkit-line-clamp: 2;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }
        .ltm-memory-date {
          font-size: 12px;
          color: ${colors.textTertiary};
          margin-top: 6px;
        }
        
        .ltm-panel-footer {
          padding: 12px 16px;
          background: ${colors.bgElevated};
          border-top: 1px solid ${colors.borderSubtle};
          text-align: center;
        }
        .ltm-panel-link {
          color: ${colors.brandPrimary};
          text-decoration: none;
          font-size: 13px;
          font-weight: 500;
          display: flex;
          align-items: center;
          justify-content: center;
          gap: 4px;
        }
        .ltm-panel-link:hover {
          text-decoration: underline;
        }
        
        /* Scrollbar styling */
        .ltm-panel-body::-webkit-scrollbar {
          width: 6px;
        }
        .ltm-panel-body::-webkit-scrollbar-track {
          background: transparent;
        }
        .ltm-panel-body::-webkit-scrollbar-thumb {
          background: ${colors.border};
          border-radius: 3px;
        }
      </style>
      <svg class="ltm-badge-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="12" cy="12" r="10" stroke="white" stroke-width="2"/>
        <circle cx="12" cy="12" r="4" fill="white"/>
        <path d="M12 2v4M12 18v4M2 12h4M18 12h4" stroke="white" stroke-width="2" stroke-linecap="round"/>
      </svg>
      <span class="ltm-badge-count">${data.count}</span>
    `;
    
    document.body.appendChild(memoryBadge);
    memoryBadge.addEventListener('click', () => toggleMemoryPanel(data));
  } else {
    memoryBadge.querySelector('.ltm-badge-count').textContent = data.count;
  }
  
  // Store data for panel
  memoryBadge.dataset.memories = JSON.stringify(data.memories);
}

function toggleMemoryPanel(data) {
  if (memoryPanel) {
    memoryPanel.style.display = memoryPanel.style.display === 'none' ? 'block' : 'none';
    return;
  }
  
  const colors = getThemeColors();
  
  // Create panel
  memoryPanel = document.createElement('div');
  memoryPanel.id = 'ltm-memory-panel';
  
  const memories = data.memories || JSON.parse(memoryBadge.dataset.memories || '[]');
  
  let itemsHtml = memories.map(m => `
    <div class="ltm-memory-item" data-id="${m.id}">
      <div class="ltm-memory-type">${m.type || 'note'}</div>
      <div class="ltm-memory-text">${escapeHtml(m.text.slice(0, 150))}</div>
      <div class="ltm-memory-date">${formatDate(m.created_at)}</div>
    </div>
  `).join('');
  
  memoryPanel.innerHTML = `
    <div class="ltm-panel-header">
      <span class="ltm-panel-title">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="10" stroke="${colors.brandPrimary}" stroke-width="2"/>
          <circle cx="12" cy="12" r="4" fill="${colors.brandPrimary}"/>
        </svg>
        Your Memories (${memories.length})
      </span>
      <button class="ltm-panel-close" onclick="this.closest('#ltm-memory-panel').style.display='none'">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M18 6L6 18M6 6l12 12"/>
        </svg>
      </button>
    </div>
    <div class="ltm-panel-body">
      ${itemsHtml || '<div style="padding:24px;text-align:center;color:' + colors.textTertiary + ';">No memories for this page</div>'}
    </div>
    <div class="ltm-panel-footer">
      <a href="#" class="ltm-panel-link" id="ltm-open-dashboard">
        View all in Dashboard
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
          <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
          <polyline points="15 3 21 3 21 9"/>
          <line x1="10" y1="14" x2="21" y2="3"/>
        </svg>
      </a>
    </div>
  `;
  
  document.body.appendChild(memoryPanel);
  memoryPanel.style.display = 'block';
  
  // Open dashboard link
  document.getElementById('ltm-open-dashboard').addEventListener('click', (e) => {
    e.preventDefault();
    chrome.runtime.sendMessage({ action: 'openDashboard', query: window.location.href });
  });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function formatDate(dateStr) {
  if (!dateStr) return '';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

// Listen for system theme changes
if (window.matchMedia) {
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    // Remove existing badge/panel to recreate with new colors
    const badge = document.getElementById('ltm-memory-badge');
    const panel = document.getElementById('ltm-memory-panel');
    if (badge) badge.remove();
    if (panel) panel.remove();
    memoryBadge = null;
    memoryPanel = null;
  });
}

console.log('🧠 Longterm Memory extension loaded');
