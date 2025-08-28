# Liquid Glass Redesign Blueprint

## Project Overview

**Goal:** Transform the Longterm Memory dashboard from "functional Tailwind template" to "Apple iOS 26 / macOS Tahoe 26 premium aesthetic"

**Design Language:** Apple's Liquid Glass (WWDC 2025)
- Translucent surfaces that refract light
- Floating controls that adapt to context
- Rounded corners matching hardware edges
- Three-layer depth: highlight, shadow, illumination
- Dark-mode-first with seamless light mode support

**Target Aesthetic:** "This looks like it ships with macOS Tahoe"

---

## Design Principles

### 1. Translucency Over Opacity
- Surfaces should reveal what's behind them
- Use `backdrop-filter: blur()` extensively
- Layer transparency creates depth without heaviness

### 2. Floating, Not Anchored
- Controls float above content
- Navigation shrinks/expands based on context
- Elements feel like they exist in 3D space

### 3. Rounded Harmony
- Border radius matches Apple hardware (large, consistent)
- No sharp corners except for text/content
- Concentricity: nested elements share center points

### 4. Subtle Motion
- Micro-animations for state changes
- Smooth transitions (300-500ms, ease-out)
- Nothing jarring or attention-grabbing

### 5. Content First
- UI recedes, content advances
- Generous whitespace
- Typography does the heavy lifting

---

## Color System

### Dark Mode (Primary)

```css
/* Backgrounds */
--bg-base: #000000;                    /* True black base */
--bg-primary: rgba(28, 28, 30, 0.8);   /* Elevated surfaces */
--bg-secondary: rgba(44, 44, 46, 0.6); /* Cards, panels */
--bg-tertiary: rgba(58, 58, 60, 0.4);  /* Subtle highlights */

/* Glass Surfaces */
--glass-bg: rgba(255, 255, 255, 0.05);
--glass-border: rgba(255, 255, 255, 0.1);
--glass-highlight: rgba(255, 255, 255, 0.15);
--glass-blur: 20px;

/* Text */
--text-primary: rgba(255, 255, 255, 0.95);
--text-secondary: rgba(255, 255, 255, 0.7);
--text-tertiary: rgba(255, 255, 255, 0.5);
--text-quaternary: rgba(255, 255, 255, 0.3);

/* Accent */
--accent-primary: #0A84FF;             /* Apple Blue */
--accent-purple: #BF5AF2;              /* Purple (our brand, subdued) */
--accent-green: #30D158;               /* Success */
--accent-orange: #FF9F0A;              /* Warning */
--accent-red: #FF453A;                 /* Error/Destructive */
--accent-teal: #64D2FF;                /* Info */

/* Semantic */
--color-success: #30D158;
--color-warning: #FF9F0A;
--color-error: #FF453A;
--color-info: #64D2FF;
```

### Light Mode

```css
/* Backgrounds */
--bg-base: #F2F2F7;                    /* System gray 6 */
--bg-primary: rgba(255, 255, 255, 0.8);
--bg-secondary: rgba(255, 255, 255, 0.6);
--bg-tertiary: rgba(0, 0, 0, 0.03);

/* Glass Surfaces */
--glass-bg: rgba(255, 255, 255, 0.7);
--glass-border: rgba(0, 0, 0, 0.1);
--glass-highlight: rgba(255, 255, 255, 0.9);

/* Text */
--text-primary: rgba(0, 0, 0, 0.85);
--text-secondary: rgba(0, 0, 0, 0.6);
--text-tertiary: rgba(0, 0, 0, 0.4);
--text-quaternary: rgba(0, 0, 0, 0.25);
```

---

## Typography

### Font Stack
```css
--font-system: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", Arial, sans-serif;
--font-mono: "SF Mono", SFMono-Regular, ui-monospace, Menlo, Monaco, monospace;
```

### Scale (Apple HIG)
```css
--text-caption2: 11px;    /* Smallest labels */
--text-caption1: 12px;    /* Captions */
--text-footnote: 13px;    /* Footnotes */
--text-subhead: 15px;     /* Subheadlines */
--text-body: 17px;        /* Body text */
--text-title3: 20px;      /* Small titles */
--text-title2: 22px;      /* Medium titles */
--text-title1: 28px;      /* Large titles */
--text-largetitle: 34px;  /* Hero text */
```

### Weights
```css
--font-regular: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

---

## Spacing System

### Base Unit: 4px

```css
--space-0: 0;
--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-5: 20px;
--space-6: 24px;
--space-8: 32px;
--space-10: 40px;
--space-12: 48px;
--space-16: 64px;
--space-20: 80px;
```

---

## Border Radius

```css
--radius-sm: 8px;         /* Small elements */
--radius-md: 12px;        /* Buttons, inputs */
--radius-lg: 16px;        /* Cards */
--radius-xl: 20px;        /* Large cards */
--radius-2xl: 24px;       /* Panels */
--radius-3xl: 32px;       /* Modals */
--radius-full: 9999px;    /* Pills, avatars */
```

---

## Glass Effect Implementation

### Basic Glass Surface
```css
.glass {
  background: var(--glass-bg);
  backdrop-filter: blur(var(--glass-blur)) saturate(180%);
  -webkit-backdrop-filter: blur(var(--glass-blur)) saturate(180%);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-xl);
}
```

### Glass with Highlight (Top Edge Light)
```css
.glass-highlight {
  background: var(--glass-bg);
  backdrop-filter: blur(var(--glass-blur)) saturate(180%);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-xl);
  box-shadow: 
    inset 0 1px 0 0 var(--glass-highlight),
    0 4px 24px -4px rgba(0, 0, 0, 0.3);
}
```

### Floating Glass (Elevated)
```css
.glass-floating {
  background: var(--glass-bg);
  backdrop-filter: blur(30px) saturate(200%);
  border: 1px solid var(--glass-border);
  border-radius: var(--radius-2xl);
  box-shadow: 
    0 8px 32px -8px rgba(0, 0, 0, 0.4),
    0 0 0 1px rgba(255, 255, 255, 0.05);
}
```

---

## Component Specifications

### Navigation Bar
- **Behavior:** Shrinks on scroll, expands on scroll-up (iOS 26 style)
- **Background:** Glass effect with 20px blur
- **Height:** 64px default → 48px compact
- **Position:** Fixed, floating with margin from edges
- **Border radius:** 16px (pill-like)

### Sidebar
- **Background:** Semi-transparent (80% opacity)
- **Width:** 280px expanded, 72px collapsed
- **Icons:** SF Symbols style, 24px
- **Active indicator:** Pill background with accent color at 15% opacity

### Cards
- **Background:** Glass surface
- **Border:** 1px solid rgba(255,255,255,0.1)
- **Shadow:** Subtle, layered
- **Hover:** Slight scale (1.01) + increased brightness
- **Border radius:** 16px

### Buttons
- **Primary:** Solid accent color, no border
- **Secondary:** Glass surface with border
- **Ghost:** Transparent, border on hover
- **Height:** 44px (touch target minimum)
- **Border radius:** 12px (or full for icon buttons)

### Inputs
- **Background:** rgba(255,255,255,0.05)
- **Border:** 1px solid rgba(255,255,255,0.1)
- **Focus:** Border becomes accent color, subtle glow
- **Height:** 44px
- **Border radius:** 10px

### Search Bar
- **Background:** Glass with magnifying glass icon
- **Placeholder:** "Search memories..." in tertiary text
- **Command hint:** "⌘K" badge on right side
- **Border radius:** 12px

### Memory Cards
- **Layout:** Clean, minimal metadata
- **Title:** Body text, semibold
- **Date:** Caption text, tertiary color
- **Tags:** Small pills with glass background
- **Entity link:** Subtle icon, hover reveals full name

### Stats Cards
- **Background:** Solid color at low opacity (15-20%)
- **Icon:** SF Symbol style, accent color
- **Number:** Large title weight
- **Label:** Caption text below

---

## Animation Specs

### Transitions
```css
--ease-default: cubic-bezier(0.4, 0, 0.2, 1);
--ease-in: cubic-bezier(0.4, 0, 1, 1);
--ease-out: cubic-bezier(0, 0, 0.2, 1);
--ease-spring: cubic-bezier(0.175, 0.885, 0.32, 1.275);

--duration-fast: 150ms;
--duration-base: 200ms;
--duration-slow: 300ms;
--duration-slower: 500ms;
```

### Hover States
- Cards: `transform: scale(1.01); transition: 200ms ease-out`
- Buttons: `filter: brightness(1.1); transition: 150ms`
- Links: `opacity: 0.8 → 1; transition: 150ms`

### Page Transitions
- Fade in: `opacity: 0 → 1; 300ms ease-out`
- Slide up: `translateY(8px) → 0; 300ms ease-out`

### Loading States
- Skeleton pulse: Subtle shimmer animation
- Spinner: Apple-style segmented circle

---

## Layout Structure

### Main Layout
```
┌─────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────┐   │
│  │            Floating Nav Bar                  │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  ┌──────────┐  ┌───────────────────────────────┐   │
│  │          │  │                               │   │
│  │ Sidebar  │  │         Main Content          │   │
│  │ (Glass)  │  │         (Scrollable)          │   │
│  │          │  │                               │   │
│  │          │  │                               │   │
│  └──────────┘  └───────────────────────────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Dashboard Grid
```
┌─────────┬─────────┬─────────┬─────────┐
│  Stat   │  Stat   │  Stat   │  Stat   │
└─────────┴─────────┴─────────┴─────────┘

┌───────────────────────────────────────┐
│            Search Bar                  │
└───────────────────────────────────────┘

┌───────────────────────────────────────┐
│                                       │
│           Memory Cards                │
│         (Masonry or List)             │
│                                       │
└───────────────────────────────────────┘
```

---

## File Structure

```
dashboard/static/
├── liquid-glass.css          # NEW: Complete redesign
├── liquid-glass-components.css # NEW: Component library
├── design-tokens.css          # UPDATE: New color system
├── components.css             # DEPRECATE: Old components
├── utilities.css              # KEEP: Utility classes
├── index.html                 # UPDATE: New markup structure
└── graph.html                 # UPDATE: Match new aesthetic
```

---

## Implementation Phases

### Phase 1: Foundation (Current)
- [x] Create design blueprint (this document)
- [ ] Create liquid-glass.css with new design tokens
- [ ] Create base glass component classes

### Phase 2: Core Components
- [ ] Navigation bar (floating, collapsible)
- [ ] Sidebar (glass, collapsible)
- [ ] Cards (memory cards, stat cards)
- [ ] Buttons (all variants)
- [ ] Inputs and search bar

### Phase 3: Dashboard Rebuild
- [ ] Update index.html structure
- [ ] Apply new component classes
- [ ] Implement scroll-based nav behavior
- [ ] Add micro-animations

### Phase 4: Knowledge Graph
- [ ] Update graph.html to match
- [ ] Glass panels for controls
- [ ] Consistent color palette

### Phase 5: Polish
- [ ] Light mode refinement
- [ ] Responsive breakpoints
- [ ] Accessibility audit
- [ ] Performance optimization

---

## Quality Checklist

### Visual
- [ ] Looks native to macOS Tahoe
- [ ] Glass effects render correctly
- [ ] Colors are harmonious
- [ ] Typography is crisp and readable
- [ ] Spacing feels balanced

### Interaction
- [ ] Hover states feel responsive
- [ ] Transitions are smooth (60fps)
- [ ] Click targets are 44px minimum
- [ ] Focus states are visible
- [ ] Scroll behavior is natural

### Technical
- [ ] Works in Safari, Chrome, Firefox
- [ ] Dark mode is seamless
- [ ] Light mode is polished
- [ ] Mobile is usable (tablet minimum)
- [ ] Performance is snappy

---

## Reference Links

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- iOS 26 Liquid Glass announcement: https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/
- CSS backdrop-filter: https://developer.mozilla.org/en-US/docs/Web/CSS/backdrop-filter
- CSS-Tricks Liquid Glass: https://css-tricks.com/getting-clarity-on-apples-liquid-glass/

---

## Notes for Future Agents

If you're continuing this work:

1. **Read this entire document first** - It contains all the design decisions
2. **Dark mode is primary** - Design for dark first, adapt to light
3. **Less is more** - When in doubt, remove visual noise
4. **Test in Safari** - Our users are on macOS, Safari is the reference browser
5. **Preserve functionality** - The current features must all still work
6. **Use the design tokens** - Don't hardcode colors or spacing
7. **Check the glass effects** - backdrop-filter can be performance-heavy

### Key Files to Understand
- `/dashboard/static/index.html` - Main dashboard markup
- `/dashboard/static/graph.html` - Knowledge graph page
- `/dashboard/app.py` - Flask backend (routes, API)
- `/dashboard/DESIGN_SYSTEM.md` - Previous design documentation

### Testing Commands
```bash
# Start the dashboard
cd $HOME/Documents/GitHub/longterm-memory-macos/dashboard
python app.py

# Access at http://localhost:5555
```

---

*Last Updated: November 26, 2025*
*Design Language: Apple Liquid Glass (iOS 26 / macOS Tahoe 26)*
