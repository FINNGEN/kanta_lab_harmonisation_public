# LOINC -> OMOP Mapping -- Stats

Source: `DATA/MapLOINCToOmop/codesWithOMOP.tsv`

## Overview

Each local code carries the OMOP concept `FixLOINCDimensions` chose for it
from a shortlist that a semantic search over the LOINC vocabulary returned for
the name `FindLOINCDimensions` guessed. This step only resolves that id
against the vocabulary — there is no tuple join to succeed or fail, so
"unmapped" here means the model declined every candidate, not that a join
missed.

| bucket | n | pct |
|---|---|---|
| total | 1984 | 100.0% |
| named by FindLOINCDimensions | 1790 | 90.2% |
| left unnamed |  194 | 9.8% |

Of the rows a mapping was attempted for:

| bucket | n | pct |
|---|---|---|
| attempted (a name was guessed) | 1790 | 100.0% |
| mapped to an OMOP concept | 1586 | 88.6% |
| unmapped (no candidate was right) |  204 | 11.4% |
| distinct concepts used |  623 |  |

## By domain (the chosen concept's `has_system`)

Which specimens the mapped codes ended up in, most common first. Unmapped
rows are grouped together: this approach never infers a system of its own, so
an unmapped row has no specimen to be counted under.

| omop_has_system | n_rows | pct_of_rows |
|---|---|---|
| Serum or Plasma | 563 | 28.4% |
| (unmapped) | 389 | 19.6% |
| Blood | 202 | 10.2% |
| Urine | 179 | 9.0% |
| Serum | 112 | 5.6% |
| XXX |  89 | 4.5% |
| Stool |  37 | 1.9% |
| Blood or Tissue |  36 | 1.8% |
| Red Blood Cells |  35 | 1.8% |
| Blood capillary |  28 | 1.4% |
| Heart |  27 | 1.4% |
| Specimen |  22 | 1.1% |
| Platelet poor plasma |  20 | 1.0% |
| Cerebral spinal fluid |  19 | 1.0% |
| Respiratory system specimen |  18 | 0.9% |
| Upper respiratory specimen |  18 | 0.9% |
| Bone marrow |  15 | 0.8% |
| Urine sediment |  15 | 0.8% |
| Blood venous |  12 | 0.6% |
| Throat |  12 | 0.6% |
| Blood arterial |  11 | 0.6% |
| ^Patient |  11 | 0.6% |
| Semen |   8 | 0.4% |
| Plasma |   7 | 0.4% |
| Pleural fluid |   7 | 0.4% |
| Serum, Plasma or Blood |   7 | 0.4% |
| Respiratory system |   5 | 0.3% |
| Tissue and Smears |   5 | 0.3% |
| Body fluid |   4 | 0.2% |
| Interstitial fluid |   4 | 0.2% |
| Nose |   4 | 0.2% |
| Reticulocytes |   4 | 0.2% |
| Serum and Blood |   4 | 0.2% |
| Vaginal |   4 | 0.2% |
| Bronchoalveolar lavage |   3 | 0.2% |
| Cervix |   3 | 0.2% |
| Nasopharynx |   3 | 0.2% |
| Pharynx |   3 | 0.2% |
| Blood^BPU |   2 | 0.1% |
| Calculus (stone) |   2 | 0.1% |
| Cardiac echo study |   2 | 0.1% |
| Dialysis fluid |   2 | 0.1% |
| Hematopoietic progenitor cells^BPU |   2 | 0.1% |
| Isolate |   2 | 0.1% |
| Peritoneal fluid |   2 | 0.1% |
| Plasma arterial |   2 | 0.1% |
| Pus |   2 | 0.1% |
| Respiratory system airway |   2 | 0.1% |
| Skeletal system |   2 | 0.1% |
| Skin |   2 | 0.1% |
| Blood central venous |   1 | 0.1% |
| Blood cord |   1 | 0.1% |
| Blood^Donor |   1 | 0.1% |
| Bone |   1 | 0.1% |
| Catheter tip |   1 | 0.1% |
| Dialysis fluid peritoneal |   1 | 0.1% |
| Eye |   1 | 0.1% |
| Lower respiratory specimen |   1 | 0.1% |
| Nervous system |   1 | 0.1% |
| Plasma cell-free DNA |   1 | 0.1% |
| Sputum |   1 | 0.1% |
| Synovial fluid |   1 | 0.1% |
| Vagina |   1 | 0.1% |
| Wound |   1 | 0.1% |
| ^Specimen |   1 | 0.1% |

## Cross-check against the reference mapping

`DATA/ReferenceMappings/lab_data_summary.csv` holds a separately curated Finnish-code -> OMOP mapping. Restricted to its `APPROVED` rows and matched to this table by `TEST_NAME`+`UNIT`, it is the only independent read on whether the concepts chosen here are the *right* ones:

| bucket | n | pct |
|---|---|---|
| rows overlapping an APPROVED reference mapping | 764 |  |
| of those, this pipeline chose a concept | 688 | 90.1% |
| of those, it chose the reference's concept | 469 | 68.2% |

Agreement over the whole overlap (the comparable headline number): **469 / 764 = 61.4%**.

**Example disagreements:**

| TEST_NAME | UNIT | loinc_name_guess | our_omop_concept_name | reference_OMOP_CONCEPT_NAME |
|---|---|---|---|---|
| kudostransglutaminaasi,iga-vasta-aineet |  | Transglutaminase.tissue IgA Ab [Presence] in Serum or Plasma | Tissue transglutaminase IgA Ab [Presence] in Serum | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| kudostransglutaminaasi,igavasta-aineet |  | Transglutaminase.tissue IgA Ab [Presence] in Serum or Plasma | Tissue transglutaminase IgA Ab [Presence] in Serum | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| kudostransglutaminaasi,igg-vasta-aineet |  | Transglutaminase.tissue IgG Ab [Presence] in Serum or Plasma | Tissue transglutaminase IgG Ab [Presence] in Serum | Tissue transglutaminase IgG Ab [Units/volume] in Serum |
| s-kudostransglutaminaasi,iga-vasta-aineet |  | Transglutaminase.tissue IgA Ab [Presence] in Serum or Plasma | Tissue transglutaminase IgA Ab [Presence] in Serum | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| s-kudostransglutaminaasi,igavasta-aineet |  | Transglutaminase.tissue IgA Ab [Presence] in Serum or Plasma | Tissue transglutaminase IgA Ab [Presence] in Serum | Tissue transglutaminase IgA Ab [Units/volume] in Serum |
| s-kudostransglutaminaasi,iggva(keliakia) |  | Transglutaminase.tissue IgG Ab [Presence] in Serum or Plasma | Tissue transglutaminase IgG Ab [Presence] in Serum | Tissue transglutaminase IgG Ab [Units/volume] in Serum |
| s-kudostransglutaminaasi,iggvasta-aineet |  | Transglutaminase.tissue IgG Ab [Presence] in Serum or Plasma | Tissue transglutaminase IgG Ab [Presence] in Serum | Tissue transglutaminase IgG Ab [Units/volume] in Serum |
| b-c-resktiivinenproteiini | mg/l | C reactive protein [Mass/volume] in Serum or Plasma | C reactive protein [Mass/volume] in Capillary blood | C reactive protein [Mass/volume] in Serum or Plasma |
| c-reaktiivinenproteiini,pika | mg/l | C reactive protein [Mass/volume] in Serum or Plasma | C reactive protein [Mass/volume] in Serum or Plasma | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method |
| c-reaktiivinenproteiini,pikatesti,veri | mg/l | C reactive protein [Mass/volume] in Serum or Plasma | C reactive protein [Mass/volume] in Capillary blood | C reactive protein [Mass/volume] in Serum or Plasma |
