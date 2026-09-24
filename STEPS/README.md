# STEPS

Index of the steps, in the order they run.

1. [`BuildKnownInformationTable`](BuildKnownInformationTable/README.md) — join
   `labSummary.tsv` with the Kodistopalvelu lab code table and the
   prefix/suffix code tables into `knownInformation.tsv`, then summarise it
   into a stats report.
2. [`GetMeasurementOmopData`](GetMeasurementOmopData/README.md) — pull every
   standard OMOP `Measurement`-domain concept and its LOINC attributes
   (component, property, method, scale type, system, time aspect, panel
   flag) from the FinnGen CDM vocabulary, then summarise it into a stats
   report.
3. [`GroupKnownInformationTable`](GroupKnownInformationTable/README.md) —
   filter `knownInformation.tsv` and cluster the surviving `TEST_NAME`s by
   string similarity into size-capped groups, then summarise the groups
   (with a dendrogram) into a stats report.
4. [`FindLOINCDimensions`](FindLOINCDimensions/README.md) — send each
   similarity group to an LLM to guess the **LOINC Long Common Name** each
   local lab code would have, plus `is_panel`, into
   `codesWithLoincNames.tsv` and a per-group `reflections.md`.
5. [`FixLOINCDimensions`](FixLOINCDimensions/README.md) — resolve each guessed
   name to a real OMOP concept: Hecate semantic search over the LOINC
   vocabulary for candidates, annotated with the LOINC Top 2000 recommended
   list and Finnish usage, then an LLM picks one per code, into
   `codesWithOmopConcepts.tsv`.
6. [`MapLOINCToOmop`](MapLOINCToOmop/README.md) — look each chosen
   `omop_concept_id` up in OMOP's `measurement_concept_attributes.tsv`, into
   `codesWithOMOP.tsv`, then report on the mapping's goodness — including
   agreement with the separately curated reference mapping.
