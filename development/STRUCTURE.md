# STRUCTURE.md

This file is the map of the repository. It describes what the project is, how it
is laid out, and the naming and file conventions every part must follow. Read it
before creating or modifying anything.

For language and style rules, see `development/STYLE.md`.

---

## What this project is

This repository organizes a **research project as a reproducible, composable
pipeline** that harmonises Kanta laboratory data: it maps each source lab test
and unit to a standard OMOP / LOINC concept, a target unit and a conversion.

The project is a sequence of small, single-purpose *steps*. A step runs one
action (data conversion, a mapping search, a plot…), reads the outputs of
previous steps from the data folder, and writes its own results back into it.

The design goals:

- **Reproducible** — every step is a script driven by an environment file.
  Rerunning a step on the same inputs gives the same outputs.
- **Composable** — steps chain by reading each other's output folders.
- **Legible** — a fixed folder layout and naming convention means any reader (or
  agent) can find inputs, outputs, actions, and conclusions without guessing.

---

## Two trees, three blocks

The project is split into two trees, **`SCRIPTS/`** (the code) and **`DATA/`**
(everything the code reads and writes). Both are divided into the same three
**blocks**, numbered in the order they are worked through:

| Block | What it holds |
|---|---|
| **`1_Input`** | The data we receive and want to map: the (summary of the) Kanta lab data — test names, units, counts, value distributions. |
| **`2_Harmonisation`** | The tables and data needed to map the input onto the target: the mapping tables (source test + unit → target concept, target unit, conversion) and everything built to produce and evaluate them. |
| **`3_Target`** | The target vocabulary the input is mapped into: the OMOP and/or LOINC data (concepts, units, groups…). |

`SCRIPTS/<Block>/` holds the steps that work on that block;
`DATA/<Block>/` holds the data of that block. A step lives in the block whose
data it writes. A step may read the data of other blocks, but only ever
**writes** into its own block's data folder; the data of other blocks is
read-only to it.

---

## Structure

```
.
├── README.md                      # project aim, broad terms
├── development/
│   ├── STRUCTURE.md               # this file — project structure + naming conventions
│   └── STYLE.md                   # languages and style rules
├── ENVIRONMENTS/
│   └── <ENV_NAME>.env             # one file per environment → --env <ENV_NAME>
├── SCRIPTS/
│   ├── 1_Input/
│   ├── 2_Harmonisation/
│   ├── 3_Target/
│   │   └── <N>_<ActionInPascalCase>/   # a step: its position + the action it performs
│   │       ├── README.md          # purpose, inputs, outputs, action, env vars, how to run
│   │       ├── run.sh             # entry point: run.sh <DATA-folder> --env <name> [flags]
│   │       └── scripts/           # R / Python / SQL / other, called by run.sh
│   │           └── ...
├── DATA/
│   ├── 1_Input/
│   ├── 2_Harmonisation/
│   ├── 3_Target/
│   │   ├── 0_<InputName>/         # data entering the block from outside (not a step result)
│   │   └── <N>_<ActionInPascalCase>/   # results of a step, folder named after the step
│   │       └── log.txt            # run log, written by every step
├── DOCUMENTATION/                 # explanatory documents (diagrams, table descriptions)
└── ARCHIVE/                       # previous version of the project; gitignored, frozen
```

`ARCHIVE/` is frozen and gitignored: nothing in it is run or read by a current
step.

### Top-level files

- **README.md** — the project aim in broad terms. What question the project
  exists to answer, who it is for. No implementation detail.
- **development/STRUCTURE.md** — this file.
- **development/STYLE.md** — which languages are allowed where, and the style
  rules for each. `run.sh` is always bash; it may call R, Python, SQL, or other
  tools, which live in the step's `scripts/` folder.
- **ENVIRONMENTS/`<env>`.env** — one file per environment. Holds the shared
  variables for that environment (paths, credential handles, dataset roots).
  `run.sh` loads exactly one of these, selected by `--env`.

### SCRIPTS/

One folder per block, each holding one subfolder per step, named
`<N>_<ActionInPascalCase>`: a zero-based number giving its position in run
order **within its block**, an underscore, then the action in PascalCase
(verb-first, e.g. `BuildX`, `FindY`). A step that reads one or more
already-finished runs rather than occupying a position in the pipeline (a
cross-run comparison or audit utility) carries no number prefix. Step names are
unique across blocks, so a step is identified by its name alone.

Each block folder also has a **README.md**, an index listing its steps in the
order they run.

- **README.md** — starts with a one- or few-sentence **purpose** statement
  right after the title, then documents the step: **inputs** (which folders /
  files it reads), **outputs** (what it writes), the **action** it performs,
  the **env vars** it needs, and **how to run it** (exact `run.sh` invocation).
- **run.sh** — the entry point. Contract:
  - **Arg 1**: path to the `DATA/` folder.
  - **`--env <name>`**: which environment to load. `run.sh` sources
    `ENVIRONMENTS/<name>.env` (from the repo root).
  - Additional flags as needed, documented in the step's README.
  - The step **reads** the data folders of any block directly under `DATA/`,
    and **writes** its own results into `DATA/<Block>/<N>_<ActionInPascalCase>/`
    — a folder named after the step itself, in the step's own block.
  - The step **writes a run log** to
    `DATA/<Block>/<N>_<ActionInPascalCase>/log.txt` (see
    [Run logging](#run-logging)).
- **scripts/** — the R / Python / SQL / other scripts that `run.sh` calls. No
  business logic in `run.sh` beyond arg parsing, env loading, and invoking these.

Once a step exists, `scripts/` is the source of truth for what it does; its
`README.md` must describe what the code does.

### DATA/

- **`1_Input/`** — the data to be mapped. The real Kanta data never enters the
  repository, only its summary (counts of `TEST_NAME` + `UNIT` pairs, where
  unit and value came from, value deciles, with small counts removed).
- **`2_Harmonisation/`** — the mapping tables and the data built around them.
  These are plain, hand-editable files under version control, so every change
  to a mapping is a reviewable diff.
- **`3_Target/`** — the OMOP / LOINC data the input is mapped into.

In every block:

- `0_<InputName>/` holds data that enters from outside the repo. It is not the
  result of a step; it is the number `0` position of the block.
- `<N>_<ActionInPascalCase>/` holds what a step writes (its results and its
  `log.txt`).

---

## Run logging

**Every step must record a log of its run and save it in its output folder as
`log.txt`** — i.e. `DATA/<Block>/<N>_<ActionInPascalCase>/log.txt`. The log is
a first-class output: it makes a run auditable and reproducible (config values
used, inputs read, actions taken, outputs written, warnings, errors).

- The log records the resolved configuration (env vars), the inputs read, the
  actions performed, and the outputs written — mirroring the script's named
  sections.
- The mechanics of *how* each language emits the log live in
  `development/STYLE.md`. In short: bash tees `run.sh` output to `log.txt`; **R
  uses `ParallelLogger`**; Python uses the `logging` module writing to the same
  `log.txt`.

---

## File naming convention

Names are load-bearing: readers and agents locate inputs, outputs, and actions
from names alone. Follow these exactly.

| Thing | Convention |
|---|---|
| Block | **`<N>_<Name>`** — `1_Input`, `2_Harmonisation`, `3_Target`; the same name under `SCRIPTS/` and `DATA/` |
| Step folder | **`<N>_<ActionInPascalCase>`** — zero-based run-order number within its block, underscore, verb-first action |
| Step result folder (under `DATA/<Block>/`) | **identical to the step folder**, numeric prefix included |
| Folder of data from outside the repo | **`0_<InputName>`**, the zero position of the block |
| Run log (in a step result folder) | **fixed literal** `log.txt` |
| Environment file | **UPPERCASE** + `.env` |
| Script in `scripts/` | **camelCase** + language extension |

Fixed literals (do not rename): `SCRIPTS`, `DATA`, `ENVIRONMENTS`, `scripts`,
`1_Input`, `2_Harmonisation`, `3_Target`; the file names `README.md`, `run.sh`,
`log.txt`.

Rules:

- The `--env` value is the environment file's basename without extension, so
  file case and the flag value match: e.g. `FINNGEN.env` ⇒ `--env FINNGEN`.
- A step's result folder **must** be named identically to its step folder,
  numeric prefix included — that is how the next step finds its inputs.
- Step names are actions: start with a verb, PascalCase, no separators.
- Steps are numbered per block, each block starting its own count at 0. The
  number is the step's position in run order, renumbered (with its result
  folder, `run.sh` path references and README) whenever a step is inserted,
  removed, or reordered — it is never a stable id, only a position.
