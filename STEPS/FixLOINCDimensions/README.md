# FixLOINCDimensions

Corrects the LOINC axis labels produced by `FindLOINCDimensions` so they are
real OMOP vocabulary terms.

## Inputs

- `DATA/FindLOINCDimensions/codesWithLoincDimensions.tsv` — local Finnish lab
  codes with the six LLM-inferred LOINC axes and `is_panel`, in similarity
  groups (`group_id`).
- `DATA/SourceLabelingData/loinc_axes_frequency.tsv` — how often each axis value
  is used in curated Finnish mappings (`axe_name`, `name`, `concept_id`,
  `n_codes`, `n_events`). Built by `scripts/buildLoincAxesFrequency.R`; see
  that file's header and `DATA/SourceLabelingData/README.md`.
- `scripts/systemPrompt.md` — the system prompt for the correction pass.
- The **Hecate** API (`https://hecate.pantheon-hds.com`), a semantic search over
  the OMOP vocabularies, queried per axis value.

## Outputs

- `DATA/FixLOINCDimensions/codesWithFixedLoincDimensions.tsv` — the same
  columns as the input, with the axis values corrected.
- `DATA/FixLOINCDimensions/reflections.md` — one `# Group <id>` section per
  group: which corrections were made and why, and where the candidate lists
  fell short.
- `DATA/FixLOINCDimensions/hecateCandidates.tsv` — every Hecate lookup made
  (`axe_name`, `value`, `concept_name`, `concept_id`, `score`), cached across
  runs so re-runs do no network traffic. Not score-filtered: the threshold is
  applied when the candidates are used, so it can be changed without re-querying.
- `DATA/FixLOINCDimensions/groupsCache/<group_id>.json` — the model's raw
  answer for one group, and `<group_id>_prompt.md` the exact prompt. A **cache**:
  a re-run only calls the LLM for groups that have none.
- `DATA/FixLOINCDimensions/log.txt` — run log, including how many values
  changed per axis.

## Action

`FindLOINCDimensions` writes the axes as free text. Measured against the
curated Finnish mappings, most values were real OMOP terms but the wrong one,
and `has_component` drifted off the controlled vocabulary entirely — roughly
75% of its mismatches were near-miss paraphrases that exist nowhere in OMOP
(`Transglutaminase IgA Ab` for OMOP's `Tissue Transglutaminase IgA`,
`gamma-Glutamyl transferase` for `Gamma glutamyl transferase`). Since the
downstream mapping joins on exact axis values, a near miss fails exactly as
hard as nonsense.

`scripts/fixLoincDimensions.R` therefore, for the four free-text axes
(`has_component`, `has_property`, `has_method`, `has_system`):

1. Asks Hecate for the closest real LOINC terms to each distinct current value,
   filtered to that axis's concept class (`LOINC Component`, `LOINC Property`,
   `LOINC Method`, `LOINC System`), keeping candidates scoring at or above
   `HECATE_SCORE_THRESHOLD`. Lookups are deduplicated across the whole run —
   the same value recurs in many groups — and cached on disk.
2. Attaches each candidate's Finnish usage (`n_codes`, `n_events`) from the
   frequency table, so the model can break ties on established usage rather
   than guessing.
3. Sends each similarity group to the LLM with its rows and the candidate
   lists, and asks which label each row should carry: keep the current value
   when it is already an exact OMOP term, otherwise pick the candidate the
   row's own evidence supports, otherwise leave the axis empty. The model may
   not invent a value outside the candidate list.

`has_scale_type` and `has_time_aspect` are **not** searched: they already come
from closed lists embedded in `FindLOINCDimensions`' prompt, so they are
carried through unchanged, as is `is_panel`.

Rows the model fails to answer keep their **original** axis values rather than
being emptied, and the join is guarded the same way as in
`FindLOINCDimensions`: unknown or duplicated `row_id`s are dropped with a
warning rather than allowed to shift the table.

## Env vars

- `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, `GOOGLE_APPLICATION_CREDENTIALS` —
  Vertex AI project, region and service-account key, from the `--env` file.
- `LLM_PROVIDER` (default `google_vertex`), `LLM_MODEL` (default
  `gemini-2.5-pro`), `LLM_PARALLEL_WORKERS` (default `detectCores() - 2`).
- `HECATE_SCORE_THRESHOLD` — minimum similarity to keep a candidate, default
  `0.75`. Below this the search is returning a different concept rather than a
  spelling variant.
- `HECATE_CANDIDATE_LIMIT` — candidates requested per value, default `5`.
- `HECATE_PARALLEL_WORKERS` — parallel Hecate lookups, default `4` (kept
  modest: it is someone else's public API).

## How to run

```
./STEPS/FixLOINCDimensions/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME> \
    [--ngroups <N>] [--seed <N>] [--clean]
```

`--ngroups <N>` processes a random sample of `N` groups (`--seed`, default `1`,
makes the sample reproducible). `--clean` deletes the per-group LLM answer
cache, which is required after editing `systemPrompt.md` or the output schema
since the cache is keyed on `group_id` alone; the Hecate cache is kept, as it
depends only on the axis values.

```
./STEPS/FixLOINCDimensions/run.sh DATA --env build --ngroups 30
```

### Rebuilding the frequency table

Only needed when the reference mappings or the OMOP vocabulary snapshot change:

```
Rscript STEPS/FixLOINCDimensions/scripts/buildLoincAxesFrequency.R \
    DATA/ReferenceMappings/lab_data_summary.csv \
    DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv \
    DATA/SourceLabelingData/loinc_axes_frequency.tsv
```
