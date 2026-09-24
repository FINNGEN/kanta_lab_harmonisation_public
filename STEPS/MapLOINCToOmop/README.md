# MapLOINCToOmop

## Inputs

- `DATA/FixLOINCDimensions/codesWithOmopConcepts.tsv` — one row per local
  `TEST_NAME`/`UNIT`, with the `omop_concept_id` chosen for it (empty when no
  candidate was right), its guessed name `loinc_name_guess`, and `is_panel`.
- `DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv` — every
  standard OMOP `Measurement`-domain concept, with its name, code, vocabulary
  and the six LOINC axes pulled from the vocabulary itself.
- `DATA/ReferenceMappings/lab_data_summary.csv` (optional) — a separately
  curated Finnish-code -> OMOP mapping, `testId` formatted as `"TEST_NAME
  [UNIT]"`, with a `status` column (`APPROVED`, `NOT-FOUND`, `IGNORED`,
  `UNCHECKED`). Used as the cross-check in the stats report (see Action); the
  report degrades gracefully if this file is absent.

## Outputs

- `DATA/MapLOINCToOmop/codesWithOMOP.tsv` — `codesWithOmopConcepts.tsv` with
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
- `DATA/MapLOINCToOmop/loincToOmopMappingStats.md` — stats on the mapping's
  quality (see Action).
- `DATA/MapLOINCToOmop/log.txt` — run log (written by `run.sh`'s `tee`; both R
  scripts log through `ParallelLogger::logInfo()` with no logger registered,
  per `development/STYLE.md`).

## Action

There is no matching left to do in this step. `FixLOINCDimensions` already
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
   since `FixLOINCDimensions` validates its ids against the candidates it
   offered, but a silent pass-through would hide it if it did.
2. `scripts/summariseLoincToOmopMapping.R` reads `codesWithOMOP.tsv` and
   writes `loincToOmopMappingStats.md`:
   - **Overview** — how many rows were named at all, and of those, how many
     carry a concept. "Unmapped" here means the model declined every
     candidate, not that a join missed.
   - **By domain** — which specimens the mapped codes ended up in, from the
     chosen concept's own `has_system`.
   - **Cross-check against the reference mapping** — the number that matters.
     The reference's `APPROVED` rows are matched to this table by
     `TEST_NAME`+`UNIT`, and for the overlap the report gives both how often
     this pipeline answered at all and how often its answer *is* the
     reference's concept. Coverage and correctness pull in opposite
     directions, so reporting only the first would let the step look good by
     mapping everything; both are given, with agreement over the whole overlap
     as the headline. A few example disagreements are listed. The section is
     skipped (with a note, not an error) if the file isn't found.

## Env vars

None required.

## How to run

```
./STEPS/MapLOINCToOmop/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME>
```
