
# DESIGN.md — PockeDev (Refined, Stitch-Optimized)

## 0. Design Intent

PockeDev is a **precision mobile developer surface**.

This document refines the design system to align with:
- UX core principles (clarity, feedback, consistency, affordance)
- modern high-end developer tooling expectations
- “Google Stitch-style” system thinking:
  - composability
  - clarity of flows
  - predictable behavior
  - scalable primitives

---

# 1. UX Core Principles (Enforced)

## 1.1 Clarity > Power
Every screen must answer instantly:
- Where am I?
- What am I editing?
- What can I do next?

If not → redesign.

---

## 1.2 Single Source of Truth (UI + Data)
- File name = source of truth
- Dirty state = explicit, not inferred
- Active tab = always visible

Avoid:
- duplicated indicators
- hidden state
- implicit behavior

---

## 1.3 Direct Manipulation
- Tap file → opens file
- Edit → changes immediately visible
- Save → explicit action (Phase 1)

No hidden automation.

---

## 1.4 Predictability
Every interaction must be:
- repeatable
- reversible (when possible)
- consistent across screens

---

## 1.5 Feedback Everywhere
Every action must produce feedback:
- loading → visible
- success → subtle confirmation
- error → actionable

No silent failures.

---

## 1.6 Progressive Disclosure
Only show:
- what’s needed now
- at this level of complexity

Hide:
- future Git/AI/SSH complexity

---

# 2. Information Hierarchy (Critical Fixes)

## 2.1 Global hierarchy

Always maintain:

1. Context (project/file)
2. Content (editor / list)
3. Actions (controls)

Never invert this.

---

## 2.2 Editor priority
Editor must dominate visually:

- ≥80% of screen = content
- controls = secondary
- chrome = minimal

---

## 2.3 Action grouping
Group actions by intent:

- file actions (rename/delete)
- navigation (back, path)
- editing (save, search)

Do NOT mix these visually.

---

# 3. Navigation Model (Refined)

## 3.1 Navigation rules

Use:
- stack navigation for hierarchy
- modal for temporary flows
- overlay for transient tools (search)

Avoid:
- deep nested modals
- ambiguous back behavior

---

## 3.2 Entry points (final)

Home must have:

- Open File
- Open Folder
- New Project
- Clone Repo (optional)

Each must:
- feel equal priority
- be immediately actionable

---

# 4. Visual System Refinements

## 4.1 Contrast tuning (important)

Problem to avoid:
- “dark but muddy UI”

Fix:
- increase contrast between:
  - background vs surface
  - surface vs editor
  - active vs inactive

Rule:
> Every layer must be visually distinguishable in <100ms.

---

## 4.2 Accent discipline

Before:
- risk of overuse

Fix:
- accent is ONLY for:
  - focus
  - active tab
  - primary action
  - search matches

Never use accent for:
- decoration
- passive elements

---

## 4.3 Divider strategy

Replace heavy borders with:
- subtle separators
- spacing + alignment

Avoid:
- boxed UI everywhere

---

# 5. Component-Level UX Improvements

## 5.1 Tabs (critical improvement)

Problems to avoid:
- browser-like clutter
- small touch targets

Refinement:
- minimum touch size: 44pt
- visible active state
- close button only on active tab (future)

Overflow:
- horizontal scroll
- no wrapping

---

## 5.2 File Explorer

Refinements:
- highlight active file (not just selected)
- use indentation for hierarchy
- keep icons minimal

UX rule:
> User must scan 10 files in <2 seconds.

---

## 5.3 Editor

Key refinements:

### Cursor + selection
- high visibility caret
- clear selection contrast

### Active line
- subtle highlight improves orientation

### Horizontal padding
- prevents “edge fatigue”

---

## 5.4 Buttons

Refinement:
- reduce number of primary buttons

Rule:
> One primary action per screen.

Everything else:
- secondary / tertiary

---

## 5.5 Inputs

Refinement:
- persistent labels (not floating only)
- clear focus state
- no ambiguity

---

# 6. Motion System (Refined)

## 6.1 Duration rules
- micro: 100–150ms
- standard: 200–250ms
- modal: 250–300ms

---

## 6.2 Motion intent

Motion must:
- explain transitions
- maintain spatial continuity

Never:
- surprise
- distract

---

## 6.3 Key transitions

### File open
Explorer → Editor:
- slide + fade
- maintain context

### Tab switch
- instant or near-instant
- no heavy animation

### Search overlay
- fade + slight elevation

---

# 7. Error Handling UX (Missing Before)

## Must include:

### File errors
- “Cannot open file”
- “Cannot save file”

With:
- reason
- retry option

---

### Clone errors
- network issue
- invalid repo

---

### Empty states
Must always include:
- explanation
- next action

---

# 8. Performance UX (Critical)

## 8.1 Perceived performance

Even if slow:
- show progress
- show partial content

---

## 8.2 Editor responsiveness

Must guarantee:
- no typing lag
- no scroll jank

If needed:
- degrade features before performance

---

# 9. Accessibility Improvements

## Add explicitly:

- dynamic type support (within reason)
- color contrast ≥ WCAG AA
- touch targets ≥ 44pt
- non-color indicators (icons + text)

---

# 10. Stitch-Style System Thinking (Key Upgrade)

## 10.1 Composable primitives

Define core primitives:

- Surface
- ListItem
- Tab
- Button
- Input
- EditorView

All UI must be built from these.

---

## 10.2 State-driven UI

Every component must have explicit states:

Example:
Tab:
- active
- inactive
- dirty
- loading

Avoid implicit logic.

---

## 10.3 Deterministic flows

Every flow must be:

Input → State → UI → Feedback

No hidden transitions.

---

# 11. Design Anti-Patterns to Avoid

- Overusing glow / neon
- Treating code editor as “design canvas”
- Mixing too many metaphors (IDE + dashboard + chat)
- Overloading top bar
- Deep nested navigation
- Hidden gestures without affordance

---

# 12. Final Design Quality Checklist

Before shipping any screen:

- Is the primary action obvious?
- Is the current context obvious?
- Is the content readable at a glance?
- Is there unnecessary visual noise?
- Are all states handled?
- Does it feel native to iOS?
- Does it feel like a serious tool?

If any answer is “no” → iterate.

---

# 13. Final Experience Definition

PockeDev should feel like:

> a fast, precise, premium engineering tool where every interaction is intentional, every state is clear, and every surface respects the developer’s focus.

---

# 14. One-Line Rule

> If a feature makes the UI more impressive but less clear — remove it.

