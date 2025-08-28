# Liquid Glass Implementation Roadmap

## Overview
Transform dashboard to Apple iOS 26 / macOS Tahoe 26 "Liquid Glass" aesthetic.

**Reference:** `LIQUID_GLASS_REDESIGN.md` for complete design specifications.

---

## Phase 1: Design Tokens & Foundation ⏱️ 30 min

### Task 1.1: Create liquid-glass.css
Create new CSS file with Apple-accurate design tokens:
- Dark mode color system (primary)
- Light mode color system
- Typography scale (SF Pro / system font)
- Spacing system (4px base)
- Border radius scale
- Animation/transition presets
- CSS custom properties for all values

### Task 1.2: Glass Effect Base Classes
- `.glass` - Basic translucent surface
- `.glass-highlight` - With top edge highlight
- `.glass-floating` - Elevated with shadow
- `.glass-solid` - Opaque variant for contrast

---

## Phase 2: Core Components ⏱️ 45 min

### Task 2.1: Navigation Components
- `.nav-floating` - Main navigation bar
- `.nav-compact` - Scrolled/compact state
- `.sidebar-glass` - Sidebar container
- `.nav-item` - Navigation items with active states

### Task 2.2: Button System
- `.btn-glass` - Base glass button
- `.btn-primary` - Solid accent button
- `.btn-secondary` - Outlined glass button
- `.btn-ghost` - Minimal/text button
- `.btn-icon` - Icon-only button (circular)
- Size variants: sm, md, lg

### Task 2.3: Card System
- `.card-glass` - Memory card container
- `.card-stat` - Statistics card
- `.card-interactive` - Hoverable cards
- `.card-header`, `.card-body`, `.card-footer`

### Task 2.4: Form Elements
- `.input-glass` - Text inputs
- `.search-glass` - Search bar with icon
- `.select-glass` - Dropdown select
- `.toggle-glass` - Toggle switches

### Task 2.5: Typography Classes
- `.text-title`, `.text-body`, `.text-caption`
- `.text-primary`, `.text-secondary`, `.text-muted`
- `.font-mono` for code

### Task 2.6: Utility Additions
- `.blur-bg` - Background blur utility
- `.glow-accent` - Subtle glow effect
- Spacing utilities using new scale

---

## Phase 3: Dashboard Rebuild ⏱️ 60 min

### Task 3.1: Page Structure
Update index.html with new layout:
```html
<body class="dark">
  <nav class="nav-floating glass-floating">...</nav>
  <aside class="sidebar-glass">...</aside>
  <main class="main-content">...</main>
</body>
```

### Task 3.2: Header/Stats Section
- Remove emoji icons, use minimal SVG or CSS shapes
- Stats cards with colored backgrounds at low opacity
- Clean typography hierarchy

### Task 3.3: Search Experience
- Full-width glass search bar
- Command palette hint (⌘K)
- Filter pills as glass buttons

### Task 3.4: Memory Cards Grid
- Glass card styling
- Cleaner metadata display
- Subtle hover animations
- Entity/tag pills

### Task 3.5: View Switcher
- Tab bar with pill-style active indicator
- Browse / Timeline / Insights views
- Smooth transitions between views

### Task 3.6: Pagination
- Glass-styled pagination controls
- Current page indicator

---

## Phase 4: Timeline & Insights Views ⏱️ 30 min

### Task 4.1: Timeline View
- Glass container for timeline
- Date headers with sticky positioning
- Memory entries with connecting line

### Task 4.2: Insights Panel
- Glass cards for each insight type
- Progress bars with accent colors
- Clean data visualization

---

## Phase 5: Knowledge Graph ⏱️ 30 min

### Task 5.1: Graph Page Update
- Match color palette with dashboard
- Glass control panels
- Consistent button styles
- Updated node colors

### Task 5.2: Graph Controls
- Floating glass panel for controls
- Slider styling
- Search overlay styling

---

## Phase 6: Command Palette ⏱️ 20 min

### Task 6.1: Modal Styling
- Centered glass modal
- Search input styling
- Results list styling
- Keyboard navigation indicators

---

## Phase 7: Polish & QA ⏱️ 30 min

### Task 7.1: Light Mode
- Test all components in light mode
- Adjust contrasts as needed
- Ensure readability

### Task 7.2: Responsive
- Tablet breakpoint (768px)
- Mobile considerations (480px)
- Collapsible sidebar behavior

### Task 7.3: Accessibility
- Focus states visible
- Color contrast ratios
- Screen reader labels
- Keyboard navigation

### Task 7.4: Performance
- Check for jank with backdrop-filter
- Optimize animations
- Test on lower-end hardware

### Task 7.5: Cross-Browser
- Safari (primary)
- Chrome
- Firefox (backdrop-filter fallbacks)

---

## Execution Order

1. **liquid-glass.css** - Design tokens (must be first)
2. **liquid-glass-components.css** - Component library
3. **index.html** - Dashboard markup updates
4. **graph.html** - Knowledge graph updates
5. **Testing & polish**

---

## Files to Create/Modify

### Create:
- `/dashboard/static/liquid-glass.css`
- `/dashboard/static/liquid-glass-components.css`

### Modify:
- `/dashboard/static/index.html`
- `/dashboard/static/graph.html`

### Keep (reference):
- `/dashboard/static/design-tokens.css` (old system)
- `/dashboard/static/components.css` (old components)
- `/dashboard/static/utilities.css` (still useful)

---

## Success Criteria

- [ ] Looks like a native macOS Tahoe app
- [ ] Glass effects work in Safari & Chrome
- [ ] Dark mode is beautiful
- [ ] Light mode is polished
- [ ] All existing features still work
- [ ] Performance is smooth (60fps animations)
- [ ] Accessible (keyboard nav, focus states)

---

## Estimated Total Time: ~4 hours

This is a significant visual overhaul but the underlying Vue.js logic remains unchanged. We're reskinning, not rebuilding.
