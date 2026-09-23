---
name: commit
description: Use whenever the user asks to commit changes (e.g. "commit this", "commit the current step", "/commit"). Reviews the diff and commits with a scope-first message matching this repo's convention.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Read, Edit(**/README.md)
---

## Context

- Current branch: !`git branch --show-current`
- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Recent commits: !`git log --oneline -10`

## Rules

- Never stage files containing credentials or secrets (API keys,
  cloud credentials, connection configs with tokens). If the diff touches
  these, stop and flag them instead of committing.
- If the diff contains merge conflict markers (`<<<<<<<`, `=======`,
  `>>>>>>>`), stop and flag instead of committing.
- Don't blindly stage everything untracked — check `.gitignore` and be
  cautious of build artifacts, caches, dependency folders, and large/binary
  or data files that don't look intentional.
- **Group commits by area, never by action.** All changes belonging to the
  same subject scope go into a **single** commit, however many distinct edits
  they contain. If there are 2 (or more) `Infra` changes, make **one** `Infra`
  commit whose summary covers all of them — do not split it per file or per
  action. Only split across commits when changes span **different** subject
  scopes (a different `<line>/<step> (<location>)`, or `Infra` vs a line).
  Do not mix an `Infra` change, a `STEPS` code change, and a `DATA` change in
  the same commit.
- When one commit's summary must cover several changes in that area, write a
  concise combined subject and, if it doesn't fit, list the changes as bullets
  in the body.
- When splitting, commit in this order: **Infra** → **STEPS** (code) →
  **DATA** (results) → **Docs** (README sync edits) — shared/infra changes
  land before the steps that rely on them; generated results and the doc-sync
  commit land last.
- Never `git push`. Never `git commit --amend`. Only if explicitly asked.

## Keep docs in sync with code

Code and docs must stay in sync. Most folders carry a `README.md`; its required
format and content are defined in `AGENTS.md` / `CLAUDE.md`.

Before committing, check each change against the relevant `README.md`:

- **New/renamed/removed file, step, or working folder** → reflected in its
  folder's `README.md` (a new step also in the parent line's step list; a new
  line also in `LINES_OF_RESEARCH/README.md`).
- **Changed input/output, env var, run invocation, or action** → matches that
  step's `README.md` sections.

If already in sync, do nothing. Otherwise make the **minimum** edits (per the
`AGENTS.md` templates) and commit them last, as a single `Docs` commit.

## Commit message format

This repo is organized into lines of research, each a chain of steps that
read and write working folders (see `AGENTS.md`). The commit subject encodes
*where* in that structure the change lands, inferred from the changed paths.

Subject line: `<line_of_research>/<step> (<location>): <summary>`

- **`<line_of_research>`** — the affected `LINE_*` / `SUBLINE_*` folder under
  `LINES_OF_RESEARCH/`, copied verbatim (e.g.
  `LINE_CompareCohortsWithGenetics`). Use `Infra` instead when the change is
  **not** inside any line of research — repo-wide or shared files such as
  `AGENTS.md`, `ENVIRONMENTS/`, `development/STYLE.md`, `.claude/`,
  `LINES_OF_RESEARCH/README.md`, top-level `README.md`.
- **`<step>`** — the step folder being edited, i.e. the subfolder under the
  line's `STEPS/` or under a `DATA/<DATAFOLDER>/`, copied verbatim
  (PascalCase action name, e.g. `CompareSelectedVariants`).
- **`(<location>)`** — tells *which side* of the step changed:
  - `(STEPS)` — the step's code/docs was modified (under `STEPS/<step>/`).
  - `(DATA/<DATAFOLDER>)` — a data example / results subfolder was modified
    (under `DATA/<DATAFOLDER>/<step>/`), e.g. `(DATA/G6_PARKINSONS)`.
- **summary** — imperative, no trailing period, based on the actual diff.
  Keep the whole subject line under ~72 characters. Start it with a label
  verb (below).

For `Infra` there is no step or location — just `Infra: <summary>`.

**Labels** — the leading verb of the summary. Use the one that fits the
work; these suit a research pipeline better than software types:

- `Add` — new step, line, working folder, or file.
- `Update` / `Refine` — change an existing step's behavior or docs.
- `Fix` — correct a bug or wrong result.
- `Refactor` — restructure without changing behavior (e.g. conform a copied
  step to the repo layout).
- `Remove` / `Ignore` — delete files, or stop tracking them via `.gitignore`.
- `Record` / `Refresh` — save or regenerate run outputs, data, or plots in a
  working folder.
- `Docs` — README / AGENTS / STYLE changes only.
- `WIP` — a checkpoint save with no other clear label.

```
LINE_CompareCohortsWithGenetics/CompareSelectedVariants (STEPS): Refine all-studies effects as reference
LINE_CompareCohortsWithGenetics/CompareSelectedVariants (DATA/G6_PARKINSONS): Refresh conceptRatios.tsv
LINE_ChartReviewToRules/KeeperToCohort (STEPS): Add chart-review -> case/control cohort step
Infra: Docs clarify step result-folder naming in AGENTS.md
```

**Body (optional):** add one when the *why* isn't obvious from the diff —
a modeling choice, a tradeoff, a run's parameters or results. Skip for
small, self-explanatory changes. Blank line after the subject, then free
text wrapped at ~72 chars; bullets are fine.

```
LINE_CompareCohortsWithGenetics/CompareSelectedVariants (STEPS): Refine all-studies effects as reference

Per-cohort betas were noisy for rare variants; the all-studies
beta_all/se_all is the stable reference for the enrichment plot.
```

## Your task

Based on the context above, group the changes by subject **area** (scope) and
stage + commit each area as **one** commit — never split a single area into
multiple commits by action or file. Only produce more than one commit when
changes span different areas, committed in the order Infra → STEPS → DATA. Then
sync docs (see "Keep docs in sync with code") and commit any README edits last,
as a single `Docs` commit. If a rule blocks a commit, stop and explain why.
Otherwise stage and commit — no extra commentary beyond the summary below.

After committing, always show the resulting commit(s) in the chat as a
plain list, one line per commit, short hash + subject line, in the order
they were made — even when there's only one:

```
- `<hash>` <subject line>
```

This list is required output, not optional commentary.