# LOINC -> OMOP Mapping -- Stats

Source: `DATA/MapLOINCToOmop/codesWithOMOP.tsv`

## Overview

Local codes are joined to OMOP concepts by requiring an exact match on all
6 LOINC axes (`has_component`, `has_property`, `has_method`,
`has_scale_type`, `has_system`, `has_time_aspect`) plus `is_panel`. A row
with none of the 6 axes known is never attempted -- there is nothing to
join by -- rather than being matched against every equally-unknown OMOP
concept.

| bucket | n | % |
|---|---|---|
| total | 1984 | 100.0% |
| with >=1 axis known | 1940 | 97.8% |
| no axis known | 44 | 2.2% |

Of the rows a match was attempted for:

| bucket | n | % |
|---|---|---|
| attempted | 1940 | 100.0% |
| matched (>=1 OMOP concept) | 177 | 9.1% |
| unmatched (0 OMOP concepts) | 1763 | 90.9% |
| matched uniquely (1 concept) | 175 | 9.0% |
| matched ambiguously (>1 concept) | 2 | 0.1% |

## By domain (has_system)

Match rate broken down by specimen/system (`has_system`), most common
first. `(unknown)` groups rows with no `has_system` value at all.

| has_system | n rows | n matched | % matched |
|---|---|---|---|
| Serum | 471 | 12 | 2.5% |
| (unknown) | 345 | 3 | 0.9% |
| Blood | 276 | 37 | 13.4% |
| Plasma | 270 | 2 | 0.7% |
| Urine | 218 | 91 | 41.7% |
| ^Patient | 82 | 0 | 0.0% |
| Bone marrow | 37 | 0 | 0.0% |
| Lymphocytes | 37 | 0 | 0.0% |
| Stool | 34 | 2 | 5.9% |
| Cerebral spinal fluid | 31 | 3 | 9.7% |
| Serum or Plasma | 16 | 3 | 18.8% |
| Blood capillary | 15 | 3 | 20.0% |
| Red Blood Cells | 15 | 1 | 6.7% |
| Throat | 15 | 1 | 6.7% |
| Blood venous | 13 | 6 | 46.2% |
| Pleural fluid | 9 | 4 | 44.4% |
| Urine sediment | 9 | 0 | 0.0% |
| White Blood Cells | 8 | 0 | 0.0% |
| Blood arterial | 7 | 3 | 42.9% |
| Platelet poor plasma | 5 | 0 | 0.0% |
| Tissue | 5 | 0 | 0.0% |
| Vaginal fluid | 5 | 0 | 0.0% |
| Bronchoalveolar lavage fluid | 4 | 0 | 0.0% |
| Respiratory specimen | 4 | 0 | 0.0% |
| Secretion | 4 | 0 | 0.0% |
| Amniotic fluid | 3 | 0 | 0.0% |
| Nose | 3 | 0 | 0.0% |
| Perineum | 3 | 0 | 0.0% |
| Pharyngeal secretion | 3 | 0 | 0.0% |
| Pus | 3 | 2 | 66.7% |
| Skin | 3 | 0 | 0.0% |
| Ascitic fluid | 2 | 0 | 0.0% |
| Bronchoalveolar lavage | 2 | 0 | 0.0% |
| Cervical specimen | 2 | 0 | 0.0% |
| Dialysate | 2 | 0 | 0.0% |
| Interstitial fluid | 2 | 1 | 50.0% |
| Pancreatic fluid | 2 | 0 | 0.0% |
| Plasma capillary | 2 | 0 | 0.0% |
| Semen | 2 | 0 | 0.0% |
| Sputum | 2 | 1 | 50.0% |
| Umbilical cord blood serum | 2 | 0 | 0.0% |
| Aspirate | 1 | 1 | 100.0% |
| Bile | 1 | 0 | 0.0% |
| Bone | 1 | 0 | 0.0% |
| Catheter tip | 1 | 1 | 100.0% |
| Dialysis fluid.peritoneal | 1 | 0 | 0.0% |
| Gingival crevicular fluid | 1 | 0 | 0.0% |
| Nasal secretion | 1 | 0 | 0.0% |
| Nasopharynx | 1 | 0 | 0.0% |
| Peritoneal fluid | 1 | 0 | 0.0% |
| Sperm | 1 | 0 | 0.0% |
| Synovial fluid | 1 | 0 | 0.0% |

## Cross-check against the reference mapping

`DATA/ReferenceMappings/lab_data_summary.csv` holds a previously curated Finnish-code -> OMOP mapping. Restricted to its `APPROVED` rows and matched to this table by `TEST_NAME`+`UNIT`:

- n rows overlapping an APPROVED reference mapping: 764
- of those, our join's OMOP concept(s) include the reference's approved concept: 62 / 764 (8.1%)

**Example disagreements:**

| TEST_NAME | UNIT | our omop_concept_id | our omop_concept_name | reference OMOP_CONCEPT_ID | reference OMOP_CONCEPT_NAME |
|---|---|---|---|---|---|
| kudostransglutaminaasi,iga-vasta-aineet |  |  |  | 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| kudostransglutaminaasi,igavasta-aineet | u/ml |  |  | 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| kudostransglutaminaasi,igavasta-aineet |  |  |  | 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| kudostransglutaminaasi,igg-vasta-aineet |  |  |  | 3046870 | Tissue transglutaminase IgG Ab [Units/volume] in Serum |
| s-kudostransglutaminaasi,iga-vasta-aineet | u/ml |  |  | 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
