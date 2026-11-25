---
name: drawio-to-pdf
description: Converts a draw.io (.drawio) diagram anywhere in the repository to a PDF in the same directory. Use when the user asks to export or convert a .drawio diagram to PDF.
---

# draw.io to PDF

Converts one `.drawio` file to PDF with the draw.io desktop app. The PDF is
written into the same directory as the source file. Works on macOS, Windows and
Linux.

## Input

A path to a `.drawio` file anywhere in the repository, for example
`spec/conceptual/erd.drawio`. The PDF goes next to it, here
`spec/conceptual/erd.pdf`.

## Steps

1. Check that the file exists.
2. Find the draw.io CLI. Use the first one that exists:
   - `drawio` or `draw.io` on the PATH (`command -v drawio`, or
     `where drawio` on Windows). This is the normal case on Linux, and it works
     on any system where the draw.io desktop app adds itself to the PATH.
   - macOS: `/Applications/draw.io.app/Contents/MacOS/draw.io`
   - Windows: `"C:\Program Files\draw.io\draw.io.exe"`, or the same path under
     `%LOCALAPPDATA%\Programs\draw.io\draw.io.exe` for a per-user install.
   - Linux: `/opt/drawio/drawio`, `/usr/bin/drawio`, or
     `/snap/bin/drawio`.

   If none exists, stop and tell the user, in their language, that draw.io is
   not installed and the export cannot run. Give them the download link
   `https://www.drawio.com/` and say that the desktop app is needed. For a
   Polish-speaking user, the message can be: "Nie znaleziono draw.io, a bez
   niego nie wyeksportuję PDF. Zainstaluj desktopową wersję draw.io
   (https://www.drawio.com/) i uruchom ponownie." Do not guess another path,
   and do not change any files.
3. Export it to PDF. The `-x` flag is the export command. `<dir>` is the
   file's directory and `<name>` is its base name, both relative to the project
   root:

   ```
   <drawio> -x -f pdf -a --crop -b 10 -o <dir>/<name>.pdf <dir>/<name>.drawio
   ```

   The flags matter:
   - `-a` exports all pages. Without it only the first page is written, and a
     diagram file with several diagrams loses the rest.
   - `--crop` fits each page to its diagram, so arrows and boxes are not cut
     off at the page edge.
   - `-b 10` adds a 10-point border around the diagram.

   Exception: an ERD of the `modify-erd` skill (`host="modify-erd"` in the
   `.drawio` file) has its padding in the page. Export it without `--crop` and
   `-b`, otherwise the padding is lost:

   ```
   <drawio> -x -f pdf -a -o <dir>/<name>.pdf <dir>/<name>.drawio
   ```

   Run this from the project root. On macOS the CLI may print a sandbox warning
   about `Operation not permitted`. It is harmless as long as the exit code is 0
   and the PDF exists.
4. Confirm that the PDF exists and is not empty.
5. Report the two paths to the user: the source `.drawio` and the new PDF.

## Notes

- A `.drawio` file can hold several diagrams, one per page. Check the page
  count of the PDF against the number of `<diagram` entries in the source.
- An empty diagram (no shapes) makes `--crop` fail with `Export failed`. If that
  happens, run the same command without `--crop` and tell the user that the
  diagram is empty.
- Do not overwrite an existing PDF next to the source without asking.
