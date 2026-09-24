# Known Information Table -- Stats

Source: `DATA/BuildKnownInformationTable/knownInformation.tsv`

## Overview

### Distinct TEST_NAME + UNIT

Each row of `knownInformation.tsv` is one `TEST_NAME`/`UNIT` pair.
`with recorded data` counts pairs that are not almost entirely missing
(`p_missing` < 95%); `with deciles computed` counts pairs that got a
decile summary.

| bucket | n | % |
|---|---|---|
| total | 29341 | 100.0% |
| with recorded data (p_missing < 95.0) | 13150 | 44.8% |
| with deciles computed | 5568 | 19.0% |

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

**All TEST_NAME** (n = 23242)

| bucket | n | % |
|---|---|---|
| total | 23242 | 100.0% |
| is number (TEST_NAME is a bare digit code) | 473 | 2.0% |
| with long name | 2390 | 10.3% |
| with prefix | 13741 | 59.1% |
| with suffix | 1092 | 4.7% |

**TEST_NAME with n_events > 100** (n = 9412)

| bucket | n | % |
|---|---|---|
| total | 9412 | 100.0% |
| is number (TEST_NAME is a bare digit code) | 190 | 2.0% |
| with long name | 1649 | 17.5% |
| with prefix | 6073 | 64.5% |
| with suffix | 493 | 5.2% |

**TEST_NAME with n_events > 500** (n = 4701)

| bucket | n | % |
|---|---|---|
| total | 4701 | 100.0% |
| is number (TEST_NAME is a bare digit code) | 86 | 1.8% |
| with long name | 1159 | 24.7% |
| with prefix | 3154 | 67.1% |
| with suffix | 284 | 6.0% |

## Prefixes

Among the distinct `TEST_NAME`s with a recognized prefix, how many use
each prefix meaning, sorted by usage descending.

n distinct prefixes: 75

| Prefix meaning | n distinct TEST_NAME |
|---|---|
| Serum | 4260 |
| Blood | 1859 |
| Urine | 1448 |
| Plasma | 1282 |
| Patient | 1088 |
| Cerebrospinal fluid | 442 |
| Feces | 405 |
| Tissue | 318 |
| Fasting plasma | 254 |
| Leukocyte | 193 |
| Fasting serum | 191 |
| Venous blood | 177 |
| Bone marrow | 174 |
| Erythrocyte | 168 |
| Arterial blood | 161 |
| Capillary blood | 120 |
| Pleural fluid | 104 |
| 24-hour urine | 98 |
| Synovial fluid | 95 |
| Pharyngeal secretion | 93 |
| Ascitic fluid | 73 |
| Vaginal discharge | 64 |
| Lymphocyte | 55 |
| Pus | 55 |
| Sperm / semen | 40 |
| Expectorate (sputum) | 36 |
| Dialysis fluid | 32 |
| Peritoneal dialysis fluid | 32 |
| Aspiration fluid | 30 |
| Bronchoalveolar lavage | 30 |
| Secretion | 30 |
| Skin | 29 |
| Fasting blood; Foreign body / implant | 24 |
| Amniotic fluid | 20 |
| Central blood | 20 |
| Night (morning) urine | 19 |
| Umbilical artery blood | 18 |
| Collected urine | 17 |
| Muscle | 17 |
| Umbilical venous blood | 17 |
| Nasal secretion | 16 |
| Lymph node | 12 |
| Point-of-care test | 12 |
| Fasting erythrocyte | 9 |
| Placenta | 9 |
| Thrombocyte | 9 |
| Saliva | 8 |
| Umbilical blood | 8 |
| Chorionic villus | 7 |
| Hemoglobin | 7 |
| Bone | 5 |
| Gastrointestinal canal | 5 |
| Kidney | 5 |
| Maternal milk | 5 |
| Bile | 3 |
| Bronchial fluid | 3 |
| Liver | 3 |
| Lung | 3 |
| Nail | 3 |
| Umbilical (blood) serum | 3 |
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

n distinct suffixes: 61

| Suffix meaning | n distinct TEST_NAME |
|---|---|
| Qualitative test (also semi-quantitative) | 330 |
| DNA test | 183 |
| Antibodies | 77 |
| Free or unconjugated | 42 |
| Culture | 40 |
| Native preparation | 32 |
| Upright (standing) | 30 |
| Supine (lying down) | 25 |
| IgM antibodies | 22 |
| IgG antibodies | 21 |
| Exercise / functional test | 20 |
| Ionized | 20 |
| Stimulation, stimulated | 20 |
| Antigen | 17 |
| Clearance | 17 |
| Vitamin | 17 |
| Fractions | 13 |
| Long-term / prolonged | 13 |
| Index | 12 |
| Micro | 11 |
| Isoenzymes | 10 |
| Staining | 10 |
| Flow cytometry | 9 |
| Typing | 9 |
| Special technique | 8 |
| Immunofluorescence | 7 |
| Stability | 7 |
| Amplitude-integrated | 6 |
| Immunohistochemical | 6 |
| Electron microscopic | 5 |
| IgA antibodies | 5 |
| Confirmation, confirmatory test | 4 |
| Releasing hormone | 4 |
| Antibiotic sensitivity | 3 |
| Basic screening | 3 |
| Content | 3 |
| Oligoclonal | 3 |
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
| Nucleic acid | 1 |
| Retention | 1 |
| Species identification | 1 |
| Transcutaneous | 1 |
| Vibration sense | 1 |
