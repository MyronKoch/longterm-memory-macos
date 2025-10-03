# Longterm Memory Design System

A comprehensive, accessible, token-based design system for the Longterm Memory dashboard.

## Overview

The design system consists of three CSS files:

1. **`design-tokens.css`** - CSS custom properties (variables)
2. **`components.css`** - Reusable UI components
3. **`utilities.css`** - Tailwind-style utility classes

## Quick Start

Include the CSS files in your HTML:

```html
<link rel="stylesheet" href="/static/design-tokens.css">
<link rel="stylesheet" href="/static/components.css">
<link rel="stylesheet" href="/static/utilities.css">
```

## Design Tokens

### Colors

```css
/* Brand */
--color-primary: #8b5cf6;
--color-primary-hover: #7c3aed;
--color-on-primary: #ffffff;

/* Surfaces */
--color-background: #f9fafb;
--color-surface: #ffffff;
--color-on-surface: #111827;
--color-on-surface-muted: #6b7280;

/* Semantic */
--color-success: #10b981;
--color-warning: #f59e0b;
--color-error: #ef4444;
--color-info: #3b82f6;
```

### Spacing (8px base)

```css
--space-1: 0.25rem;   /* 4px */
--space-2: 0.5rem;    /* 8px */
--space-3: 0.75rem;   /* 12px */
--space-4: 1rem;      /* 16px */
--space-6: 1.5rem;    /* 24px */
--space-8: 2rem;      /* 32px */
```

### Typography (Fluid)

```css
--text-xs: clamp(0.7rem, 0.65rem + 0.25vw, 0.75rem);
--text-sm: clamp(0.8rem, 0.75rem + 0.25vw, 0.875rem);
--text-base: clamp(0.9rem, 0.85rem + 0.25vw, 1rem);
--text-lg: clamp(1rem, 0.95rem + 0.25vw, 1.125rem);
--text-xl: clamp(1.125rem, 1rem + 0.5vw, 1.25rem);
```

### Shadows

```css
--shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.1);
--shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
--shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
--shadow-xl: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
```

## Components

### Buttons

```html
<!-- Primary -->
<button class="btn btn-primary">Primary Action</button>

<!-- Secondary -->
<button class="btn btn-secondary">Secondary</button>

<!-- Ghost -->
<button class="btn btn-ghost">Ghost Button</button>

<!-- Danger -->
<button class="btn btn-danger">Delete</button>

<!-- Sizes -->
<button class="btn btn-primary btn-sm">Small</button>
<button class="btn btn-primary btn-md">Medium</button>
<button class="btn btn-primary btn-lg">Large</button>

<!-- Icon Button -->
<button class="btn btn-icon btn-secondary" aria-label="Settings">⚙️</button>

<!-- Loading State -->
<button class="btn btn-primary" aria-busy="true">Loading...</button>
```

### Cards

```html
<!-- Elevated (default) -->
<div class="card card-elevated card-padding-md">
  Content here
</div>

<!-- Outlined -->
<div class="card card-outlined card-padding-md">
  Content here
</div>

<!-- Interactive -->
<button class="card card-elevated card-interactive card-padding-md">
  Clickable card
</button>

<!-- With sections -->
<div class="card card-outlined">
  <div class="card-header">Header</div>
  <div class="card-body">Body content</div>
  <div class="card-footer">Footer</div>
</div>
```

### Form Inputs

```html
<div class="form-group">
  <label class="form-label form-label-required" for="email">Email</label>
  <p class="form-hint" id="email-hint">We'll never share your email</p>
  <input 
    type="email" 
    id="email" 
    class="input" 
    aria-describedby="email-hint"
  >
</div>

<!-- With error -->
<div class="form-group">
  <label class="form-label" for="password">Password</label>
  <input type="password" id="password" class="input input-error" aria-invalid="true">
  <p class="form-error" role="alert">Password is required</p>
</div>

<!-- Sizes -->
<input class="input input-sm" placeholder="Small">
<input class="input" placeholder="Medium (default)">
<input class="input input-lg" placeholder="Large">
```

### Badges

```html
<span class="badge badge-primary">Primary</span>
<span class="badge badge-success">Success</span>
<span class="badge badge-warning">Warning</span>
<span class="badge badge-error">Error</span>
<span class="badge badge-info">Info</span>
<span class="badge badge-neutral">Neutral</span>
```

### Progress Bars

```html
<div class="progress">
  <div class="progress-bar" style="width: 60%"></div>
</div>

<!-- Variants -->
<div class="progress">
  <div class="progress-bar progress-bar-success" style="width: 80%"></div>
</div>
```

### Modals

```html
<div class="modal-overlay">
  <div class="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
    <div class="modal-header">
      <h2 class="modal-title" id="modal-title">Modal Title</h2>
      <button class="btn btn-icon btn-ghost" aria-label="Close">✕</button>
    </div>
    <div class="modal-body">
      Modal content here
    </div>
    <div class="modal-footer">
      <button class="btn btn-secondary">Cancel</button>
      <button class="btn btn-primary">Confirm</button>
    </div>
  </div>
</div>
```

## Accessibility

### Skip Link

```html
<a href="#main-content" class="skip-link">Skip to main content</a>
<!-- ... header ... -->
<main id="main-content">
```

### Screen Reader Only

```html
<span class="sr-only">Hidden text for screen readers</span>
```

### Focus Styles

All interactive elements have `:focus-visible` styles:

```css
:focus-visible {
  outline: 2px solid var(--color-focus);
  outline-offset: 2px;
}
```

### Touch Targets

Minimum 44x44px touch targets (WCAG 2.1):

```css
--touch-target-min: 44px;

button, a, [role="button"] {
  min-height: var(--touch-target-min);
}
```

### ARIA Labels

```html
<!-- Icon buttons need labels -->
<button class="btn btn-icon" aria-label="Search">🔍</button>

<!-- Toggle buttons -->
<button aria-pressed="true">Dark Mode</button>

<!-- Tabs -->
<div role="tablist">
  <button role="tab" aria-selected="true">Tab 1</button>
  <button role="tab" aria-selected="false">Tab 2</button>
</div>
```

## Dark Mode

The design system automatically supports dark mode via the `.dark` class on the HTML element:

```html
<html class="dark">
```

All color tokens automatically adjust for dark mode.

## Utility Classes

Layout, spacing, typography, and more utility classes are available in `utilities.css`. They follow Tailwind naming conventions:

```html
<!-- Flexbox -->
<div class="flex items-center justify-between gap-4">

<!-- Spacing -->
<div class="p-4 mt-2 mb-4">

<!-- Typography -->
<p class="text-lg font-semibold text-muted">

<!-- Colors -->
<div class="bg-surface border rounded-lg shadow-md">
```

## Best Practices

### DO ✅

- Use semantic HTML elements
- Add ARIA labels to icon buttons
- Ensure 44px minimum touch targets
- Use design tokens instead of hardcoded values
- Test with keyboard navigation
- Test with screen readers

### DON'T ❌

- Use `<div>` for buttons
- Skip focus styles
- Hardcode colors or spacing
- Forget alt text on images
- Create inaccessible modals

## Browser Support

- Chrome/Edge (last 2 versions)
- Firefox (last 2 versions)
- Safari (last 2 versions)

## File Structure

```
dashboard/static/
├── design-tokens.css    # CSS custom properties
├── components.css       # Reusable components
├── utilities.css        # Utility classes
├── index.html          # Dashboard
└── graph.html          # Knowledge graph
```
