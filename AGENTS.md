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

The project has two areas, each with its own steps and data folder:

- **MAPPING** — `STEPS/MAPPING/<step_name>/` holds the steps, and
  `DATA_MAPPINGS/` holds the mapping data (all the tables that map source lab
  codes and units to OMOP). The MAPPING steps **modify** this data.
- **SUMMARY** — `STEPS/SUMMARY/<step_name>/` holds the steps, and
  `DATA_SUMMARY/` holds the summary of the real Kanta data and everything
  derived from it. The SUMMARY steps **produce** this data; they never change
  the mappings.
- Later, a SUMMARY step uses `DATA_MAPPINGS/` (read-only) to harmonize the data
  in `DATA_SUMMARY/`.
- Inside a data folder, `<N>_<step_name>/` holds the data produced by that
  step, and `0_<InputName>/` holds the data the area starts from.

Put a new step in the area whose data it changes: a step that edits mapping
tables goes in MAPPING, anything that reads or builds on the summary goes in
SUMMARY.

See @development/STRUCTURE.md for the exact folder layout, file names, and
naming conventions.

## Creating a step

Creating a step means creating its whole folder,
`STEPS/<AREA>/<N>_<step>/`, and every file in it: `README.md`, `run.sh`, and `scripts/`. See
`development/STRUCTURE.md` for exactly what belongs in each file and how a
step folder is laid out, including the `<N>_` run-order prefix (and when a
step gets none). Add the step to its area's index, `STEPS/<AREA>/README.md`.

Inserting a step between two existing ones means renumbering every step of that
area from that point on — folder name, `DATA_<AREA>/` result folder, every other step's
`run.sh` path references to it, and its own README — not just adding a
decimal or a letter suffix.

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

Steps run in order within their area. See `STEPS/<AREA>/README.md` for the list
of steps of an area and the order they run in.

Before running a step, read its `STEPS/<AREA>/<step>/README.md` for what it needs
(inputs, environment variables, arguments) — do not guess; see
`development/STRUCTURE.md` for how a step's inputs and outputs are named and
located. Then run it:

```
./STEPS/<AREA>/<step>/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME> [<STEP FLAGS>]
```

`<PATH_TO_DATA_FOLDER>` is a full or relative path to the data folder of the
step's area (`DATA_SUMMARY/` or `DATA_MAPPINGS/`) — not just its name.

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