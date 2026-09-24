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
| with >=1 axis known | 1901 | 95.8% |
| no axis known | 83 | 4.2% |

Of the rows a match was attempted for:

| bucket | n | % |
|---|---|---|
| attempted | 1901 | 100.0% |
| matched (>=1 OMOP concept) | 167 | 8.8% |
| unmatched (0 OMOP concepts) | 1734 | 91.2% |
| matched uniquely (1 concept) | 167 | 8.8% |
| matched ambiguously (>1 concept) | 0 | 0.0% |

## By domain (has_system)

Match rate broken down by specimen/system (`has_system`), most common
first. `(unknown)` groups rows with no `has_system` value at all.

| has_system | n rows | n matched | % matched |
|---|---|---|---|
| Serum | 484 | 13 | 2.7% |
| (unknown) | 349 | 0 | 0.0% |
| Blood | 266 | 32 | 12.0% |
| Plasma | 225 | 2 | 0.9% |
| Urine | 207 | 80 | 38.6% |
| ^Patient | 103 | 0 | 0.0% |
| Lymphocyte | 37 | 0 | 0.0% |
| Bone marrow | 35 | 0 | 0.0% |
| Cerebral spinal fluid | 31 | 1 | 3.2% |
| Stool | 31 | 3 | 9.7% |
| Platelet poor plasma | 28 | 0 | 0.0% |
| Serum or Plasma | 23 | 11 | 47.8% |
| Blood capillary | 17 | 7 | 41.2% |
| Red Blood Cells | 15 | 2 | 13.3% |
| Throat | 15 | 0 | 0.0% |
| White Blood Cells | 14 | 0 | 0.0% |
| Urine sediment | 13 | 3 | 23.1% |
| Blood venous | 11 | 4 | 36.4% |
| Pleural fluid | 9 | 4 | 44.4% |
| Plasma arterial | 8 | 1 | 12.5% |
| Tissue | 6 | 0 | 0.0% |
| Blood arterial | 5 | 3 | 60.0% |
| Secretion | 4 | 0 | 0.0% |
| Vaginal fluid | 4 | 0 | 0.0% |
| Amniotic fluid | 3 | 0 | 0.0% |
| Nose | 3 | 0 | 0.0% |
| Perineum | 3 | 0 | 0.0% |
| Pharyngeal secretion | 3 | 0 | 0.0% |
| Ascitic fluid | 2 | 0 | 0.0% |
| Bronchoalveolar lavage | 2 | 0 | 0.0% |
| Cervix | 2 | 0 | 0.0% |
| Dialysis fluid | 2 | 1 | 50.0% |
| Leukocyte | 2 | 0 | 0.0% |
| Pancreatic juice | 2 | 0 | 0.0% |
| Plasma venous | 2 | 0 | 0.0% |
| Pus | 2 | 0 | 0.0% |
| Serum from umbilical cord blood | 2 | 0 | 0.0% |
| Skin | 2 | 0 | 0.0% |
| Sputum | 2 | 0 | 0.0% |
| Ascites fluid | 1 | 0 | 0.0% |
| Aspirate | 1 | 0 | 0.0% |
| Bile | 1 | 0 | 0.0% |
| Bone | 1 | 0 | 0.0% |
| Bronchoalveolar lavage fluid | 1 | 0 | 0.0% |
| Catheter tip | 1 | 0 | 0.0% |
| Gingival crevicular fluid | 1 | 0 | 0.0% |
| Peritoneal fluid | 1 | 0 | 0.0% |
| Sperm | 1 | 0 | 0.0% |
| Synovial fluid | 1 | 0 | 0.0% |

## Cross-check against the reference mapping

`DATA/ReferenceMappings/lab_data_summary.csv` holds a previously curated Finnish-code -> OMOP mapping. Restricted to its `APPROVED` rows and matched to this table by `TEST_NAME`+`UNIT`:

- n rows overlapping an APPROVED reference mapping: 764
- of those, our join's OMOP concept(s) include the reference's approved concept: 57 / 764 (7.5%)

**Example disagreements:**

| TEST_NAME | UNIT | our omop_concept_id | our omop_concept_name | reference OMOP_CONCEPT_ID | reference OMOP_CONCEPT_NAME |
|---|---|---|---|---|---|
| kudostransglutaminaasi,iga-vasta-aineet |  |  |  | 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| kudostransglutaminaasi,igavasta-aineet | u/ml |  |  | 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| kudostransglutaminaasi,igavasta-aineet |  |  |  | 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| kudostransglutaminaasi,igg-vasta-aineet |  |  |  | 3046870 | Tissue transglutaminase IgG Ab [Units/volume] in Serum |
| s-kudostransglutaminaasi,iga-vasta-aineet | u/ml |  |  | 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
