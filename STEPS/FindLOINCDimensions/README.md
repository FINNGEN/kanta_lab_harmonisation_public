# FindLOINCDimensions

Guesses the **LOINC Long Common Name** of every local Finnish lab code.

## Inputs

- `DATA/GroupKnownInformationTable/knownInformationGrouped.tsv` — one row per
  local `TEST_NAME`/`UNIT`, with `n`, `p_missing`, `deciles`, `LongName`,
  `prefix_meaning`, `suffix_meaning`, clustered into similarity groups by
  `group_id` / `group_path`.
- `DATA/SourceLabelingData/loinc_names_frequency.tsv` — which LOINC concepts
  the curated Finnish mappings already use, and how much data they cover. The
  head of this table is injected into the prompt as worked examples; see
  `DATA/SourceLabelingData/README.md`.
- `scripts/systemPrompt.md` — the system prompt: the LOINC-expert role, the
  Finnish lab coding system, how it maps onto the table's columns, the caveats
  about this data, and the rules for building a LOINC Long Common Name. It
  carries a `{{FINNISH_NAME_EXAMPLES}}` placeholder that the script fills at
  run time with the frequency table's head.

## Outputs

- `DATA/FindLOINCDimensions/codesWithLoincNames.tsv` — every processed row of
  the input table, unchanged, with two columns appended:
  - `loinc_name_guess` — the LOINC Long Common Name the model believes this
    code maps to, spelled as LOINC spells it:
    `<Component> [<Property>] in <System> by <Method>`, e.g.
    `Creatinine [Moles/volume] in Serum or Plasma`. Empty when the model could
    not tell what the test measures — the prompt explicitly prefers an empty
    name to an invented one, since an invention sends the next step's search
    after a concept the code never meant.
  - `is_panel` — `TRUE` when the code orders a bundle of separately reported
    tests rather than one result.
- `DATA/FindLOINCDimensions/reflections.md` — one `# Group <id>` section per
  group, holding that group's reflection from the model: ideas to improve the
  process, gotchas, ambiguities and data problems it hit on those rows.
- `DATA/FindLOINCDimensions/loincNamesStats.md` — a stats report over
  `codesWithLoincNames.tsv`: how many codes could be named, how closely the
  guesses follow the LOINC name template, the most frequently guessed names and
  the `[Property]` / `in <System>` / `by <Method>` parts they carry, and a
  **Findings** section in which the per-group reflections are sent back to the
  model and distilled into recurring key findings, suggested improvements, and
  systematic data problems.
- `DATA/FindLOINCDimensions/groupsCache/<group_id>.json` — the model's raw
  structured answer for one group, and `<group_id>_prompt.md` the exact prompt
  that produced it, examples and all. The `.json` files are a **cache**: a
  re-run only calls the LLM for groups that have none, so the step is resumable
  and re-running it after a partial failure costs nothing for groups already
  done.
- `DATA/FindLOINCDimensions/log.txt` — run log: `run.sh`'s `tee` capturing both
  its own output and the R script's `ParallelLogger` console output, per
  `development/STYLE.md`.

## Action

`scripts/findLoincNames.R` sends **one LLM call per similarity group**, in
parallel across workers, and joins the answers back into one table.

The model is asked for a **name**, not for the six LOINC axes. The axes are
still how it reasons — component, property, time, system, scale, method — but
it returns the single string they compose into. That string is not expected to
be a real LOINC name: it is a **search query**. `FixLOINCDimensions` feeds it
to a semantic search over the LOINC vocabulary and asks a second pass to pick
the real concept it was aiming at.

This is why the step changed shape. An earlier version returned the six axes
and the mapping joined all of them, plus `is_panel`, against the OMOP
vocabulary's own columns. That join fires only when all seven land exactly
right, and on a 30-group sample it matched 287 of 1,940 rows while agreeing
with the curated Finnish mapping on 11.3% of the overlap. Guessing one string
well is a far easier target than guessing seven labels that must *all* be
exactly right.

The prompt therefore spends its length on how LOINC actually writes names: the
`<Component> [<Property>] in <System> by <Method>` template, the property
display forms (`[Moles/volume]`, not OMOP's `Substance Concentration`), the
fact that a plain point-in-time sample is written nowhere and a 24-hour
collection folds into the system slot (`in 24 hour Urine`), that nominal and
fraction terms drop the brackets entirely (`Bacteria identified in Urine by
Culture`, `Lymphocytes/Leukocytes in Blood`), and that Method is omitted for
most chemistry. The head of `loinc_names_frequency.tsv` is appended as worked
examples, so the model sees the exact current spelling of the concepts this
data really contains.

Each call is that system prompt plus the group's rows as a markdown table. The
group is the unit of work because the clustering puts near-identical codes
together: sibling rows disambiguate a truncated or misspelled code, and show
whether two similar codes are genuinely the same test or deliberately differ
(specimen, fasting state, unit).

The model returns **only the two new fields per row**, keyed by a `row_id` the
script assigns before prompting — not the whole table back. This keeps the
payload small, makes it impossible for the model to silently alter source
values (`n`, `deciles`, ...), and gives an unambiguous integer join key;
`TEST_NAME` alone would not work, since the same code recurs within a group
with different `UNIT`s. The join is guarded: `row_id`s that were never sent, or
returned twice, are dropped with a warning, and rows the model skipped keep an
empty name rather than silently shifting the table.

Each call also returns a short reflection on that group, collected into
`reflections.md`.

`scripts/summariseLoincNamesStats.R` then reports on the result: coverage and
name-shape statistics computed locally from the table, plus one further LLM
call — over the concatenated reflections, not per group — that distils them
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
- `FINNISH_NAME_EXAMPLES` — how many of the most-used Finnish LOINC names to
  inject into the prompt, default `100` (which covers ~90% of all records in
  the curated mappings).

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
