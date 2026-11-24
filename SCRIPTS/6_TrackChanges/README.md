# 6_TrackChanges

Keeps, for every `TEST_NAME[MEASUREMENT_UNIT]` pair, the list of commits that changed its harmonisation. The
details of each change (what was checked, what was decided, the result) are in the body of the commit, so the
git history is the log of the cases and this table is its index by pair.

This step has no scripts and no `run.sh`: the table is written when committing, by the `commit` skill
(`.claude/skills/commit/SKILL.md`).

## Inputs

None. The table is updated from the git history: `evaluatedHarmonisedKantaAgregatedTable.tsv` of
`DATA/5_EvaluateHarmonisedData/` before and after a commit.

## Outputs

In `DATA/6_TrackChanges/`:

- `TestCodeUnitChanges.tsv` — one row per pair with at least one change:

| Column | Description |
|---|---|
| `TEST_NAME` | The test of the pair |
| `MEASUREMENT_UNIT` | The unit of the pair as it arrives in Kanta (empty when there is none) |
| `changes` | Comma separated list of the commits that changed the pair, oldest first: the short commit hash (`a4bcce7`), or `#<issue>:<commit>` (`#12:a4bcce7`) when the change was made for a GitHub issue |

## Action

After a commit that changes `evaluatedHarmonisedKantaAgregatedTable.tsv` (a `DATA` commit, from an edit of
`2_Harmonisation` or a rerun after a change of the code), the commit skill runs

```
python3 .claude/skills/commit/logChanges.py <commit> [<issue_number>]
```

which adds the commit to the `changes` of every pair whose row differs from the parent commit in
`mapping_status`, `harmonisation_values_status`, `UNIT`, `concept_id`, `target_unit`, `HARMONISED_UNIT`,
`CONVERSION` or `mapping_warning_messages`, or that is new and mapped (not `MISSING`). A change of the KS alone
(e.g. because the reference of the pair changed) is not logged. The skill then reruns `7_BuildDashboard` and
commits the table and the dashboard.

`7_BuildDashboard` shows the list in the Change Log column of the Mapping Table, each commit and issue a link
to the GitHub repository of `github_url` in `DATA/settings.yaml`.

## Env vars

None.

## How to run

Nothing to run: see Action.
