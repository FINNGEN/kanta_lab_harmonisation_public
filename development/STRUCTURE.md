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
runs one action (data conversion, covariate discovery, a fit, a plot…), reads
the outputs of previous steps from `DATA/`, and writes its own results back
into `DATA/`.

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
│   ├── README.md                  # index: the steps, in the order they run
│   └── <ActionInPascalCase>/      # a step, named as the action it performs
│       ├── README.md              # inputs, outputs, action, env vars, how to run
│       ├── run.sh                 # entry point: run.sh <DATA-folder> --env <name> [flags]
│       └── scripts/               # R / Python / SQL / other, called by run.sh
│           └── ...
└── DATA/
    └── <ActionInPascalCase>/  # a step's results, folder named after the step
        └── log.txt            # run log, written by every step
```

`DATA/` is a single flat folder: every step writes its results directly into
`DATA/<ActionInPascalCase>/`, no intermediate folder.

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

- **README.md** — an index listing every step, in the order they run.

One subfolder per step, named as an **action in PascalCase** (verb-first, e.g.
`ConvertX`, `FindY`, `FitZ`).

- **README.md** — documents the step: **inputs** (which previous step folders /
  files it reads), **outputs** (what it writes), the **action** it performs, the
  **env vars** it needs, and **how to run it** (exact `run.sh` invocation).
- **run.sh** — the entry point. Contract:
  - **Arg 1**: path to the `DATA/` folder.
  - **`--env <name>`**: which environment to load. `run.sh` sources
    `ENVIRONMENTS/<name>.env`.
  - Additional flags as needed, documented in the step's README.
  - The step **reads** previous steps' output folders directly under `DATA/`,
    and **writes** its own results into `DATA/<ActionInPascalCase>/` — a
    folder named after the step itself.
  - The step **writes a run log** to `DATA/<ActionInPascalCase>/log.txt`
    (see [Run logging](#run-logging) below).
- **scripts/** — the R / Python / SQL / other scripts that `run.sh` calls. No
  business logic in `run.sh` beyond arg parsing, env loading, and invoking these.

### DATA/

Where steps are run and their results land. Each step writes its results into
a subfolder named after the step (see above).

---

## Run logging

**Every step must record a log of its run and save it in its output folder as
`log.txt`** — i.e. `DATA/<ActionInPascalCase>/log.txt`. The log is a
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
| Step folder | **PascalCase, verb-first action** |
| Step result folder (under `DATA/`) | **identical to the step folder** |
| Run log (in a step result folder) | **fixed literal** `log.txt` |
| Environment file | **UPPERCASE** + `.env` |
| Script in `scripts/` | **camelCase** + language extension |

Fixed literals (do not rename): the folder names `STEPS`, `DATA`,
`ENVIRONMENTS`, `scripts`; the file names `README.md`, `run.sh`, `log.txt`,
`AGENTS.md`, `development/STRUCTURE.md`, `development/STYLE.md`.

Rules:

- The `--env` value is the environment file's basename without extension, so
  file case and the flag value match: e.g. `FINNGEN.env` ⇒ `--env FINNGEN`.
- A step's result folder **must** be named identically to its step folder — that
  is how the next step finds its inputs.
- Step names are actions: start with a verb, PascalCase, no separators.
