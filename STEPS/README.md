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
