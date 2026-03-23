You are working on the PocketDev iOS application.

This is a structured, spec-driven project. You must follow the orchestration system strictly.

## Step 1 — Load Source of Truth

Read and internalize the following files:

- ORCHESTRATOR.md
- DESIGN.md
- TOKENS.md
- UI_SPEC.md
- COMPONENT_MAP.md
- ARCHITECTURE.md
- BUILD_ORDER.md

These files are the ONLY source of truth.
Ignore all previous conversation context and do not rely on memory.

---

## Step 2 — Execution Rules

You must follow these rules:

1. Do NOT redesign anything
2. Do NOT invent new UX patterns
3. Do NOT add features outside Phase 1 scope
4. Do NOT implement everything at once
5. Always build vertical slices end-to-end
6. Every UI must match DESIGN.md and UI_SPEC.md
7. All styling must come from TOKENS.md
8. All UI must be built from COMPONENT_MAP.md primitives
9. Follow ARCHITECTURE.md for structure and modules

If something is unclear:
- ask a question instead of guessing

---

## Step 3 — Stitch MCP Integration

Stitch MCP is connected.

Project ID: <PUT_YOUR_STITCH_PROJECT_ID_HERE>

Rules for using Stitch:
- Use Stitch ONLY for UI generation/refinement
- Always follow UI_SPEC.md when generating screens
- Apply TOKENS.md and COMPONENT_MAP.md strictly
- Do NOT redesign existing screens
- Do NOT introduce new components or layout patterns

Stitch is a rendering tool, not a design authority.

---

## Step 4 — First Task (MANDATORY)

Implement ONLY the first vertical slice:

Home → New Project → Explorer → Open File → Edit → Save

Requirements:
- Fully functional flow end-to-end
- Include all relevant states (empty, loading, error, success)
- Maintain clear state visibility (dirty, active file, etc.)
- Follow all UX rules from DESIGN.md

---

## Step 5 — Output Format

For this task, you must:

1. Explain the implementation plan
2. Generate the folder/project structure
3. Provide Swift code for:
   - screens
   - components
   - services
   - models
4. Explain how each part maps to:
   - DESIGN.md
   - UI_SPEC.md
   - ARCHITECTURE.md

Do NOT skip explanations.

---

## Step 6 — Constraints

- iOS native (Swift)
- SwiftUI for app shell
- UIKit allowed for editor if needed
- Local-first only (no Git, SSH, AI)

---

## Step 7 — Quality Gate

Before finishing, verify:

- Primary action is obvious on every screen
- Context is always visible
- No unnecessary UI noise
- All states are handled
- Behavior is predictable and consistent

If not — fix before output.

---

Begin.