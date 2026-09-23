# AGENTS.md

This file is the instruction file for anyone — human or agent — **acting** in
this repository: the git workflow and the imperative checklist for scaffolding
new steps.

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
- `DATA/<step_name>` holds data used or produced by that step.

See @development/STRUCTURE.md for the exact folder layout, file names, and
naming conventions.

## Creating a step

Creating a step means creating its whole folder, `STEPS/<step>/`, and
every file in it: `README.md`, `run.sh`, and `scripts/`. See
`development/STRUCTURE.md` for exactly what belongs in each file and how a
step folder is laid out.

Once a step exists, `scripts/` is the source of truth for what that step
does — the behavior is whatever the code does, and the code is edited
directly. `run.sh` is only the standard command that runs it: it parses
arguments, loads the environment and resolves paths, and is the same
boilerplate for every step. Its `README.md` is the step's human-readable
description of that code: the one place a reader can understand the step
without reading it. A README that disagrees with the code is a bug in the
README. When changing a step's behavior:

1. change `scripts/` — it is the source;
2. update the step's `README.md` so it describes what the code now does.

## Running a step

Steps run in order. See `STEPS/README.md` for the full list of steps and the
order they run in.

Before running a step, read its `STEPS/<step>/README.md` for what it needs
(inputs, environment variables, arguments) — do not guess; see
`development/STRUCTURE.md` for how a step's inputs and outputs are named and
located. Then run it:

```
./STEPS/<step>/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME> [<STEP FLAGS>]
```

`<PATH_TO_DATA_FOLDER>` is a full or relative path to the `DATA/` folder —
not just its name.

`--env <ENV_NAME>` selects which `ENVIRONMENTS/<ENV_NAME>.env` file `run.sh`
loads.

`<STEP FLAGS>` are the step's own arguments, documented in its `README.md`.

A step never derives a path it can't be given — if a required file or table
is missing, it stops rather than guessing.

## Committing

Use the `commit` skill (`.claude/skills/commit/SKILL.md`) to commit changes —
it reviews the diff, groups commits by scope, and writes the commit message
in this repo's convention. Do not hand-roll a commit outside it. Only commit
when the user asks.