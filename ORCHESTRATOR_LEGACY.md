
# ORCHESTRATOR.md

## Purpose
Guide Claude Code to build PocketDev step-by-step using structured docs.

## Workflow
1. Read DESIGN.md
2. Read TOKENS.md
3. Read COMPONENT_MAP.md
4. Read UI_SPEC.md
5. Read ARCHITECTURE.md
6. Follow BUILD_ORDER.md

## Rules
- Do NOT implement everything at once
- Build vertical slices
- Respect state-driven UI
- No Git/SSH/AI in Phase 1

## First Task
Implement:
Home → New Project → Explorer → Open File → Edit → Save

## Stitch Integration

Stitch MCP is available. Stitch is a rendering tool, not a design authority.

Stitch Project ID: <YOUR_PROJECT_ID>

Rules:
- Use Stitch ONLY when generating or refining UI
- Always follow DESIGN.md and UI_SPEC.md as source of truth
- Do NOT invent UI outside the defined system
- When using Stitch:
  - map screens from UI_SPEC.md
  - apply tokens from TOKENS.md
  - reuse components from COMPONENT_MAP.md

Preferred workflow:
1. Read UI_SPEC.md
2. Generate or refine screen via Stitch MCP
3. Validate against DESIGN.md
4. Continue implementation

Do NOT:
- redesign screens already defined
- introduce new UX patterns
- override existing design decisions
- Do not add new UI elements