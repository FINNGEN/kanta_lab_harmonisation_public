# Known Information Table -- Stats

Source: `DATA_v4/BuildKnownInformationTable/knownInformation.tsv`

## Overview

### Distinct TEST_NAME + UNIT

Each row of `knownInformation.tsv` is one `TEST_NAME`/`UNIT` pair.
`with recorded data` counts pairs that are not almost entirely missing
(`p_missing` < 95%); `with deciles computed` counts pairs that got a
decile summary.

| bucket | n | % |
|---|---|---|
| total | 26798 | 100.0% |
| with recorded data (p_missing < 95.0) | 0 | 0.0% |
| with deciles computed | 0 | 0.0% |

### Distinct TEST_NAME

Collapsing to one row per `TEST_NAME` (summing `n` across its units) shows
how much lab-code metadata is available, and whether that coverage holds
up for the tests that actually have data. The three tables below are the
same buckets applied to three overlapping tiers -- all `TEST_NAME`s, then
only those with more than 100 / more than 500 total events -- and each
table's `%` is relative to that tier's own total, stated in its heading.

- `is number` -- `TEST_NAME` is a bare digit code, never resolved to an
  abbreviation (likely a raw internal code).
- `with long name` / `with prefix` / `with suffix` -- matched as described
  in this step's `README.md`.

**All TEST_NAME** (n = 21445)

| bucket | n | % |
|---|---|---|
| total | 21445 | 100.0% |
| is number (TEST_NAME is a bare digit code) | 423 | 2.0% |
| with long name | 2327 | 10.9% |
| with prefix | 12811 | 59.7% |
| with suffix | 1020 | 4.8% |

**TEST_NAME with n_events > 100** (n = 9401)

| bucket | n | % |
|---|---|---|
| total | 9401 | 100.0% |
| is number (TEST_NAME is a bare digit code) | 190 | 2.0% |
| with long name | 1646 | 17.5% |
| with prefix | 6064 | 64.5% |
| with suffix | 492 | 5.2% |

**TEST_NAME with n_events > 500** (n = 4699)

| bucket | n | % |
|---|---|---|
| total | 4699 | 100.0% |
| is number (TEST_NAME is a bare digit code) | 86 | 1.8% |
| with long name | 1158 | 24.6% |
| with prefix | 3153 | 67.1% |
| with suffix | 284 | 6.0% |

## Prefixes

Among the distinct `TEST_NAME`s with a recognized prefix, how many use
each prefix meaning, sorted by usage descending.

n distinct prefixes: 75

| Prefix meaning | n distinct TEST_NAME |
|---|---|
| Serum | 3975 |
| Blood | 1698 |
| Urine | 1332 |
| Plasma | 1216 |
| Patient | 1023 |
| Cerebrospinal fluid | 414 |
| Feces | 376 |
| Tissue | 302 |
| Fasting plasma | 249 |
| Leukocyte | 187 |
| Fasting serum | 177 |
| Venous blood | 169 |
| Arterial blood | 160 |
| Erythrocyte | 159 |
| Bone marrow | 146 |
| Capillary blood | 116 |
| Pleural fluid | 100 |
| Pharyngeal secretion | 89 |
| Synovial fluid | 88 |
| 24-hour urine | 84 |
| Ascitic fluid | 67 |
| Vaginal discharge | 61 |
| Lymphocyte | 54 |
| Pus | 54 |
| Sperm / semen | 40 |
| Bronchoalveolar lavage | 30 |
| Expectorate (sputum) | 30 |
| Secretion | 29 |
| Skin | 28 |
| Peritoneal dialysis fluid | 27 |
| Aspiration fluid | 26 |
| Dialysis fluid | 23 |
| Fasting blood; Foreign body / implant | 21 |
| Central blood | 19 |
| Night (morning) urine | 19 |
| Amniotic fluid | 18 |
| Umbilical artery blood | 17 |
| Umbilical venous blood | 17 |
| Muscle | 15 |
| Nasal secretion | 15 |
| Collected urine | 13 |
| Lymph node | 11 |
| Point-of-care test | 11 |
| Fasting erythrocyte | 9 |
| Placenta | 9 |
| Thrombocyte | 9 |
| Chorionic villus | 7 |
| Hemoglobin | 7 |
| Saliva | 7 |
| Gastrointestinal canal | 5 |
| Kidney | 5 |
| Umbilical blood | 5 |
| Bone | 4 |
| Maternal milk | 4 |
| Bronchial fluid | 3 |
| Liver | 3 |
| Lung | 3 |
| Nail | 3 |
| Umbilical (blood) serum | 3 |
| Bile | 2 |
| Mucosa | 2 |
| Pancreatic juice | 2 |
| Periodontal pocket | 2 |
| Central nervous system | 1 |
| Cervical fluid | 1 |
| Gas | 1 |
| Gastric juice | 1 |
| Heart | 1 |
| Mammary fluid | 1 |
| Nerve | 1 |
| Pituitary gland | 1 |
| Stomach | 1 |
| Sweat | 1 |
| Urethral fluid | 1 |
| Uterus (womb) | 1 |

## Suffixes

Same as Prefixes, for the distinct `TEST_NAME`s with a recognized suffix.

n distinct suffixes: 59

| Suffix meaning | n distinct TEST_NAME |
|---|---|
| Qualitative test (also semi-quantitative) | 315 |
| DNA test | 166 |
| Antibodies | 71 |
| Free or unconjugated | 41 |
| Culture | 37 |
| Native preparation | 31 |
| Upright (standing) | 27 |
| Supine (lying down) | 24 |
| IgG antibodies | 20 |
| IgM antibodies | 20 |
| Ionized | 20 |
| Stimulation, stimulated | 17 |
| Antigen | 16 |
| Exercise / functional test | 16 |
| Clearance | 15 |
| Vitamin | 15 |
| Fractions | 13 |
| Long-term / prolonged | 13 |
| Index | 12 |
| Isoenzymes | 10 |
| Micro | 10 |
| Flow cytometry | 8 |
| Special technique | 8 |
| Typing | 8 |
| Immunofluorescence | 7 |
| Stability | 7 |
| Staining | 7 |
| Amplitude-integrated | 6 |
| Immunohistochemical | 6 |
| Electron microscopic | 5 |
| IgA antibodies | 5 |
| Antibiotic sensitivity | 3 |
| Basic screening | 3 |
| Confirmation, confirmatory test | 3 |
| Content | 3 |
| Oligoclonal | 3 |
| Releasing hormone | 3 |
| Conjugated | 2 |
| Follow-up test | 2 |
| Targeted screening | 2 |
| Targeted screening with specified follow-up | 2 |
| Absorbed | 1 |
| Anaerobic | 1 |
| Avidity test | 1 |
| Basic screening with specified follow-up | 1 |
| Binding capacity | 1 |
| Bound | 1 |
| Classification, subclasses | 1 |
| Enzyme histochemical | 1 |
| Histomorphometric | 1 |
| IgE antibodies | 1 |
| In situ hybridization | 1 |
| Ion channel | 1 |
| Isoelectric focusing | 1 |
| Macro | 1 |
| Monoclonal | 1 |
| Retention | 1 |
| Species identification | 1 |
| Vibration sense | 1 |
