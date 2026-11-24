# Hecate: semantic search of OMOP concepts

Hecate (https://hecate.pantheon-hds.com) is a semantic search engine for the OHDSI vocabulary. Use it in step
3 of the skill when `targetTable.tsv` alone does not give a good candidate concept: it ranks concepts by
similarity of their names, and gives how much each one is used in the OHDSI network.

Read this only when looking for a concept. Searching `targetTable.tsv` (step 3 of `SKILL.md`) is still the
first step: it holds what can be mapped, with the axes, the Groups and the target units.

## The script

`scripts/hecate.py`, run from the root of the repo:

| Situation | Command | What it does |
|---|---|---|
| A concept is mapped, but a closer one may exist (another system, method or property) | `hecate.py similar <concept_id>` | searches with the name of the concept (the Similar tab of the web page) |
| No concept yet, or the current one is wrong | `hecate.py search "<LOINC name>"` | searches with a name written as LOINC writes it |
| Check a candidate | `hecate.py concept <concept_id>` | details, LOINC axes (component, property, system, scale, method), and `Concept replaced by` / `Maps to` |

Options: `--limit N` (default 15); `--loinc` to search only LOINC; `--all` to search every vocabulary,
domain and standard status. By default it searches the standard `Measurement` concepts of every vocabulary,
the same concepts `targetTable.tsv` holds (LOINC, SNOMED, OMOP Extension, ...).

Each result is marked with whether it is in `targetTable.tsv` and how many rows of `mapping.tsv` use it.
A concept that is not in the target cannot be mapped.

## Writing the query

The search compares names, so write the query the way LOINC names a test:
`<Component> [<Property>] in <System>[ by <Method>]`, in English. For example:

- `Cancer Ag 19-9 [Units/volume] in Serum or Plasma`
- `Iron saturation [Mass Fraction] in Serum or Plasma`
- `Oxygen saturation in Venous blood`
- `Albumin [Mass/time] in 24 hour Urine`

- The **component** is the analyte in English (translate the Finnish `TEST_NAME`, e.g. `trfesat` →
  transferrin saturation, `hbo2sat` → oxygen saturation).
- The **property** follows from the unit, as in step 3 of `SKILL.md`: `[Mass/volume]` for `g/l`,
  `[Moles/volume]` for `mmol/l`, `[Units/volume]` for `u/ml`, `[#/volume]` for `e9/l`, `[Mass Fraction]` or
  none for `%`, `[Presence]` for a qualitative test.
- The **system** follows from the prefix of the `TEST_NAME` (step 2 of `SKILL.md`): `Serum or Plasma`,
  `Blood`, `Urine`, `Arterial blood`, `Venous blood`, `Capillary blood`, ...
- When the right name is not clear, try the component alone (e.g. `transferrin saturation`): the
  results show how LOINC names it.

## LOINC first, other vocabularies when they fit better

Prefer a LOINC concept: LOINC is the vocabulary of lab tests, its six axes (component, property, system,
scale, time, method) say exactly what was measured, the target unit and the LOINC Groups of `targetTable.tsv`
come from it, and most of the approved mappings use it. But do not search LOINC only: sometimes a concept of
another vocabulary fits the test better, e.g. a SNOMED or OMOP Extension concept for a calculated or
derived measurement, a score or an index that LOINC does not have, or that has no LOINC concept for the
specimen of the test. Take a non-LOINC concept only when no LOINC concept has the right axes, say why in
the proposal, and check that it has a target unit (or that one can be given in
`harmonisedUnitOverwrite.tsv`) and that it is not in a LOINC Group with the other pairs of the test.

Use `--loinc` to see the LOINC candidates alone when the first results are crowded by other vocabularies.

## Reading the results

- `score` is the similarity of the names (1 = the same name), not a measure of whether the concept is
  right: check the axes against the evidence (system from the prefix, property from the unit, scale from
  the values).
- `vocabulary`: see above; between candidates that fit equally well, LOINC wins.
- `OHDSI records` is how many records the concept has in the OHDSI network. Between candidates with the
  same axes, prefer the one that is widely used: it is the one other data sources map the same test to
  (e.g. transferrin saturation: 2502-3 with 9.2 M records, against 60517-0 with 74 k).
- Concepts of the `[Measurement]` kind (e.g. `Cancer Ag 19-9 [Measurement] in Serum or Plasma`) are recent
  generic LOINC codes, usually not in the target: prefer the one with the property.
- Give the candidates as in step 3 of `SKILL.md`, adding the score and the OHDSI records.

## The API

The script uses only three endpoints of the API (described at https://hecate.pantheon-hds.com/openapi/):

- `GET /api/search?q=<text>&domain_id=Measurement&standard_concept=S&limit=<n>` (and `vocabulary_id=LOINC`
  with `--loinc`) — the ranked concepts, with `score` and `record_count`.
- `GET /api/concepts/<id>` — the details of a concept.
- `GET /api/concepts/<id>/relationships` — its relationships, among them the LOINC axes (`Has component`,
  `Has property`, `Has system`, `Has scale type`, `Has method`).

The API also has `/api/search_standard` (searches the synonyms too and maps non-standard concepts to
standard ones), `/api/concepts/<id>/expand` (the hierarchy) and `/api/concepts/<id>/phoebe` (PHOEBE
related concepts). Only concept names and ids are sent to the API, never the Kanta data.
