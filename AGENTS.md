# AGENTS.md

This file is the instruction file for anyone — human or agent — **acting** in
this repository: the git workflow and the imperative checklists for scaffolding
new research lines, sublines, and steps.

Before acting, read the map:

- **`development/STRUCTURE.md`** — what the project is, its folder layout, and
  the naming/file conventions every part must follow, @development/STRUCTURE.md.
- **`development/STYLE.md`** — the languages allowed where, and the style and
  logging rules for each @development/STYLE.md.

---

## Agent instructions

Follow these when scaffolding. Placeholders are written `<Like This>`. For the
folder layout and naming rules these produce, see `development/STRUCTURE.md`.

## General behaviour of the project

- `STEPS/<step_name>/` holds the instructions and code to perform one.
- `DATA/<step_name>` holds data use or produced by that step.

See @development/STRUCTURE.md for the exact folder layout, file names, and
naming conventions.

## Creating a step

Creating a step means creating its whole folder, `STEPS/<step>/`, and
every file in it: `README.md`, `run.sh`, and `script/`. See `development/STRUCTURE.md` for exactly what
belongs in each file and how a step folder is laid out.

Once a step exists, `script/` is the source of truth for what that step
does — the behavior is whatever the code does, and the code is edited
directly. `run.sh` is only the standard command that runs it: it parses
arguments, loads the environment and resolves paths, and is the same
boilerplate for every step. Its `README.md` is the step's human-readable
description of that code: the one place a reader can understand the step
without reading it. A README that disagrees with the code is a bug in the
README. When changing a step's behavior:

1. change `script/` — it is the source;
2. update the step's `README.md` so it describes what the code now does;
3. record important project decisions in `.scratchpad/NOTES.md`.

Knowledge that applies to every register belongs in the step's code, not in
each `<register>.yaml`. A register's YAML carries only what is specific to
that register.

## Running a step

Steps run in order, one register at a time. See `STEPS/README.md` for the
full list of steps and the order they run in.

Before running a step, read its `STEPS/<step>/README.md` for what it needs
(inputs, environment variables, arguments) — do not guess; see
`development/STRUCTURE.md` for how a step's inputs and outputs are named and
located. Then run it:

```
./STEPS/<step>/run.sh <PATH_TO_DATA_FOLDER> [<STEP INPUTS>] [ENV]
```

`<PATH_TO_REGISTER_FOLDER>` is a full or relative path to the register
folder — not just its name — e.g. `REGISTERS/VISION_DATA`.

`<STEP INPUTS>` are the step's own arguments, positional and in the order its
`README.md` gives: `<TABLE>` for `CreateSummary`, the person register's folder
and an optional `FRACTION` for `GenerateDummyData`, none for a step that needs
none.

`ENV` is always last and defaults to `build`. A step never derives a path it
can't be given — if a required file or table is missing, it stops rather
than guessing.

## Committing

Use the `commit` skill (`.claude/skills/commit/SKILL.md`) to commit changes —
it reviews the diff, groups commits by scope, and writes the commit message
in this repo's convention. Do not hand-roll a commit outside it. Only commit
when the user asks.