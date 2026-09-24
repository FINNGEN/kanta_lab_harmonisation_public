# MapLOINCToOmop

## Inputs

- `DATA/FindLOINCDimensions/codesWithLoincDimensions.tsv` — one row per local
  `TEST_NAME`/`UNIT`, with the 6 LOINC axes (`has_component`, `has_property`,
  `has_method`, `has_scale_type`, `has_system`, `has_time_aspect`) and
  `is_panel` inferred by an LLM.
- `DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv` — every
  standard OMOP `Measurement`-domain concept, with the same 7 columns pulled
  from the vocabulary itself.
- `DATA/ReferenceMappings/lab_data_summary.csv` (optional) — a previously
  curated Finnish-code -> OMOP mapping, `testId` formatted as `"TEST_NAME
  [UNIT]"`, with a `status` column (`APPROVED`, `NOT-FOUND`, `IGNORED`,
  `UNCHECKED`). Used only as a cross-check in the stats report (see Action);
  the report degrades gracefully if this file is absent.

## Outputs

- `DATA/MapLOINCToOmop/codesWithOMOP.tsv` — `codesWithLoincDimensions.tsv`,
  unchanged, with four columns appended:
  - `omop_concept_id`, `omop_concept_name`, `omop_vocabulary_id` — every OMOP
    concept whose `has_component`/`has_property`/`has_method`/
    `has_scale_type`/`has_system`/`has_time_aspect`/`is_panel` exactly match
    the row's, joined with `"; "` when more than one concept shares that
    tuple. Empty when zero concepts match, or when the row has none of the 6
    axes known (see Action).
  - `n_omop_matches` — how many OMOP concepts matched (`0` when none, and
    also `0` for a row with no axis known, since no match was attempted).
- `DATA/MapLOINCToOmop/loincToOmopMappingStats.md` — stats on the mapping's
  quality (see Action).
- `DATA/MapLOINCToOmop/log.txt` — run log (written by `run.sh`'s `tee`; both R
  scripts log through `ParallelLogger::logInfo()` with no logger registered,
  per `development/STYLE.md`).

## Action

Two scripts, run in order:

1. `scripts/mapLoincToOmop.R` joins on all 7 columns at once (the 6 axes plus
   `is_panel`) — an exact match on every one of them, not a per-axis score.
   OMOP concepts with **none** of the 6 axes known (mostly non-LOINC concepts
   in the Measurement domain, e.g. SNOMED clinical findings — about 18,200 of
   ~102,800) are excluded as join targets first: without that, a local row
   with no axis information at all would "match" every one of those ~18,200
   concepts, which isn't a real match, just two unknowns lining up. For the
   same reason a local row with none of the 6 axes known is never attempted.
2. `scripts/summariseLoincToOmopMapping.R` reads `codesWithOMOP.tsv` and
   writes `loincToOmopMappingStats.md`:
   - **Overview** — how many rows had any axis to join on at all, and of
     those, how many matched >=1 / exactly 0 / exactly 1 / more than 1 OMOP
     concept.
   - **By domain (`has_system`)** — match rate for each specimen/system
     value, most common first.
   - **Cross-check against the reference mapping** — if
     `DATA/ReferenceMappings/lab_data_summary.csv` is present, its `APPROVED`
     rows are matched to this table by `TEST_NAME`+`UNIT`, and for the
     overlap, what fraction of the time this join's OMOP concept(s) include
     the reference's approved concept — a second, independent read on
     "goodness" beyond internal match/ambiguity rates, since the reference
     mapping was curated separately. A few example disagreements are listed.
     This section is skipped (with a note, not an error) if the file isn't
     found.

## Env vars

None required.

## How to run

```
./STEPS/MapLOINCToOmop/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME>
```
