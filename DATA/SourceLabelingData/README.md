


source : https://yhteistyotilat.fi/wiki08/spaces/JULKUNI/pages/141431291/Laboratoriotutkimusnimikkeist%C3%B6

## How lab codes are encoded in Finland

Per `Laboratoriotutkimusnimikkeistö-2021-ohjeistus.pdf` (the national lab test
nomenclature guide maintained by Kuntaliitto's Kodistopalvelu):

- Each test has a 4-digit running `CodeId` (national codes start at 1001).
- Its `Abbreviation` is up to 10 characters, built as **`<prefix><ShortName>[-<suffix>]`**:
  - a 1-2 letter **prefix** naming the specimen/system the sample is from
    (e.g. `S` = serum, `B` = blood, `U` = urine, `Pt` = patient), see
    `code_prefixes.tsv`;
  - a mnemonic Finnish (occasionally international) abbreviation of the test's
    long name;
  - an optional **suffix**, attached directly or after a hyphen, qualifying
    the result type or method (e.g. `-O` = qualitative/semi-quantitative,
    `-Ab` = antibodies), see `code_suffixes.tsv`.
- Example: `S -Bil-O` = S (serum) - Bil (bilirubiini/bilirubin) - O
  (qualitative).

`code_prefixes.tsv` and `code_suffixes.tsv` list every prefix/suffix from the
guide's abbreviation tables, with columns `id` (the code, lowercased),
`code` (the code as printed in the guide, case-sensitive), `name` (English —
taken from the guide's own English gloss where given, otherwise translated
from the Finnish/Swedish), `name_fi` (Finnish). Note: prefixes `fB`
(paastoveri/fasting blood) and `Fb` (vierasesine tai implantti/foreign body)
both lowercase to the same `id` (`fb`) — a genuine collision in the source,
not a transcription error.

## `loinc_axes_frequency.tsv` — how often each LOINC axis value is used in Finland

A frequency prior over LOINC axis values, used to break ties when a fuzzy
search offers several plausible terms for the same axis: the term Finland
actually uses is usually the right one.

Columns:

- `axe_name` — which axis: `component`, `property`, `method`, `system`,
  `scale_type`, `time_aspect`.
- `name` — the axis value, exactly as the OMOP vocabulary spells it.
- `concept_id` — that value's own OMOP concept id. Empty for 9 of 1223 values
  whose names come from SNOMED rather than LOINC (`Measurement - action`,
  `Microorganism; Organism`, ...) and so have no concept in the LOINC classes
  searched.
- `n_codes` — how many curated Finnish code→concept mappings use a concept
  carrying this axis value.
- `n_events` — how many lab records those codes cover (`n_records` summed).

Built by `STEPS/FixLOINCDimensions/scripts/buildLoincAxesFrequency.R`, which
joins `DATA/ReferenceMappings/lab_data_summary.csv` to
`DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv` on
`concept_id` and resolves each value's own id through Hecate (exact name match
only). Only `status == "APPROVED"` reference rows are counted — the
human-verified mappings — since `UNCHECKED` ones would add volume at the cost
of feeding unverified concept assignments into what is meant to be a
trustworthy prior. Re-run it only when the reference mappings or the OMOP
vocabulary snapshot change:

```
Rscript STEPS/FixLOINCDimensions/scripts/buildLoincAxesFrequency.R \
    DATA/ReferenceMappings/lab_data_summary.csv \
    DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv \
    DATA/SourceLabelingData/loinc_axes_frequency.tsv
```

