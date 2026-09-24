# FixLOINCDimensions

Resolves the guessed LOINC names from `FindLOINCDimensions` to real OMOP
concept ids.

## Inputs

- `DATA/FindLOINCDimensions/codesWithLoincNames.tsv` — local Finnish lab codes
  with the LLM's guessed LOINC Long Common Name (`loinc_name_guess`) and the
  computed `unit_share` / `evidence_level`, in similarity groups (`group_id`).
- `DATA/SourceLabelingData/loinc_names_frequency.tsv` — which LOINC concepts
  the curated Finnish mappings already use. Built by
  `scripts/buildLoincNamesFrequency.R`. Read **only by the stats report**,
  never by the prompt: it is derived from the reference mappings this pipeline
  is measured against, so showing it to the model would make the evaluation
  circular. Measuring against it afterwards is what it is for.
- `DATA/SourceLabelingData/loinc_top2000.tsv` — the LOINC Top 2000+ (SI)
  recommended mapping targets (`rank`, `concept_id`, ...). Built by
  `scripts/buildLoincTop2000.R`. See `DATA/SourceLabelingData/README.md` for
  both.
- `DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv` — used to
  resolve each chosen `concept_id` to the vocabulary's own concept name.
- `scripts/systemPrompt.md` — the system prompt for the resolution pass.
- The **Hecate** API (`https://hecate.pantheon-hds.com`), a semantic search
  over the OMOP vocabularies, queried once per distinct guessed name.

## Outputs

- `DATA/FixLOINCDimensions/codesWithOmopConcepts.tsv` — the input table with
  two columns appended:
  - `omop_concept_id` — the concept the model chose for this code, or empty
    when it judged that no candidate was right.
  - `omop_concept_name` — that concept's name, taken from the OMOP vocabulary
    rather than from the model's copy of it.
  - `reasoning` — why each part of the chosen name is right, one clause per
    part separated by ` ; `, each naming the evidence in the row that carries
    it. This is what makes a mapping reviewable without re-deriving it: a
    reader can see whether the specimen came from the code or from nowhere.
  - `certainty` — `high`, `medium` or `low`, the model's own confidence in the
    whole mapping. A claim rather than a measurement, but a `low` row is one it
    is asking you to check, and the report cross-tabulates it against
    `evidence_level` so a `high` on a `name only` row is visible.

  There is no `is_panel` column: LOINC names panels as panels, so a bundle is
  expressed in the name itself rather than in a separate flag.
- `DATA/FixLOINCDimensions/reflections.md` — one `# Group <id>` section per
  group: what could and could not be mapped, and where the candidate list was
  missing the concept the model knew was right.
- `DATA/FixLOINCDimensions/fixedLoincNamesStats.md` — a stats report: how many
  guesses became concept ids, whether the search even returned candidates and
  how close they scored, whether the chosen concepts are on the LOINC
  recommended list or already used in Finland, the most-chosen concepts, the
  `certainty` distribution cross-tabulated against `evidence_level`, and a
  **Findings** section distilled from the reflections by a further LLM call.
- `DATA/FixLOINCDimensions/hecateCandidates.tsv` — every Hecate lookup made
  (`value`, `concept_name`, `concept_id`, `concept_code`, `score`), cached
  across runs so re-runs do no network traffic. Not score-filtered: the
  threshold is applied when the candidates are used, so it can be changed
  without re-querying.
- `DATA/FixLOINCDimensions/groupsCache/<group_id>.json` — the model's raw
  answer for one group, and `<group_id>_prompt.md` the exact prompt. A
  **cache**: a re-run only calls the LLM for groups that have none.
- `DATA/FixLOINCDimensions/log.txt` — run log, including how many ids were
  discarded for not being in the group's candidate list.

## Action

`FindLOINCDimensions` writes one string per local code: the LOINC Long Common
Name it thinks the code should have. That string is a hypothesis, not a
concept — it is spelled like a LOINC name but need not be one. This step turns
it into an identifier.

`scripts/fixLoincNames.R`:

1. Sends every distinct guessed name to Hecate, which returns the closest real
   **standard** LOINC concepts in the `Measurement` domain. The standard filter
   matters: without it the top hit is regularly a deprecated concept — the real
   name `Glucose [Mass or Moles/volume] in Serum or Plasma` scores its own
   deprecated concept 1.000 and pushes the two live glucose concepts below it —
   and mapping local data onto a deprecated concept is worse than not mapping
   it. No concept-class filter is applied, so panels stay reachable alongside
   ordinary lab tests. Lookups are deduplicated across the whole run and cached
   on disk.
2. Pools the hits for all the guesses in one similarity group and deduplicates
   them by `concept_id`, keeping the best score. Pooling is deliberate: sibling
   codes in a group are near-identical strings, so the right concept for one
   row is often what another row's guess retrieved.
3. Annotates each candidate with its **LOINC Top 2000+ (SI)** rank — the one
   prior the prompt breaks ties on, and only between candidates the row's own
   evidence supports equally. That list is Regenstrief's, independent of the
   Finnish reference mappings, so using it does not contaminate the evaluation.
4. Sends each group to the LLM with its rows and that candidate table, and asks
   for one `omop_concept_id` per row, a `reasoning` trail naming the evidence
   behind each part of the chosen name, and one overall `certainty`.

The prompt carries the same evidence hierarchy as `FindLOINCDimensions` — see
that step's README — plus two rules specific to choosing between real concepts,
both derived from measuring the first run against the curated Finnish mappings:

- **Precision must be earned by the name.** LOINC holds a plain and a qualified
  concept for most tests. The more precise candidate is the right answer when
  the name states the qualifier — `-Vi` says culture, `pikatesti` says a rapid
  test, `dU` says a 24-hour collection. The error to avoid is *inventing* a
  qualifier, not being specific: this step added a method the reference leaves
  blank 59 times (usually `Automated count` on a bare blood-count code), took
  `--trough` variants for plain drug levels, and narrowed `Serum or Plasma` to
  `Capillary blood` on codes that said no such thing. The prompt asks, of every
  qualifier: which characters of this code say so?
- **A guess that is itself a real concept is evidence, not an instruction.** In
  33 rows the earlier pass had already written the reference concept's exact
  name and the search returned it at score 1.000, yet this step moved off it.
  It now carries real weight — but a better-supported candidate, including a
  more precise one, still wins.

The score threshold is `0.5`, deliberately looser than the `0.75` the earlier
axis-based version used. There, the search matched a short axis label against
another short label of the same kind and anything below 0.75 was a different
concept. Here it matches a whole invented sentence against real LOINC names, so
the right concept routinely lands at 0.7–0.8; the eGFR concepts top out at 0.72
for a well-formed guess. The model is shown the score and told what it does and
does not mean, so a loose floor costs a few extra rows in the prompt rather
than a wrong answer.

Every returned id is **validated against the candidates that row's own group
was shown**, and discarded if it was not among them. An id from outside that
set was not chosen from the evidence — it came from the model's memory or from
nowhere — and this step exists precisely so that what comes out of it is a
concept the search actually found. The concept *name* likewise comes from the
OMOP vocabulary, never from the model's copy; the copy is used only to detect
that the model meant a different concept than the id it typed.

The join is guarded the same way as in `FindLOINCDimensions`: unknown or
duplicated `row_id`s are dropped with a warning rather than allowed to shift
the table. `certainty` is normalised to `high`/`medium`/`low` and anything else
becomes empty, and both it and `reasoning` are cleared whenever no concept
survived — they would otherwise describe a choice that is not in the table.

`scripts/summariseFixedLoincNames.R` then writes the stats report. Its numbers
are about the *route*, not about correctness: whether the search offered
anything, and what kind of concept was taken. Whether the chosen concept is the
**right** one is not knowable from this table — that is what
`MapLOINCToOmop`'s cross-check against the curated reference mapping is for.

## Env vars

- `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, `GOOGLE_APPLICATION_CREDENTIALS` —
  Vertex AI project, region and service-account key, from the `--env` file.
- `LLM_PROVIDER` (default `google_vertex`), `LLM_MODEL` (default
  `gemini-2.5-pro`), `LLM_PARALLEL_WORKERS` (default `detectCores() - 2`).
- `HECATE_SCORE_THRESHOLD` — minimum similarity to keep a candidate, default
  `0.5` (see Action for why it is this low).
- `HECATE_CANDIDATE_LIMIT` — candidates requested per guessed name, default
  `10`.
- `HECATE_PARALLEL_WORKERS` — parallel Hecate lookups, default `4` (kept
  modest: it is someone else's public API).

## How to run

```
./STEPS/FixLOINCDimensions/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME> \
    [--ngroups <N>] [--seed <N>] [--clean]
```

`--ngroups <N>` processes a random sample of `N` groups (`--seed`, default `1`,
makes the sample reproducible). Since the input already holds only the groups
`FindLOINCDimensions` processed, omitting `--ngroups` simply covers all of
them — which is the normal way to run this step.

`--clean` deletes the per-group LLM answer cache, which is required after
editing `systemPrompt.md` or the output schema since the cache is keyed on
`group_id` alone; the Hecate cache is kept, as it depends only on the guessed
names.

```
./STEPS/FixLOINCDimensions/run.sh DATA --env build --clean
```

### Rebuilding the reference tables

Only needed when the reference mappings, the LOINC Top 2000 list, or the OMOP
vocabulary snapshot change:

```
Rscript STEPS/FixLOINCDimensions/scripts/buildLoincNamesFrequency.R \
    DATA/ReferenceMappings/lab_data_summary.csv \
    DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv \
    DATA/SourceLabelingData/loinc_names_frequency.tsv

Rscript STEPS/FixLOINCDimensions/scripts/buildLoincTop2000.R \
    DATA/SourceLabelingData/LOINC_1.6_Top2000CommonLabResultsSI.csv \
    DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv \
    DATA/SourceLabelingData/loinc_top2000.tsv
```
