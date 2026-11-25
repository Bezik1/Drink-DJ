# Python scripts of skills

Every Python file in this project, and above all the scripts of the skills in
`.claude/skills/`, follows these rules.

## Layout of a skill

**Every Python file of a skill is in the `scripts/` folder of that skill.** This
has no exceptions: the script, the helper modules and the packages. Never create
a `.py` file or a package next to `SKILL.md`.

```
.claude/skills/<skill-name>/
├── SKILL.md
└── scripts/              # only in a skill, that has Python code
    ├── <skill_name>.py
    ├── classes/
    ├── const/
    └── utils/
```

- `.claude/skills/<skill-name>/SKILL.md` describes the steps for the agent. The
  skill name is lowercase, with words separated by hyphens.
- The script has the name of the skill with underscores: `md-to-pdf` has
  `scripts/md_to_pdf.py`. It is the only file, that the user or the agent runs.
- `scripts/` is not a package, so it has no `__init__.py`.
- `SKILL.md` always gives the path with the folder, for example
  `python3 <skill>/scripts/md_to_pdf.py`.
- A script finds the other folders from its own path:

  ```python
  SCRIPTS = Path(__file__).resolve().parent
  SKILLS = SCRIPTS.parents[1]
  ROOT = SKILLS.parents[1]
  ```

- A bigger tool splits the code into packages inside `scripts/`, each with an
  `__init__.py`:
  - `classes/PascalCase.py`: one class in a file with the name of the class.
  - `const/general.py`: constants.
  - `utils/<topic>.py`: functions without state.
- A skill that needs another skill adds the `scripts/` folder of that skill to
  `sys.path`, for example `SKILLS / "docx-to-pdf" / "scripts"`, and imports
  `docx_to_pdf`. It never copies its code.
- Package folders must not be named like the packages of another skill, except
  `classes`, `const` and `utils` inside one skill.

## Code style

- Python 3.8 or newer. Only the standard library, unless `SKILL.md` names
  another requirement and the script reports a clear message, when it is missing.
- Classes are the unit of work: `__init__` prepares the object and `__call__`
  does the main action, for example `DocxToPdfConverter()(source, target)`.
  Plain functions are for the command line (`run_cli`, `parse_args`) and for
  stateless helpers in `utils/`.
- Names: `PascalCase` classes, `snake_case` functions, methods and variables,
  `UPPER_CASE` constants. Constants of a bigger tool are dictionaries by topic
  in `const/general.py`, such as `PATHS`, `SIZES`, `SEARCH`.
- Double quotes, f-strings and the `pathlib` module. No type annotations in
  signatures, because the types are described in the docstrings.
- Imports are in groups: standard library, then the skill's own modules. Each
  group is sorted.
- Comments inside code are rare. Explain with a docstring or with a better
  name. A comment is allowed only for something that the code cannot say.

## Docstrings

The documentation is generated from them (see "Code documentation" in the
`README.md`), so they are written for a reader of the generated pages. They are
in English, in the Google style.

- Every script and every package `__init__.py` starts with a module docstring of
  one or two sentences.
- Every class has a docstring with a summary and `Args:` for the constructor.
- Every public method and function, that is not trivial, has a docstring with
  a summary, `Args:` and `Returns:` (`Yields:`, `Raises:` when they apply). Types
  are in the form `Path`, `str[]`, `dict[]`, `tuple[Shape, Line][]`, and
  optional arguments say `optional` and their default.
- Rules and criteria of an algorithm are written as a short list in the docstring
  of the method, under `Rules:`, `Constraints:` or `Criterion:`.
- Helpers with an obvious name and body need no docstring.

## Command line and errors

- A script prints a usage line, when the arguments are wrong, and returns exit
  code `2` for that. Exit code `1` is a failed task, `0` is success. A
  validation script returns `1` for an invalid result.
- Expected failures are raised as `RuntimeError` with a message for the user,
  and the entry point catches `(RuntimeError, OSError, subprocess.TimeoutExpired)`
  and prints it. A traceback is shown only for a bug.
- The entry point is guarded with `if __name__ == "__main__":`, and it starts with
  `sys.stdout.reconfigure(errors="replace")`.
- Messages are short and say what to do, for example the install command of a
  missing program.

## Safety

- A script never changes or deletes its source file.
- It does not overwrite an existing output without `--force`. A file made by a
  person is not overwritten even with it, unless the user agrees.
- Temporary files go to the `tempfile` module. `sys.dont_write_bytecode = True`
  is set at the start, so no `__pycache__` appears in the repository.
- Every external program runs with a list of arguments (no shell), `stdin`
  closed, `capture_output` and a `timeout`.

## Works on every system

A script must run on macOS, Windows and Linux.

- Paths are built with `pathlib`, never with `/` or `\` in strings. Files are
  read and written with `encoding="utf-8"`.
- Programs are found with `shutil.which` and then with a list of the usual
  install paths of each system. A found program is run once with `--version`,
  to skip a broken launcher.
- No shell commands, no `bash`, `sed`, `awk`, `open` or `start`. If there is no
  portable way, the script needs a fallback for each system.
- `SKILL.md` writes `python3`, and says that `python` is used on Windows.

## Check before finishing

- No Python file of a skill is outside of `scripts/`. This prints an empty list:
  `python3 -c "import pathlib; print([str(p) for p in pathlib.Path('.claude/skills').rglob('*.py') if p.parts[3] != 'scripts'])"`
- The script runs with `python3` and with the oldest Python, that is installed.
- It leaves no `__pycache__` or temporary file in the repository
  (`git status`).
- `python3 scripts/generate_docs.py` finishes without an error and the new
  classes and methods appear in the documentation.
