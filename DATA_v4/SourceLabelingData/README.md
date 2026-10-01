


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

## `loinc_names_frequency.tsv` — which LOINC concepts Finland actually uses

A frequency prior over whole LOINC concepts. It answers "when several real
LOINC concepts could fit this Finnish code, which one does Finland already
use?", and it doubles as a source of correctly-spelled worked examples.

Columns:

- `concept_id` — the OMOP concept id.
- `concept_name` — its LOINC Long Common Name, as the OMOP vocabulary spells
  it today (not as the reference file recorded it, which can be stale).
- `vocabulary_id` — always `LOINC` in practice; kept so a non-LOINC concept
  sneaking into the reference mappings is visible rather than silent.
- `n_codes` — how many curated Finnish code→concept mappings use this concept.
- `n_events` — how many lab records those codes cover (`n_records` summed).

1,488 concepts covering 249M records. The 100 most used cover 89.5% of them —
which is why `4_FindLOINC` embeds exactly that head in its prompt.

Both `4_FindLOINC` (as examples of how LOINC spells the tests this
data contains) and `5_FixLOINC` (as a tie-breaker between candidates)
read this file.

Built by `STEPS/5_FixLOINC/scripts/buildLoincNamesFrequency.R`, which
joins `DATA/ReferenceMappings/lab_data_summary.csv` to
`DATA/0_GetMeasurementOmopData/measurement_concept_attributes.tsv` on
`concept_id`. Only `status == "APPROVED"` reference rows are counted — the
human-verified mappings — since `UNCHECKED` ones would add volume at the cost
of feeding unverified concept assignments into what is meant to be a
trustworthy prior. Re-run it only when the reference mappings or the OMOP
vocabulary snapshot change:

```
Rscript STEPS/5_FixLOINC/scripts/buildLoincNamesFrequency.R \
    DATA/ReferenceMappings/lab_data_summary.csv \
    DATA/0_GetMeasurementOmopData/measurement_concept_attributes.tsv \
    DATA/SourceLabelingData/loinc_names_frequency.tsv
```

## `loinc_top2000.tsv` — the LOINC recommended mapping targets

Regenstrief publishes the **LOINC Top 2000+ Lab Observations**: the ~2000
LOINC codes that cover about 99.8% of the test volume of three large
laboratory organisations, offered as the target set anyone mapping local lab
codes to LOINC should aim at. Being on this list is the strongest available
signal that a concept is the one a laboratory is *supposed* to map to, so
`5_FixLOINC` flags its candidates with it and tells the model to
prefer a flagged one when two candidates fit the evidence equally well.

The source file, `LOINC_1.6_Top2000CommonLabResultsSI.csv`, is the **SI**
edition, downloaded from
<https://github.com/OHDSI/StudyProtocolSandbox/tree/master/themis/extras>.
The SI edition is the relevant one here because Finland reports in molar/SI
units: SI rank 1 is `Creatinine [Moles/volume] in Serum or Plasma`, the
Finnish test, where the US edition's rank 1 is the mass-based
`Creatinine [Mass/volume]`. Both editions are also downloadable from
<https://loinc.org/usage/>.

Columns:

- `rank` — position on the list, 1 = highest volume.
- `loinc_code` — the LOINC code (`LOINC #` in the source).
- `concept_id` — the OMOP concept id it resolves to. Empty for 58 of 2,194
  codes that have no concept in the `Measurement` domain extract (pathology
  report fields, a few retired codes); they are kept rather than dropped, so
  the list's OMOP coverage is visible rather than assumed.
- `omop_concept_name` — the concept's name in OMOP today.
- `loinc_long_common_name` — the name as printed on the LOINC 1.6 list. It
  differs from `omop_concept_name` for 685 of the resolved codes, because
  LOINC has revised names since 1.6; the OMOP spelling is the one the rest of
  this pipeline must match.
- `loinc_class` — the LOINC class (`Chem`, `HEM/BC`, `MICRO`, ...).

Rebuilt from the CSV by
`STEPS/5_FixLOINC/scripts/buildLoincTop2000.R`:

```
Rscript STEPS/5_FixLOINC/scripts/buildLoincTop2000.R \
    DATA/SourceLabelingData/LOINC_1.6_Top2000CommonLabResultsSI.csv \
    DATA/0_GetMeasurementOmopData/measurement_concept_attributes.tsv \
    DATA/SourceLabelingData/loinc_top2000.tsv
```

