# STYLE.md

Style rules for every language used in this repository. See
`development/STRUCTURE.md` for the folder layout, the `run.sh` contract, and the
run-logging rule.

**Language roles**

- **Bash** — every `STEPS/<Action>/run.sh` is bash. It parses arguments, loads
  the environment, validates inputs, and invokes the real work. No heavy logic.
- **R / Python / SQL / other** — the actual computation, in the step's
  `scripts/` folder, called by `run.sh`. Files are camelCase + language
  extension (e.g. `convertPhenotype.py`, `findCovariates.R`).

Every script — in any language — is divided into named sections, in order, each
headed by the same banner comment (adapted to the language's comment character):

```
#
# --- Section Name -------------------------------------------------------------
#
```

Use only the sections that apply, but keep them in the order given.

**Run logging.** Every step must write a run log to
`<working-folder>/<Step>/log.txt` (the rule lives in
`development/STRUCTURE.md`). The log mirrors the script's named sections —
resolved config, inputs read, actions taken, outputs written, warnings, and
errors. How each language emits it is described in its section below.

**Table output.** Never write the literal text `NA` for a missing value in
any table this project produces (TSV, CSV, or a markdown table) — use an
empty string instead. This applies to every language; see each language's
section below for the concrete mechanism (e.g. R's `readr::write_tsv(...,
na = "")`).

Symmetrically, when a script **reads** a TSV/CSV another step in this
project wrote, it must tell its parser that `""` — not the parser's own
default of `""`/`"NA"` — is the missing-value marker (e.g. R's
`readr::read_tsv(..., na = "")`). Without this, a column whose real values
can legitimately be the text `"NA"` (e.g. a `TEST_NAME` that really is
`"NA"`) gets silently corrupted into a true missing value on read, which
then gets written back out as `""` — quietly losing that row's real
identity. A file read from **outside** this project (a source table, an
external vocabulary) is unaffected and can keep the parser's own default.

---

## R Style

**Data manipulation:** use the **tidyverse** (`dplyr`, `tibble`, `tidyr`, `readr`, `purrr`, `stringr`, ...) where possible.

**Pipe:** always `|>` (native), never `%>%`.

**Table output:** `readr::write_tsv()` / `readr::write_csv()` default to writing
missing values as the text `NA` — always pass `na = ""` to write an empty
string instead, per the Table output rule above.

**Package-qualified calls:** use `package::function()` for all calls outside the current script's primary package. Omit qualification only for `library()` itself and for functions from a package that is the script's sole purpose (e.g. Capr functions inside a cohort generation script).

**Logging:** use **`ParallelLogger`**, never bare `message()`/`cat()`, for run logging. It writes a structured, timestamped log and also captures output from **parallel workers**, so the same code logs correctly whether it runs serially or in parallel. `run.sh` already tees all stdout/stderr to `log.txt`, so R must log to the **console**, not to its own file — a second file logger pointed at `log.txt` would be a second writer on the same file. Call only `clearLoggers()` at the top of the script and log through `logInfo()`/`logWarn()`/`logError()` thereafter — with no logger registered, `ParallelLogger` already echoes to the console by default:
```r
ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration: ...")
```
Do **not** also call `addDefaultConsoleLogger()` — it registers a second console
logger on top of the implicit default one, so every line prints twice.

This keeps every step to a single `log.txt`, combining bash's own output with R's structured log lines.

**Script sections:** structure every R script with these sections in order, each headed by:
```r
#
# --- Section Name -------------------------------------------------------------
#
```
Standard sections (use only those that apply):

| Section | Purpose |
|---------|---------|
| `Libraries` | `library()` calls |
| `Configuration` | `Sys.getenv()` → local vars + `ParallelLogger::logInfo()` each var |
| `Connections` | DB / API client setup using config vars |
| `Input` | Read input files |
| `Action` | Core logic |
| `Output` | Write output files |
| `Clean up` | Close connections, remove temp objects |

## Bash Style

**Logging:** `run.sh` tees its own stdout/stderr into `log.txt` so everything it and its child scripts print is captured. Do this right after `OUTDIR` is created, before any real work:
```bash
exec > >(tee "$OUTDIR/log.txt") 2>&1
```

**Script sections:** structure every `.sh` script with these sections in order, each headed by:
```bash
#
# --- Section Name -------------------------------------------------------------
#
```
Standard sections (use only those that apply):

| Section | Purpose |
|---------|---------|
| `Arguments` | Assign `$1`, `$2`, … to named vars; exit with usage if required args missing |
| `Configuration` | Source `$FOLDER/.env`; warn if not found and continue with env vars |
| `Input` | Validate required files and commands exist; exit with error if missing |
| `Action` | Core logic / tool invocation |
| `Output` | Confirm / echo produced files |

## Python Style

**Formatting:** PEP 8, 4-space indent, formatted with `black` (default line
length). Type-hint function signatures.

**Imports:** `import package` and call `package.function()`; keep the package
name visible at the call site rather than pulling names into the local
namespace. Use `from package import name` only for very common, unambiguous
names. Never `from package import *`.

**Configuration:** read env vars with `os.environ[...]` (required) or
`os.getenv(...)` (optional); assign to local vars and log each, mirroring the R
`Configuration` section.

**Table output:** `pandas.DataFrame.to_csv()` defaults to writing missing
values as an empty string already — leave `na_rep` at its default (do not
set it to `"NA"`), per the Table output rule above.

**Logging:** configure the `logging` module with a `FileHandler` pointed at
`log.txt` in the step's output folder, then log config, inputs, actions, and
outputs through it:
```python
logging.basicConfig(
    filename=os.path.join(out_dir, "log.txt"),
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
logging.info("Configuration: ...")
```

**Script sections:** structure every `.py` script with these sections in order, each headed by:
```python
#
# --- Section Name -------------------------------------------------------------
#
```
Standard sections (use only those that apply):

| Section | Purpose |
|---------|---------|
| `Imports` | `import` statements |
| `Configuration` | `os.environ` / `os.getenv()` → local vars + log each var |
| `Connections` | DB / API client setup using config vars |
| `Input` | Read input files |
| `Action` | Core logic |
| `Output` | Write output files |
| `Clean up` | Close connections, release resources |
