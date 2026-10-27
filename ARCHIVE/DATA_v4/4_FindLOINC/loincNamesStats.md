# LOINC Name Guesses -- Stats

Source: `DATA_v4/FindLOINCDimensions/codesWithLoincNames.tsv`

Rows (local `TEST_NAME`/`UNIT` combinations): 2687
Similarity groups covered: 30

## Overview

An empty name means the model judged the code not identifiable from its row —
the prompt asks it to leave the name empty rather than invent one, so empties
are expected, not failures.

| bucket | n | pct |
|---|---|---|
| total rows | 2687 | 100.0% |
| named | 2577 | 95.9% |
| left empty (not determinable) |  110 | 4.1% |
| named as a panel |  213 | 7.9% |
| distinct names guessed | 1083 |  |

## Coverage by evidence level

`evidence_level` is computed from the row itself: whether it carries a `UNIT`,
a `value_deciles` distribution, both, or neither. The named rate should be high at
every level: the name is a search query, so the prompt asks for one whenever
the code carries any usable hint and reserves an empty name for text nothing
can be read out of. A `name` row still cannot fix its quantity — it is named
from its analyte and specimen, and `FixLOINCDimensions` settles the property
against real candidates or declines there.

| evidence_level | n_rows | n_named | pct_named |
|---|---|---|---|
| name | 1360 | 1256 | 92.4% |
| name+unit+values |  809 |  807 | 99.8% |
| name+values |  278 |  274 | 98.6% |
| name+unit |  240 |  240 | 100.0% |

## Name shape

The guess is a **search query** for the next step, so what matters is whether it
is shaped like a real LOINC Long Common Name:

```
<Component> [<Property>] in <System> by <Method>
```

Everything after the component is optional in real LOINC names too (most
chemistry carries no Method; nominal and fraction terms carry no `[Property]`),
so this is a shape profile, not a pass/fail test. A sharp drop in
`carries a [Property]` or `carries an in <System>` means the model has started
describing tests instead of naming them, and retrieval will suffer.

| part | n | pct_of_named |
|---|---|---|
| carries a [Property] | 2076 | 80.6% |
| carries an `in <System>` | 2279 | 88.4% |
| carries a `by <Method>` |  547 | 21.2% |
| is a panel name (contains ' panel') |  213 | 8.3% |
| full `C [P] in S` shape | 2046 | 79.4% |

## Most frequently guessed names

A name guessed for many rows is usually right — the same test recurs under many local spellings — but a very high count can also mean the model fell back on a generic name for codes it could not tell apart.

| guessed LOINC name | n | pct |
|---|---|---|
| Glucose [Moles/volume] in Serum or Plasma | 66 | 2.6% |
| C reactive protein [Mass/volume] in Plasma | 38 | 1.5% |
| Microscopic observation [Identifier] in Tissue by Light microscopy | 34 | 1.3% |
| Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 25 | 1.0% |
| C reactive protein [Mass/volume] in Serum or Plasma | 24 | 0.9% |
| Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood | 21 | 0.8% |
| Calcium.ionized [Moles/volume] in Serum adjusted to pH 7.4 | 18 | 0.7% |
| Albumin/Creatinine [Mass Ratio] in Urine | 17 | 0.7% |
| Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 17 | 0.7% |
| 12 lead EKG panel | 16 | 0.6% |
| Hemoglobin A1c/Hemoglobin.total in Blood | 16 | 0.6% |
| Calcium.ionized [Moles/volume] in Plasma | 15 | 0.6% |
| Glucose [Moles/volume] in Blood | 15 | 0.6% |
| Sodium [Moles/volume] in Plasma | 15 | 0.6% |
| C-reactive protein [Mass/volume] in Plasma | 13 | 0.5% |
| Drugs of abuse screen panel - Urine | 13 | 0.5% |
| Erythrocyte distribution width [Volume Ratio] in Red Blood Cells by Automated count | 13 | 0.5% |
| Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood | 13 | 0.5% |
| Tissue transglutaminase Ab.IgA [Units/volume] in Serum | 13 | 0.5% |
| Bacteria identified in Urine by Culture | 12 | 0.5% |

## `[Property]` used

Which LOINC property display forms the guesses carry. These should be LOINC's own bracket spellings (`[Moles/volume]`, `[Mass/volume]`), not OMOP attribute names (`Substance Concentration`).

| [property] | n | pct |
|---|---|---|
| Moles/volume | 588 | 28.3% |
| Mass/volume | 390 | 18.8% |
| Presence | 252 | 12.1% |
| Identifier | 125 | 6.0% |
| Units/volume | 122 | 5.9% |
| Enzymatic activity/volume | 103 | 5.0% |
| Ratio |  76 | 3.7% |
| #/volume |  56 | 2.7% |
| Molar ratio |  47 | 2.3% |
| Activity |  46 | 2.2% |
| Mass Ratio |  43 | 2.1% |
| Titer |  30 | 1.4% |
| Time |  24 | 1.2% |
| Volume Fraction |  21 | 1.0% |
| #/area |  18 | 0.9% |

## `in <System>` used

Which specimens the guesses name.

| in <system> | n | pct |
|---|---|---|
| Serum | 444 | 19.5% |
| Plasma | 361 | 15.8% |
| Serum or Plasma | 307 | 13.5% |
| Blood | 270 | 11.8% |
| Urine | 175 | 7.7% |
| Tissue |  50 | 2.2% |
| Stool |  48 | 2.1% |
| Urine sediment |  48 | 2.1% |
| Blood or Tissue |  40 | 1.8% |
| Unspecified specimen |  40 | 1.8% |
| Throat |  39 | 1.7% |
| Specimen |  36 | 1.6% |
| Platelet poor plasma |  31 | 1.4% |
| Serum or Plasma --2 hours post dose glucose |  25 | 1.1% |
| Pleural fluid |  21 | 0.9% |

## `by <Method>` used

Which methods the guesses name. LOINC omits Method for most chemistry, so a long tail here means the model is inventing methods the codes do not state — which makes the search miss the plain term.

| by <method> | n | pct |
|---|---|---|
| Culture | 78 | 14.3% |
| NAA with probe detection | 68 | 12.4% |
| Light microscopy | 63 | 11.5% |
| Organism specific culture | 55 | 10.1% |
| Automated count | 49 | 9.0% |
| NAA | 25 | 4.6% |
| Test strip | 24 | 4.4% |
| calculation | 21 | 3.8% |
| Molecular genetics method | 17 | 3.1% |
| Microscopy | 14 | 2.6% |
| Point-of-care | 14 | 2.6% |
| Immunoassay | 11 | 2.0% |
| Stain | 11 | 2.0% |
| Cytology |  6 | 1.1% |
| Immunohistochemistry |  5 | 0.9% |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA_v4/FindLOINCDimensions/reflections.md`.

### Key findings

- Inferring missing information, especially the specimen/system based on the analyte, is an essential and frequent strategy for creating a useful mapping.
- Quantitative data, particularly units and value distributions, are often more reliable than the literal test name for determining the true analyte (e.g., eGFR vs. creatinine) or test subtype (e.g., hs-CRP vs. CRP).
- Identifying that a local code represents a panel, reflex test, or bundled procedure is crucial; mapping these to a LOINC panel concept is often more accurate than choosing a single component.
- The 'LongName' field is invaluable for disambiguating abbreviated, garbled, or otherwise ambiguous codes, and is often essential for interpreting an entire family of related tests.
- Many local codes require specific clinical or procedural domain knowledge (e.g., for serology, genetics, histopathology) and an understanding of Finnish medical terms to interpret correctly.
- A consistent strategy for handling point-of-care (POCT) codes (e.g., `vieritesti`, `pika`) is to map to the base analyte, as LOINC often does not distinguish POCT in the component name.
- Local suffixes or prefixes often represent pre-analytical conditions (e.g., fasting), challenge timing (pre/post-dialysis), or administrative context (e.g., ordering ward), which must be either mapped to specific LOINC challenge fields or ignored.
- 'Pt-' (Patient) prefixed codes are a special category representing a wide variety of concepts beyond simple lab tests, including procedures, calculations, physical measurements, and administrative actions.
- Distinguishing different forms of a substance (e.g., total vs. free testosterone, ionized vs. total calcium) or different reporting standards (e.g., HbA1c in % vs. mmol/mol) requires careful parsing of local conventions, units, and values.

### Suggested improvements

- Provide a dictionary of local, non-standard, or proprietary abbreviations and prefixes (e.g., `s-kipa`, `Hertta`, `ap-`, `cp-`) to reduce guesswork and improve accuracy.
- Enrich ambiguous codes with additional context, such as the most frequent ordering department or documentation on what tests are included in local panels.
- Improve upstream data processing by fixing systematic parsing errors (e.g., 'Cl' misinterpreted as 'Clearance') and cleaning artifacts like leading hyphens or trailing punctuation.
- When possible, link fragmented codes (e.g., those starting with a hyphen) back to their original, more complete source strings to increase interpretability.

### Systematic data problems

- A high frequency of missing or ambiguous specimen information in test codes, requiring inference or the use of a generic 'Specimen' system.
- A significant number of unmappable codes that refer to administrative actions, billing, sample logistics, or overly generic 'bucket' concepts rather than specific clinical tests.
- Frequent inconsistencies and contradictions between different data fields, such as qualitative test names with quantitative values/units, or test names that are contradicted by the units and value ranges.
- Extreme variability and lack of standardization in local naming, including numerous synonyms, spelling variations, garbled/truncated codes, and uninterpretable local suffixes.
- The presence of non-standard and ambiguous system prefixes (e.g., `ap-`, `cp-`, `vp-`, `mb-`) that require educated guesses to interpret.
- Data quality issues such as clearly erroneous units for a given test, physiologically impossible values, or biologically implausible test-specimen combinations (e.g., pH in Serum).
- Many codes are simply too ambiguous or vague to interpret without a 'LongName' or other external context.
- Some codes describe the collection container or its additive (e.g., citrate concentration) rather than the analyte being measured, making the actual test unknowable.

