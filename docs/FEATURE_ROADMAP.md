# Longterm Memory - World-Class Feature Implementation Plan

## Overview
Transform the dashboard, knowledge graph, and Chrome extension from "functional" to "world-class" with Google/Obsidian-level features.

**Total Features:** 14
**Completed:** 11 ✅
**Partial:** 1 🟡
**Remaining:** 2 🔴

---

## Progress Summary

| Feature | Status |
|---------|--------|
| Semantic Search | ✅ Complete |
| Command Palette (Cmd+K) | ✅ Complete |
| Timeline View | ✅ Complete |
| Insights Panel | ✅ Complete |
| Quick Capture Widget | 🔴 Not Started |
| Graph Clustering | 🔴 Not Started |
| Local Graph View | ✅ Complete |
| Path Finding | ✅ Complete |
| Time Animation | ✅ Complete |
| Search in Graph | ✅ Complete |
| Edge Labels | 🔴 Not Started |
| Highlight-to-Save | ✅ Complete |
| Auto-Suggestions | 🟡 Partial |
| Mini-Dashboard Popup | 🔴 Not Started |

---

## 🧠 DASHBOARD ENHANCEMENTS

### 1. Semantic Search [HIGH PRIORITY]
**Status:** ✅ Complete
**Impact:** Highest - This is the "magic" feature

**Implementation:**
- ✅ Search endpoint generates embedding via Ollama (LM Studio fallback)
- ✅ pgvector cosine similarity with ≥50% threshold
- ✅ Shows similarity scores in results
- ✅ "Find similar" button on any observation
- ✅ Dashboard API: `/api/search/semantic?q=query&limit=10`

---

### 2. Cmd+K Command Palette [HIGH PRIORITY]
**Status:** ✅ Complete
**Impact:** High - Keyboard-first power users

**Implementation:**
- ✅ Global keyboard shortcut (Cmd+K / Ctrl+K)
- ✅ Fuzzy search across observations, entities, tags
- ✅ Quick actions: navigation, filtering, search
- ✅ Keyboard navigation (arrows, enter, escape)
- ✅ Vue component with Fuse.js fuzzy matching

---

### 3. Timeline View [MEDIUM PRIORITY]
**Status:** ✅ Complete
**Impact:** High - Visual memory browsing

**Implementation:**
- ✅ Visual activity chart with day/week/month granularity
- ✅ Heatmap showing activity intensity
- ✅ Click to filter observations to that period
- ✅ Milestones highlighted in Insights view
- ✅ API endpoint for aggregated timeline data

---

### 4. Insights/Patterns Panel [MEDIUM PRIORITY]
**Status:** ✅ Complete
**Impact:** High - Automated discovery

**Implementation:**
- ✅ Tag correlation matrix
- ✅ Activity patterns by day
- ✅ Focus areas identification
- ✅ Milestones (high-importance observations)
- ✅ Dedicated Insights view in dashboard

---

### 5. Quick Capture Widget [LOW PRIORITY]
**Status:** 🔴 Not Started
**Impact:** Medium - Always-accessible input

**Requirements:**
- [ ] Floating button (bottom-right corner)
- [ ] Expands to quick input form
- [ ] Auto-suggest tags based on content
- [ ] Keyboard shortcut (Cmd+N)
- [ ] Collapse after save

---

## 🕸️ KNOWLEDGE GRAPH ENHANCEMENTS

### 6. Graph Clustering [HIGH PRIORITY]
**Status:** 🔴 Not Started
**Impact:** High - Auto-organize chaos

**Requirements:**
- [ ] Detect communities using tag co-occurrence or embedding similarity
- [ ] Color-code clusters
- [ ] Cluster labels (auto-generated or top tag)
- [ ] Toggle to show/hide cluster boundaries
- [ ] Click cluster to isolate

**Technical:**
- Louvain or label propagation algorithm
- Pre-compute clusters on backend
- Three.js convex hull for boundaries

---

### 7. Local Graph View [HIGH PRIORITY]
**Status:** ✅ Complete
**Impact:** Highest for graph - Makes it actually usable

**Implementation:**
- ✅ Click node → show only N-hop neighborhood
- ✅ Slider to adjust hop distance (1-4)
- ✅ "Expand" button to add connected nodes incrementally
- ✅ "Back to full graph" button
- ✅ Breadcrumb trail of focused nodes
- ✅ Smooth camera animation when focusing

---

### 8. Path Finding [MEDIUM PRIORITY]
**Status:** ✅ Complete
**Impact:** Medium - Discovery feature

**Implementation:**
- ✅ Select two nodes → show shortest path between them
- ✅ Highlight path edges in green
- ✅ Path info panel shows node sequence
- ✅ BFS algorithm on frontend graph
- ✅ Right-click menu: "Start Path From Here"

---

### 9. Time Animation [LOW PRIORITY]
**Status:** ✅ Complete
**Impact:** Medium - Cool visualization

**Implementation:**
- ✅ Play/pause button
- ✅ Scrubber to select time range
- ✅ Nodes appear as they're created
- ✅ Watch your knowledge grow over time
- ✅ Speed control (1x-5x)

---

### 10. Search in Graph [MEDIUM PRIORITY]
**Status:** ✅ Complete
**Impact:** High - Find nodes quickly

**Implementation:**
- ✅ Search input in graph view
- ✅ Fuzzy match node names
- ✅ Matching nodes highlighted, others faded
- ✅ Click result to focus (local graph view)
- ✅ Real-time filtering as you type

---

### 11. Edge Labels [LOW PRIORITY]
**Status:** 🔴 Not Started
**Impact:** Low - Nice to have

**Requirements:**
- [ ] Show connection reason on hover
- [ ] Toggle to show all labels
- [ ] Edge thickness = connection strength

---

## 🔌 CHROME EXTENSION ENHANCEMENTS

### 12. Highlight-to-Save [HIGH PRIORITY]
**Status:** ✅ Complete
**Impact:** Highest for extension - Most natural capture flow

**Implementation:**
- ✅ Context menu: Right-click → "Longterm Memory Database" submenu
- ✅ Save Selection, Save Selection + Context, Save Entire Page
- ✅ Includes page URL, title, and surrounding context
- ✅ Native messaging to local Python host

---

### 13. Auto-Suggestions [MEDIUM PRIORITY]
**Status:** ✅ Partial - Memory Badge Complete
**Impact:** Medium - Proactive capture

**Implementation:**
- ✅ Memory badge shows count of memories from current site
- ✅ Badge color indicates presence (green) or absence (gray)
- ✅ URL caching for performance
- [ ] Visit frequency tracking (future)
- [ ] "Save this page?" prompts (future)
- [ ] Dismissable, with "don't ask for this site" option

---

### 14. Bi-directional Sync [MEDIUM PRIORITY]
**Status:** 🔴 Not Started
**Impact:** High - Memory-augmented browsing

**Requirements:**
- [ ] Show badge count: "3 memories from this domain"
- [ ] Click badge → see your notes about this site
- [ ] Inline highlights of previously saved text
- [ ] "Related memories" sidebar panel
- [ ] Quick link to dashboard filtered by this domain

**Technical:**
- Query memories by current domain on page load
- Overlay highlights on matching text
- Badge updates via background script

---

## Implementation Order (Suggested)

### Phase 1: Core Magic ✨
1. **Semantic Search** - The "wow" feature
2. **Local Graph View** - Makes graph usable
3. **Highlight-to-Save** - Natural capture

### Phase 2: Power User 💪
4. **Cmd+K Command Palette** - Keyboard mastery
5. **Graph Clustering** - Visual organization
6. **Search in Graph** - Find anything

### Phase 3: Insights 🔮
7. **Timeline View** - Temporal browsing
8. **Insights Panel** - Automated discovery
9. **Bi-directional Sync** - Augmented browsing

### Phase 4: Polish ✨
10. **Path Finding** - Connection discovery
11. **Auto-Suggestions** - Proactive capture (REMOVED - buggy)
12. **Quick Capture Widget** - Always accessible (REMOVED - redundant)
13. **Time Animation** - Visual history
14. **Edge Labels** - Graph details
15. **Design System** - Token-based CSS, accessibility, components

---

## Progress Tracker

| # | Feature | Priority | Status | Est. Time |
|---|---------|----------|--------|-----------|
| 1 | Semantic Search | 🔥 High | ✅ DONE | 2-3 hrs |
| 2 | Cmd+K Palette | 🔥 High | ✅ DONE | 2-3 hrs |
| 3 | Timeline View | 🟡 Med | ✅ DONE | 3-4 hrs |
| 4 | Insights Panel | 🟡 Med | ✅ DONE | 4-5 hrs |
| 5 | Quick Capture | 🟢 Low | ❌ REMOVED | - |
| 6 | Graph Clustering | 🔥 High | 🟡 Partial | 3-4 hrs |
| 7 | Local Graph View | 🔥 High | ✅ DONE | 2-3 hrs |
| 8 | Path Finding | 🟡 Med | ✅ DONE | 2-3 hrs |
| 9 | Time Animation | 🟢 Low | ✅ DONE | 3-4 hrs |
| 10 | Search in Graph | 🟡 Med | ✅ DONE | 1-2 hrs |
| 11 | Edge Labels | 🟢 Low | 🔴 TODO | 1 hr |
| 12 | Highlight-to-Save | 🔥 High | ❌ REMOVED | - |
| 13 | Auto-Suggestions | 🟡 Med | ❌ REMOVED | - |
| 14 | Bi-directional Sync | 🟡 Med | ✅ DONE | 3-4 hrs |
| 15 | Design System | 🔥 High | ✅ DONE | 4-5 hrs |

**Completed:** 11/15 features (73%)
**Removed:** 3 features (Quick Capture, Highlight-to-Save, Auto-Suggestions)
**Remaining:** Edge Labels (low priority), Graph Clustering (partial)

---

## Design System Details

The design system includes:
- **CSS Custom Properties**: Colors, spacing, typography, shadows, transitions
- **Component Library**: Buttons, cards, inputs, badges, modals, toasts
- **Utility Classes**: Tailwind-style helpers using design tokens
- **Accessibility**: Skip links, ARIA labels, focus styles, 44px touch targets
- **Documentation**: DESIGN_SYSTEM.md with usage examples

See `dashboard/DESIGN_SYSTEM.md` for complete documentation.

---

## Notes

- All features should respect light/dark/system theme ✅
- Mobile responsiveness for dashboard (tablet at minimum) ✅
- Keyboard accessibility throughout ✅
- Performance: lazy load, virtualize long lists, debounce searches ✅

---

*Last Updated: November 26, 2025*
*Let's build something world-class.* 🚀
