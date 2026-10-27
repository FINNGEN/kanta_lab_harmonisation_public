# STRUCTURE.md

This file is the map of the repository. It describes what the project is, how it
is laid out, and the naming and file conventions every part must follow. Read it
before creating or modifying anything.

For the git workflow and the imperative checklists for scaffolding new steps,
see `AGENTS.md`. For language and style rules, see `development/STYLE.md`.

---

## What this project is

This repository organizes a **research project as a reproducible, composable
pipeline**. The project is a sequence of small, single-purpose *steps*. A step
runs one action (data conversion, a mapping search, a fit, a plot…), reads
the outputs of previous steps from a data folder, and writes its own results
back into a data folder.

The project has **two areas**, each with its own steps and its own data folder:

| Area | Steps | Data | What it holds |
|---|---|---|---|
| **MAPPING** | `STEPS/MAPPING/` | `DATA_MAPPINGS/` | The mapping tables (source lab code and unit → OMOP concept, target unit, conversion…). The MAPPING steps **modify** these tables. |
| **SUMMARY** | `STEPS/SUMMARY/` | `DATA_SUMMARY/` | The summary of the real Kanta data (counts, unit and value sources, value deciles), and everything derived from it. SUMMARY steps only **produce** new results; they do not change the mappings. |

At some point a step uses the mapping tables in `DATA_MAPPINGS/` to harmonize
the summary data in `DATA_SUMMARY/`. That step belongs to the SUMMARY area: it
reads `DATA_MAPPINGS/` read-only and writes into `DATA_SUMMARY/`.

The design goals:

- **Reproducible** — every step is a script driven by an environment file.
  Rerunning a step on the same inputs gives the same outputs.
- **Composable** — steps chain by reading each other's output folders.
- **Legible** — a fixed folder layout and naming convention means any reader (or
  agent) can find inputs, outputs, actions, and conclusions without guessing.

---

## Structure

```
.
├── AGENTS.md                      # agent instructions, workflow, scaffolding checklist
├── README.md                      # project aim, broad terms
├── development/
│   ├── STRUCTURE.md               # this file — project structure + naming conventions
│   └── STYLE.md                   # languages and style rules
├── ENVIRONMENTS/
│   ├── LOCAL.env                  # env vars for one environment (UPPERCASE name)
│   └── <ENV_NAME>.env             # one file per environment → --env <ENV_NAME>
├── STEPS/
│   ├── README.md                  # index: the areas
│   ├── MAPPING/                   # steps that modify the mapping tables
│   │   ├── README.md              # index: the MAPPING steps, in the order they run
│   │   └── <N>_<ActionInPascalCase>/
│   └── SUMMARY/                   # steps that work on the summary of the real data
│       ├── README.md              # index: the SUMMARY steps, in the order they run
│       └── <N>_<ActionInPascalCase>/  # a step: its position + the action it performs
│           ├── README.md          # purpose, inputs, outputs, action, env vars, how to run
│           ├── run.sh             # entry point: run.sh <DATA-folder> --env <name> [flags]
│           └── scripts/           # R / Python / SQL / other, called by run.sh
│               └── ...
├── DATA_MAPPINGS/                 # data of the MAPPING area
│   ├── 0_<InputName>/             # mapping tables the project starts from (not a step result)
│   └── <N>_<ActionInPascalCase>/  # results of a MAPPING step
│       └── log.txt                # run log, written by every step
├── DATA_SUMMARY/                  # data of the SUMMARY area
│   ├── 0_<InputName>/             # data that enters from outside the repo (not a step result)
│   └── <N>_<ActionInPascalCase>/  # a SUMMARY step's results, folder named after the step
│       └── log.txt                # run log, written by every step
├── DOCUMENTAION/                  # explanatory documents (diagrams, table descriptions)
├── RESEARCH/                      # background reading and notes
└── ARCHIVE/                       # earlier versions of steps and data, kept for reference
```

Each data folder is flat: a step writes its results directly into
`DATA_<AREA>/<N>_<ActionInPascalCase>/`, no intermediate folder. `ARCHIVE/` is
frozen: nothing in it is run or read by a current step.

### Top-level files

- **README.md** — the project aim in broad terms. What question the project
  exists to answer, who it is for. No implementation detail.
- **AGENTS.md** — the agent's instruction file: git
  workflow and the imperative checklist for scaffolding steps.
- **development/STRUCTURE.md** — this file. The project structure and naming
  conventions.
- **development/STYLE.md** — which languages are allowed where, and the style
  rules for each. `run.sh` is always bash; it may call R, Python, SQL, or other
  tools, which live in the step's `scripts/` folder.
- **ENVIRONMENTS/`<env>`.env** — one file per environment. Holds the shared
  variables for that environment (paths, credentials handles, dataset roots,
  cohort names). `run.sh` loads exactly one of these, selected by `--env`.

### STEPS/

- **README.md** — an index of the areas (`MAPPING`, `SUMMARY`).

Each area folder has its own **README.md**, an index listing every step of the
area in the order they run, and one subfolder per step, named
`<N>_<ActionInPascalCase>`: a zero-based number giving its position in run
order **within its area**, an underscore, then the action in PascalCase
(verb-first, e.g. `BuildX`, `FindY`, `FitZ`) — e.g. `1_BuildX`, `2_FindY`. A
step that reads one or more already-finished runs rather than occupying a
position in the pipeline (a cross-run comparison or audit utility) has no
number prefix. Step names are unique across areas, so a step is identified by
its name alone.

- **README.md** — starts with a one- or few-sentence **purpose** statement
  (what the step is for, in plain terms) right after the title, then documents
  the step: **inputs** (which previous step folders / files it reads),
  **outputs** (what it writes), the **action** it performs, the **env vars** it
  needs, and **how to run it** (exact `run.sh` invocation).
- **run.sh** — the entry point. Contract:
  - **Arg 1**: path to the data folder of the step's area (`DATA_SUMMARY/` for
    a SUMMARY step, `DATA_MAPPINGS/` for a MAPPING step).
  - **`--env <name>`**: which environment to load. `run.sh` sources
    `ENVIRONMENTS/<name>.env` (three levels up from the step folder,
    `../../../ENVIRONMENTS/`).
  - Additional flags as needed, documented in the step's README. A step that
    needs the other area's data (e.g. the step that harmonizes the summary data
    with the mappings) takes its path as a flag and treats it as read-only.
  - The step **reads** previous steps' output folders directly under its data
    folder, and **writes** its own results into
    `DATA_<AREA>/<N>_<ActionInPascalCase>/` — a folder named after the step
    itself.
  - The step **writes a run log** to
    `DATA_<AREA>/<N>_<ActionInPascalCase>/log.txt` (see
    [Run logging](#run-logging) below).
- **scripts/** — the R / Python / SQL / other scripts that `run.sh` calls. No
  business logic in `run.sh` beyond arg parsing, env loading, and invoking these.

### DATA_MAPPINGS/

The mapping data. It holds the mapping tables, the plain, hand-editable files
that say how a source lab code, unit and value become an OMOP concept, a target
unit and a conversion. This data is **modified** by the steps in
`STEPS/MAPPING/`: a MAPPING step updates the tables here, and the tables stay
under version control, so every change to a mapping is a reviewable diff.

- `0_<InputName>/` holds the tables the project starts from (e.g.
  `0_MappingTables`). It is not the result of a step; it is the number `0`
  position of the area.
- `<N>_<ActionInPascalCase>/` holds what a MAPPING step writes (its tables and
  its `log.txt`).

### DATA_SUMMARY/

The summary data: everything computed from the **real** Kanta data. The real
data itself never enters the repository, only its summary (counts of
`TEST_NAME` + `UNIT` pairs, where unit and value came from, value deciles, with
small counts removed). This data is produced by the steps in `STEPS/SUMMARY/`
and never changes the mappings.

- `0_<InputName>/` holds the summary that enters from outside the repo (e.g.
  `0_KantaSummaryTables`, written by `summarizePreprocessKantaData` on the
  sandbox). It is not the result of a step.
- `<N>_<ActionInPascalCase>/` holds a SUMMARY step's results, a folder named
  after the step, with its `log.txt`.

---

## Run logging

**Every step must record a log of its run and save it in its output folder as
`log.txt`** — i.e. `DATA_<AREA>/<N>_<ActionInPascalCase>/log.txt`. The log is a
first-class output: it makes a run auditable and reproducible, and it is what a
reader consults to see what happened when a step ran (config values used, inputs
read, actions taken, outputs written, warnings, errors).

- The log records the resolved configuration (env vars), the inputs read, the
  actions performed, and the outputs written — mirroring the script's named
  sections.
- The mechanics of *how* each language emits the log live in
  `development/STYLE.md`. In short: bash tees `run.sh` output to `log.txt`; **R
  uses `ParallelLogger`** (which also enables logging from parallel workers);
  Python uses the `logging` module writing to the same `log.txt`.

---

## File naming convention

Names are load-bearing: readers and agents locate inputs, outputs, and actions
from names alone. Follow these exactly.

| Thing | Convention |
|---|---|
| Area | **UPPERCASE**: `MAPPING`, `SUMMARY` — the folder under `STEPS/` |
| Area data folder | **`DATA_`** + the area's name in UPPERCASE, plural for the mappings: `DATA_MAPPINGS`, `DATA_SUMMARY` |
| Step folder | **`<N>_<ActionInPascalCase>`** — zero-based run-order number within its area, underscore, verb-first action |
| Step result folder (under the area's data folder) | **identical to the step folder**, numeric prefix included |
| Folder of data from outside the repo | **`0_<InputName>`**, the zero position of the area |
| Run log (in a step result folder) | **fixed literal** `log.txt` |
| Environment file | **UPPERCASE** + `.env` |
| Script in `scripts/` | **camelCase** + language extension |

Fixed literals (do not rename): the folder names `STEPS`, `MAPPING`,
`SUMMARY`, `DATA_MAPPINGS`, `DATA_SUMMARY`, `ENVIRONMENTS`, `scripts`; the file names `README.md`, `run.sh`, `log.txt`,
`AGENTS.md`, `development/STRUCTURE.md`, `development/STYLE.md`.

Rules:

- The `--env` value is the environment file's basename without extension, so
  file case and the flag value match: e.g. `FINNGEN.env` ⇒ `--env FINNGEN`.
- A step's result folder **must** be named identically to its step folder,
  numeric prefix included — that is how the next step finds its inputs.
- Step names are actions: start with a verb, PascalCase, no separators.
- Steps are numbered per area: `STEPS/MAPPING/` and `STEPS/SUMMARY/` each
  start their own count.
- The number is the step's position in run order, zero-based, renumbered
  (and every step's own folder, `run.sh` path references, and README
  renamed/updated together) whenever a step is inserted, removed, or reordered
  — it is never a stable id, only a position.
- A step that reads one or more already-finished runs rather than occupying a
  position in the pipeline (a cross-run comparison or audit utility, e.g.
  `CompareModelRuns`) carries no number prefix at all.
