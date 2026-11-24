---
name: commit
description: Use whenever the user asks to commit changes (e.g. "commit", "commit this", "/commit"). Reviews the diff, groups it by area (Infra, SCRIPTS, Docs, DATA) and commits each area with an area-first message matching this repo's convention.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Read, Edit(**/README.md)
---

## Context

- Current branch: !`git branch --show-current`
- Current git status: !`git status`
- Changed files: !`git diff HEAD --stat`
- Recent commits: !`git log --oneline -10`

The tables under `DATA/` are large: read the diff of the code and the docs in full (`git diff HEAD --
SCRIPTS '*.md'`), and for `DATA/` only the `--stat` and the diff of the small files (reports `*.md`, the
hand-edited tables of `DATA/2_Harmonisation/`, `DATA/settings.yaml`, the `ignore` columns of the
`_warning.tsv` tables).

## Rules

- Commit only when the user asks. Never `git push`. Never `git commit --amend`.
- Never stage credentials or secrets (`ENVIRONMENTS/*.env` holding tokens or passwords, connection
  strings). If the diff has them, stop and flag them.
- If the diff has merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`), stop and flag them.
- Never stage what is gitignored or does not look intentional: `.scratchpad/`, `ARCHIVE/`, `renv/`,
  `.Rhistory`, `.DS_Store`, backups (`*.bck`), temporary files.
- Never stage the real Kanta data: only its summaries in `DATA/1_Input/0_KantaAgregatedData/` belong in
  the repo. Stop and flag a file there that is not one of the summary tables or `kanta_summary.md`.
- **Group by area, never by action or file.** All changes of one area go into **one** commit, however
  many edits it has. Split only when the changes span different areas, and never mix two areas in one
  commit.
- Commit the areas in this order: **Infra** → **SCRIPTS** → **Docs** → **DATA**. Shared files land before
  the code that relies on them, the docs after the code they describe, and the data, which is produced by
  the code, last.

## Areas

| Area | Paths |
|---|---|
| `Infra` | repo-wide and shared files: `AGENTS.md`, `CLAUDE.md`, `.claude/`, `development/`, `ENVIRONMENTS/`, `.gitignore` |
| `SCRIPTS` | the code of the steps: `SCRIPTS/**/run.sh`, `SCRIPTS/**/scripts/` |
| `Docs` | the READMEs: `README.md` and `SCRIPTS/**/README.md` |
| `DATA` | everything under `DATA/`: the hand-edited tables (`DATA/2_Harmonisation/`, `DATA/settings.yaml`, the `ignore` flags), the input summaries and the outputs of the steps |

## Keep the docs and the data in sync with the code

Before committing, check:

- **Docs**: each `README.md` of a changed step, and `README.md` when the change touches the process, the
  errors or the rerun order, still describes what the code does (see `AGENTS.md`). If not, make the
  **minimum** edits and commit them in the `Docs` commit.
- **DATA**: when `SCRIPTS` or a hand-edited table changed, the outputs of the affected steps were
  rerun (see "Rerunning after an edit" in `README.md`): their files are in the diff. If they are not, stop
  and tell the user which steps to rerun; do not run them from this skill.

## Commit message format

Subject line: `<Area>[ (<scope>)]: <summary>`

- **`<Area>`** — `Infra`, `SCRIPTS`, `Docs` or `DATA`.
- **`(<scope>)`** — optional, the steps or tables the change is about, without their number, comma
  separated: `(BuildDashboard)`, `(BuildHarmonisationTable, EvaluateHarmonisedData)`, `(Target)` for the
  steps of `3_Target`, `(Harmonisation)` for the tables of `DATA/2_Harmonisation/`, `(KantaAgregatedData)`
  for the input summaries. Leave it out when the change spans the whole pipeline (e.g. a rerun of all
  steps).
- **summary** — imperative, no trailing period, from the actual diff; the whole subject under ~72
  characters when it fits.

**Body (optional):** when one subject cannot cover all the changes of an area, or the *why* is not clear
from the diff (a mapping decision, a threshold, the effect of a rerun on the counts). Blank line after the
subject, free text or bullets wrapped at ~100 characters.

End every message with the co-author trailer the agent is told to use, if any.

```
Infra: Add AGENTS.md and the commit skill
SCRIPTS (BuildDashboard): Show the fixed unit in TestCode[Unit]
Docs (BuildKantaAgregatedTable): Describe test_outcome and the Test Outcomes section
DATA (Harmonisation): Map p-krea[mmol/l] to umol/l
DATA: Rerun steps 1, 4, 5 and 6
```

```
SCRIPTS (BuildKantaAgregatedTable, BuildDashboard): Add test_outcome and a Test Outcomes section

- Step 1 collapses summaryOutcomes.tsv into a test_outcome column of kantaAgregatedTable.tsv
- The summary and the Input Data tab show Reference Ranges after Values, then Test Outcomes
```

## Your task

Based on the context above, sort the changed files into the four areas, sync the docs and check the data
(see above), then stage and commit each area as **one** commit, in the order Infra → SCRIPTS → Docs →
DATA. If a rule blocks a commit, stop and explain why.

After committing, always list the commits in the chat, one line per commit, short hash + subject, in the
order they were made, even when there is only one:

```
- `<hash>` <subject line>
```
