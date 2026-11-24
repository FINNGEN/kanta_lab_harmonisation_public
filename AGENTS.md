# AGENTS.md

Instructions for agents working in this repository. The project and its pipeline are described in
`README.md`; this file only says how to work with it.

There are two ways to work with the repo. Find out from the request which one applies before changing
anything, and ask when it is not clear:

| Mode | What changes | Rules |
|---|---|---|
| **1. Development** | the code: `SCRIPTS/`, the READMEs, `development/` | `development/STRUCTURE.md`, `development/STYLE.md` |
| **2. Data** | the mapping: the hand-edited tables of `DATA/2_Harmonisation/` and the `ignore` flags of the warning tables | `README.md` (Errors along the process, Rerunning after an edit) |

Both modes end by rerunning the affected steps, so the files under `DATA/` always match the code and the
tables that produced them.

## Rules for both modes

- Do not commit until the user says so (see [Commit](#commit)).
- Never edit by hand a file a step writes (anything under a `DATA/<step>/` folder), except the `ignore`
  column of a `_warning.tsv`. Change the code or the input table and rerun the step instead.
- `3_Target` is built only from OMOP and lab2clean and is never edited; a fix to the target goes into
  `DATA/2_Harmonisation/harmonisedUnitOverwrite.tsv`.
- Write a lab test and its unit as `TEST_NAME[unit]` (see `development/STYLE.md`).
- Every step runs as `./SCRIPTS/<step>/run.sh DATA --env <ENV_NAME>` (e.g. `--env build`). Which steps to
  rerun after an edit is in the table "Rerunning after an edit" of `README.md`.

## Mode 1: Development

Work on the steps of the pipeline: their scripts, `run.sh`, validations, reports and the dashboard.

- Read `development/STRUCTURE.md` (layout, step naming, the `run.sh` contract, run logging) and
  `development/STYLE.md` (languages, script sections, logging, missing values written as `""`) before
  creating or changing a step.
- The code is the source of truth. When the code of a step changes, its `README.md` must still describe
  what the code does, and so must the main `README.md` when the change touches the process or the errors.
- An error the pipeline can meet must either stop it (a test of a `*.validation.md`) or be explained in
  `README.md` under "Errors along the process", with Label, Description, Source and Solution.
- Thresholds go in `DATA/settings.yaml`, not in the scripts.
- After a change, rerun the changed step and every step after it, check that each one exits with no error,
  and report what changed in its outputs.

## Mode 2: Data

Map Kanta codes and fix the errors the pipeline reports, by editing only these tables:

- `DATA/2_Harmonisation/unitFix.tsv` — the right `UNIT` of a `TEST_NAME[MEASUREMENT_UNIT]`;
- `DATA/2_Harmonisation/mapping.tsv` — the `concept_id` of a `TEST_NAME[UNIT]`, `APPROVED`,
  `ignore_mapping_reason`;
- `DATA/2_Harmonisation/unitHarmonisation.tsv` — the conversion from a `UNIT` to the target unit;
- `DATA/2_Harmonisation/harmonisedUnitOverwrite.tsv` — the target unit of a concept;
- the `ignore` column of the `_warning.tsv` tables of `DATA/4_BuildHarmonisationTable/` and of
  `DATA/5_EvaluateHarmonisedData/ks_test_warning.tsv`, to accept a reviewed finding.

How to work:

1. Find the problem in `DATA/6_BuildDashboard/dashboard.html`, in a `*.validation.md`, or in
   `mapping_status` / `harmonisation_values_status` of the step 4 and 5 tables.
2. Look up the error in `README.md` ("Errors along the process") and pick the Solution that fits. Do not
   set `ignore` to `TRUE` or `APPROVED` to `TRUE` without the user's confirmation: both are a decision that
   the mapping is right.
3. Edit the table, rerun from `4_BuildHarmonisationTable` (see "Rerunning after an edit"), and check that
   the validation report has no ERROR and that the pair now has the expected status.
4. Report what was changed, row by row, and its effect on the counts of the dashboard.

A problem in the input data itself (`DATA/1_Input/0_KantaAgregatedData/`) or in the code is not solved in
this mode: report it to the user.

## Commit

**NEVER COMMIT UNLESS THE USER SAYS SO.** Leave every change in the working tree, so the user can review
the diff of what the agent did before it is committed. Finishing a task, or a step running without errors,
is not a request to commit.

When the user asks to commit, use the `commit` skill (`.claude/skills/commit/SKILL.md`): it groups the
changes by area (Infra, SCRIPTS, Docs, DATA) and writes the messages. Never push, and never amend a commit,
unless the user asks.
