# Specification instructions for AI agents

The folder rules for `spec/` and the meaning of each stage are in the root
`README.md`.

- `documents/` in each design level holds the official PDF documents.
- `artifacts/` in each design level holds raw working files for the
  specification, such as draw.io sources, PDF exports, notes and drafts. They
  are not official documents.

## draw.io diagrams

- Editing `.drawio` files requires the draw.io MCP (see the root `CLAUDE.md`).
- To export a diagram to PDF, use the `drawio-to-pdf` skill in
  `.claude/skills/`. It writes the PDF into the same folder as the source file.
