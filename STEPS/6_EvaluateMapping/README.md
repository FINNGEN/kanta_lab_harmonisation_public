# 6_EvaluateMapping

Looks up the OMOP vocabulary's own record of each concept `5_FixLOINC`
chose, then scores the mapping's quality — including agreement with the
separately curated reference mapping. The final, reportable result of the
pipeline.

## Inputs

- `DATA/5_FixLOINC/codesWithOmopConcepts.tsv` — one row per local
  `TEST_NAME`/`UNIT`, with the `omop_concept_id` chosen for it (empty when no
  candidate was right), its guessed name `loinc_name_guess`, the `reasoning`
  and `certainty` behind the choice, and the computed `evidence_level` /
  `unit_share` the report breaks down by.
- `DATA/0_GetMeasurementOmopData/measurement_concept_attributes.tsv` — every
  standard OMOP `Measurement`-domain concept, with its name, code, vocabulary
  and the six LOINC axes pulled from the vocabulary itself.
- `DATA/ReferenceMappings/lab_data_summary.csv` (optional) — a separately
  curated Finnish-code -> OMOP mapping, `testId` formatted as `"TEST_NAME
  [UNIT]"`, with a `status` column (`APPROVED`, `NOT-FOUND`, `IGNORED`,
  `UNCHECKED`). Used as the cross-check in the stats report (see Action); the
  report degrades gracefully if this file is absent.

## Outputs

- `DATA/6_EvaluateMapping/codesWithOMOP.tsv` — `codesWithOmopConcepts.tsv` with
  the vocabulary's own record of the chosen concept appended:
  - `omop_concept_name`, `omop_concept_code`, `omop_vocabulary_id` — taken
    from the vocabulary, replacing the name the previous step copied from its
    candidate list.
  - `omop_is_panel`, `omop_has_component`, `omop_has_property`,
    `omop_has_method`, `omop_has_scale_type`, `omop_has_system`,
    `omop_has_time_aspect` — the concept's own axes. They describe the concept
    that was chosen, not the local code, and are what the stats report breaks
    the result down by.
  - `mapped` — `TRUE` when the row carries a concept id that exists in the
    vocabulary.
- `DATA/6_EvaluateMapping/loincToOmopMappingStats.md` — stats on the mapping's
  quality (see Action).
- `DATA/6_EvaluateMapping/log.txt` — run log (written by `run.sh`'s `tee`; both R
  scripts log through `ParallelLogger::logInfo()` with no logger registered,
  per `development/STYLE.md`).

## Action

There is no matching left to do in this step. `5_FixLOINC` already
returns an `omop_concept_id` per local code, chosen from concepts a semantic
search actually found, so this step looks each id up and reports on the result.

That is the change from the earlier version, which did the mapping here by
joining the six LLM-inferred LOINC axes plus `is_panel` against the same seven
columns on every OMOP concept. Such a join fires only when all seven land
exactly right, which is combinatorially fragile: on a 30-group sample it
matched 287 of 1,940 rows (14.8%), and of the rows that overlapped the curated
Finnish mapping only 11.3% agreed with it. Choosing one concept from a
retrieved shortlist replaces seven independent chances to be wrong with one.

Two scripts, run in order:

1. `scripts/mapLoincToOmop.R` joins each `omop_concept_id` to
   `measurement_concept_attributes.tsv` and carries the vocabulary's name,
   code, vocabulary id and axes alongside it. An id that is not in the
   vocabulary is reported as unmapped, with a warning — it should not happen,
   since `5_FixLOINC` validates its ids against the candidates it
   offered, but a silent pass-through would hide it if it did.
2. `scripts/summariseLoincToOmopMapping.R` reads `codesWithOMOP.tsv` and
   writes `loincToOmopMappingStats.md`:
   - **Overview** — one funnel table from every raw local code down to one
     that agrees with the reference: `total` -> `has a guessed loinc` ->
     `has a fixed loinc` -> `exists in reference` -> `agrees with reference`,
     each row as both `n_codes`/`p_codes` (distinct `TEST_NAME`/`UNIT` pairs)
     and `n_events`/`p_events` (their summed record counts, so a high-volume
     code counts for more than a one-off). "Reference" always means the
     reference's `APPROVED` rows only — a code with only an
     `UNCHECKED`/`NOT-FOUND`/`IGNORED` row there counts as absent, not as a
     match or a miss. The last two rows print `-` when
     `DATA/ReferenceMappings/lab_data_summary.csv` is absent; the rest of the
     report degrades the same way.
   - **Compare with reference** — the section that matters, and (per the
     Overview note above) scoped from here on to only the codes that carry an
     `APPROVED` reference mapping for their `TEST_NAME`+`UNIT` — a code with
     no such row has nothing to agree or disagree with, so it is dropped from
     every table and example in this section. Read every figure here as
     **agreement, not correctness**: the reference is the best mapping
     available, not ground truth. It sends the rapid-test code
     `c-reaktiivinenproteiini,pika` to a high-sensitivity CRP concept although
     that row's values floor at 5 mg/l, and it is internally inconsistent on
     some panel families.

     **By evidence level** and **By record volume** each give two tables —
     one over codes, one over their summed records — with columns
     `n_codes`/`n_events`, `n_ai_mapped` (this pipeline produced any concept),
     `n_agree` (that concept matches the reference's), and a `p_` percentage
     for each with its own denominator: `p_codes`/`p_events` is this row's
     share of the section's grand total (so the rows sum to `total`);
     `p_ai_mapped` is of this row's own codes/records, how many got AI-mapped
     at all; `p_agree` is of the ones this row actually mapped, how many
     agreed — so a row that answers rarely isn't penalized in `p_agree` for
     the rows it never attempted. A `total` row closes each table.

     *By evidence level* exists because the two mappings don't have the same
     target: the reference gives more than one concept across a code's units
     for only ~6% of multi-unit codes, so in practice it maps `TEST_NAME` ->
     concept, while this pipeline maps `(TEST_NAME, UNIT)` and leaves a
     `name`-only row unanswered rather than assuming a quantity — so those
     rows get AI-mapped less and agree less by construction, and belong in
     their own row rather than blended into the whole.

     *By record volume* exists because the reference was curated for the
     codes that carry the data (it covers 97% of rows with 50,000+ records and
     under 30% of those below 500), so one blended agreement figure mixes the
     codes it was written for with the tail it barely touches.

     Two sets of 5 examples close the section, in this order: codes
     **not automapped** (deduped by code) and **disagreements** (deduped by
     the distinct (our concept, reference concept) pair, so one recurring
     disagreement cannot fill the table). Both carry the `reasoning`
     `5_FixLOINC` gave, so the mistake — or the refusal — can be read
     rather than guessed at. The whole section is skipped (with a note, not an
     error) if the reference file isn't found.

## Env vars

None required.

## How to run

```
./STEPS/6_EvaluateMapping/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME>
```
