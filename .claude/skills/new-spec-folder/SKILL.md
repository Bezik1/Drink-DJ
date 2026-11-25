---
name: new-spec-folder
description: Creates a new specification subfolder under spec/ (for example spec/testing) with documents/, artifacts/, README.md and CLAUDE.md, and registers it in the root README. Use when the user asks to add a new design level, stage folder or specification subfolder.
---

# New specification folder

Creates a subfolder in `spec/` with the same layout as the existing ones.

## Input

- Folder name, for example `testing`.
- Title, for example "Testing Specification".
- Stage, from `ST01` to `ST04`.

Take them from the request and the stage list in the root `README.md`. Ask only
for a value, that cannot be determined from them.

## Steps

1. Check the name. It must be lowercase, with words separated by underscores
   (`_`). If `spec/<name>/` already exists, add only its missing parts and never
   overwrite a file.
2. Create `documents/` and `artifacts/` in `spec/<name>/`. Put an empty
   `.gitkeep` in each one, that has no files, as in `spec/physical/`. Without it
   Git does not track the folder.
3. Create `spec/<name>/README.md` in English:

   ```
   # <Title>

   ## Folder structure

   - `documents/`: official PDF documents of the <title lowercase>.
   - `artifacts/`: raw working files for the <title lowercase>, such as draw.io
     sources, notes and drafts.
   - `CLAUDE.md` and `README.md`: instructions for AI agents and this description.
   ```

4. Create `spec/<name>/CLAUDE.md`. It only imports the README, so the structure
   is written once:

   ```
   # <Title>

   For information about the <title lowercase> of this project, first read @README.md
   ```

5. Update the root `README.md`:
   - Add the folder to the "Repository layout" tree. Only the last folder uses
     `└──`. All `#` comments start in the same column, so move all of them when
     the new name is longer.
   - Add the folder to the row of its stage in the stage table.
6. Check with `git status --short --untracked-files=all`, that all 4 parts are
   visible to Git, and show the list to the user. Do not commit.

## Notes

- Do not move existing files into the new folder without asking.
