# FindLOINCDimensions

## Inputs

- `DATA/GroupKnownInformationTable/knownInformationGrouped.tsv` — one row per
  local `TEST_NAME`/`UNIT`, with `n`, `p_missing`, `deciles`, `LongName`,
  `prefix_meaning`, `suffix_meaning`, clustered into similarity groups by
  `group_id` / `group_path`.
- `scripts/systemPrompt.md` — the system prompt: the LOINC-expert role, a brief
  description of the Finnish lab coding system, how it maps onto the table's
  columns, the caveats about this data, and the definition of the six LOINC axes
  plus the LOINC mapping guidelines to follow.

## Outputs

- `DATA/FindLOINCDimensions/codesWithLoincDimensions.tsv` — every processed row
  of the input table, unchanged, with seven columns appended:
  - `has_component` — the analyte measured (English LOINC-style name).
  - `has_property` — `Substance Concentration`, `Mass Concentration`,
    `Presence or Threshold`, ...
  - `has_time_aspect` — `Point in time (spot)`, `24 hours`, ...
  - `has_system` — `Serum or Plasma`, `Blood`, `Urine`,
    `Cerebral spinal fluid`, ...
  - `has_scale_type` — `Qn`, `Ord`, `SemiQn`, `Nom`, `Nar`, `Doc`, `OrdQn`.
  - `has_method` — `Immunoassay`,
    `Nucleic acid amplification with probe detection`, ... only when the code
    indicates a method.
  - `is_panel` — `TRUE` when the code bundles several separately reported tests.

  These are named exactly as in `GetMeasurementOmopData`'s
  `measurement_concept_attributes.tsv`, so the inferred axes and the OMOP
  vocabulary's own axes are directly comparable. For the same reason the axis
  *values* are written as **full OMOP concept names, not LOINC abbreviations**
  (`Substance Concentration`, not `SCnc`) — otherwise the two tables could not
  be joined. `has_scale_type` is the one exception: OMOP itself stores it
  abbreviated. The prompt's per-axis value lists are the most frequent real
  values, derived by joining `DATA/ReferenceMappings/lab_data_summary.csv`
  (Finnish codes already mapped to OMOP concepts) with
  `measurement_concept_attributes.tsv` on `concept_id`.

  Any axis the model could not determine from the row is empty — an empty value
  means "not knowable from this row", which the prompt explicitly prefers over a
  guess.
- `DATA/FindLOINCDimensions/reflections.md` — one `# Group <id>` section per
  group, holding that group's reflection from the model: ideas to improve the
  process, gotchas, ambiguities and data problems it hit on those rows.
- `DATA/FindLOINCDimensions/loincDimensionsStats.md` — a stats report over
  `codesWithLoincDimensions.tsv`: how completely each axis could be filled, how
  many of the 6 core axes each row got, one section per axis with its top 10
  most-used values, and a **Findings** section in which the per-group
  reflections are sent back to the model and distilled into recurring key
  findings, suggested improvements, and systematic data problems.
- `DATA/FindLOINCDimensions/groupsCache/<group_id>.json` — the model's raw
  structured answer for one group, and `<group_id>_prompt.md` the exact prompt
  that produced it. The `.json` files are a **cache**: a re-run only calls the
  LLM for groups that have none, so the step is resumable and re-running it
  after a partial failure costs nothing for the groups already done.
- `DATA/FindLOINCDimensions/log.txt` — run log: `run.sh`'s `tee` capturing both
  its own output and the R script's `ParallelLogger` console output, per
  `development/STYLE.md`.

## Action

`scripts/findLoincDimensions.R` sends **one LLM call per similarity group**, in
parallel across workers, and joins the answers back into one table.

Each call is `systemPrompt.md` as the system prompt, plus the group's rows
rendered as a TSV table as the user message. The group is the unit of work
because the clustering puts near-identical codes together: sibling rows
disambiguate a truncated or misspelled code, and show whether two similar codes
are genuinely the same test or deliberately differ (specimen, fasting state,
unit).

The model returns **only the seven new fields per row**, keyed by a `row_id`
that the script assigns before prompting — not the whole table back. This keeps
the payload small, makes it impossible for the model to silently alter source
values (`n`, `deciles`, ...), and gives an unambiguous integer join key;
`TEST_NAME` alone would not work, since the same code recurs within a group with
different `UNIT`s. The join is guarded: `row_id`s that were never sent, or
returned twice, are dropped with a warning, and rows the model skipped keep
empty axes rather than silently shifting the table.

Each call also returns a short reflection on that group, collected into
`reflections.md`.

`scripts/summariseLoincDimensionsStats.R` then reports on the result: per-axis
completeness and top-10 values computed locally from the table, plus one further
LLM call — over the concatenated reflections, not per group — that distils them
into the report's **Findings** section. That call degrades gracefully: if it
fails, the statistics are still written and the Findings section says so.

## Env vars

- `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, `GOOGLE_APPLICATION_CREDENTIALS` —
  the Vertex AI project, region and service-account key, from the
  `ENVIRONMENTS/<ENV_NAME>.env` file selected by `--env`.
- `LLM_PROVIDER` — ellmer provider, default `google_vertex`.
- `LLM_MODEL` — model, default `gemini-2.5-pro`.
- `LLM_PARALLEL_WORKERS` — number of parallel workers; defaults to
  `detectCores() - 2`.

## How to run

```
./STEPS/FindLOINCDimensions/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME> \
    [--ngroups <N>] [--seed <N>] [--clean]
```

`--ngroups <N>` processes a **random sample** of `N` groups — used during
development to keep runs small and cheap. Omit it to process all groups. The
sample is random rather than the first `N` because groups come out of the
clustering in dendrogram order, so the first `N` are all neighbours in the tree
and cover only one corner of the data (the first 50 were all microbiology).

`--seed <N>` seeds that sample (default `1`), so a given `--seed`/`--ngroups`
pair always selects the same groups.

`--clean` deletes the per-group answer cache before running, forcing every
selected group to be asked again. **Use it after editing `systemPrompt.md` or
the output schema**: the cache is keyed on `group_id` alone, so without it a
re-run silently returns answers produced by the old prompt. It costs a full
re-run, so it is off by default.

```
./STEPS/FindLOINCDimensions/run.sh DATA --env build --ngroups 30 --clean
```
