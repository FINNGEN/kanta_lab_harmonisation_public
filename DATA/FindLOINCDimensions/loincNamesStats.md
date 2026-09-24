# LOINC Name Guesses -- Stats

Source: `DATA/FindLOINCDimensions/codesWithLoincNames.tsv`

Rows (local `TEST_NAME`/`UNIT` combinations): 1984
Similarity groups covered: 30

## Overview

An empty name means the model judged the code not identifiable from its row —
the prompt asks it to leave the name empty rather than invent one, so empties
are expected, not failures.

| bucket | n | pct |
|---|---|---|
| total rows | 1984 | 100.0% |
| named | 1790 | 90.2% |
| left empty (not determinable) |  194 | 9.8% |
| flagged as a panel |  201 | 10.1% |
| distinct names guessed |  785 |  |

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
| carries a [Property] | 1389 | 77.6% |
| carries an `in <System>` | 1522 | 85.0% |
| carries a `by <Method>` |  411 | 23.0% |
| is a panel name (contains ' panel') |  191 | 10.7% |
| full `C [P] in S` shape | 1380 | 77.1% |

## Most frequently guessed names

A name guessed for many rows is usually right — the same test recurs under many local spellings — but a very high count can also mean the model fell back on a generic name for codes it could not tell apart.

| guessed LOINC name | n | pct |
|---|---|---|
| C reactive protein [Mass/volume] in Serum or Plasma | 80 | 4.5% |
| SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 25 | 1.4% |
| 12 lead EKG panel | 22 | 1.2% |
| Transferrin saturation [Molar ratio] in Serum or Plasma | 20 | 1.1% |
| Erythrocyte [DistWidth] in Red Blood Cells | 19 | 1.1% |
| Specimen collection procedure | 19 | 1.1% |
| Albumin/Creatinine [Mass Ratio] in Urine | 18 | 1.0% |
| Short blood count panel - Blood | 18 | 1.0% |
| Sodium [Moles/volume] in Serum or Plasma | 18 | 1.0% |
| Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 14 | 0.8% |
| Phosphatidylethanol [Moles/volume] in Blood | 14 | 0.8% |
| Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | 13 | 0.7% |
| Troponin I.cardiac [Mass/volume] in Serum or Plasma | 12 | 0.7% |
| Urinalysis macro (dipstick) panel - Urine | 12 | 0.7% |
| Bacteria identified in Urine by Culture | 11 | 0.6% |
| Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | 11 | 0.6% |
| Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | 10 | 0.6% |
| Fasting glucose [Moles/volume] in Serum or Plasma | 10 | 0.6% |
| Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma |  9 | 0.5% |
| Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma |  9 | 0.5% |

## `[Property]` used

Which LOINC property display forms the guesses carry. These should be LOINC's own bracket spellings (`[Moles/volume]`, `[Mass/volume]`), not OMOP attribute names (`Substance Concentration`).

| [property] | n | pct |
|---|---|---|
| Presence | 380 | 27.4% |
| Moles/volume | 245 | 17.6% |
| Mass/volume | 227 | 16.3% |
| Enzymatic activity/volume | 118 | 8.5% |
| Units/volume | 102 | 7.3% |
| #/volume |  92 | 6.6% |
| Identifier |  36 | 2.6% |
| Mass Ratio |  26 | 1.9% |
| Molar ratio |  25 | 1.8% |
| # Ratio |  24 | 1.7% |
| DistWidth |  19 | 1.4% |
| Titer |  12 | 0.9% |
| Moles/time |  11 | 0.8% |
| #/area |  10 | 0.7% |
| Entitic mass |   9 | 0.6% |

## `in <System>` used

Which specimens the guesses name.

| in <system> | n | pct |
|---|---|---|
| Serum or Plasma | 584 | 38.4% |
| Blood | 226 | 14.8% |
| Urine | 142 | 9.3% |
| Serum | 101 | 6.6% |
| Respiratory system specimen |  99 | 6.5% |
| Stool |  38 | 2.5% |
| Red Blood Cells |  33 | 2.2% |
| Cerebral spinal fluid |  30 | 2.0% |
| Specimen |  22 | 1.4% |
| 24 hour Urine |  17 | 1.1% |
| Platelet poor plasma |  17 | 1.1% |
| Plasma |  16 | 1.1% |
| Serum or Plasma --fasting |  16 | 1.1% |
| Bone marrow |  15 | 1.0% |
| Throat |  15 | 1.0% |

## `by <Method>` used

Which methods the guesses name. LOINC omits Method for most chemistry, so a long tail here means the model is inventing methods the codes do not state — which makes the search miss the plain term.

| by <method> | n | pct |
|---|---|---|
| NAA with probe detection | 111 | 27.0% |
| Automated count |  50 | 12.2% |
| Culture |  48 | 11.7% |
| Molecular genetics method |  38 | 9.2% |
| Rapid immunoassay |  28 | 6.8% |
| Organism specific culture |  20 | 4.9% |
| Point of care |  17 | 4.1% |
| Test strip |  14 | 3.4% |
| Electrophoresis |  13 | 3.2% |
| Light microscopy |  10 | 2.4% |
| NAA |   9 | 2.2% |
| Stain |   7 | 1.7% |
| calculation |   5 | 1.2% |
| Glucose meter |   3 | 0.7% |
| High sensitivity method |   3 | 0.7% |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA/FindLOINCDimensions/reflections.md`.

### Key findings

- The combination of `p_missing` (percent of missing values), `UNIT`, and `deciles` is the most reliable method for distinguishing between quantitative tests, qualitative tests, and panel orders.
- Effective mapping requires synthesizing information from all available data columns (`TEST_NAME`, `UNIT`, `deciles`, `p_missing`, `LongName`), as no single column is sufficient on its own.
- Quantitative data, especially `deciles` and `UNIT`, should be prioritized over potentially inaccurate or contradictory information in the local `TEST_NAME`.
- Missing specimen information (`System`) can often be reliably inferred from the analyte's context, from similar codes within a group, or by matching decile value distributions.
- Identifying and decoding recurring local patterns, such as prefixes for specimen, and suffixes for methods (`-nho`), panels (`-seul`, `-pak`), or component tests (`osatutkimus`), is critical for accurate mapping.
- Many different local test names—including variations in spelling, brand names, or procedural context—often map to a single, more general LOINC concept.
- A significant number of local codes represent administrative or procedural events (e.g., sample collection, billing) rather than analytical results, and must be handled differently.
- Panel tests are identifiable by keywords (`-seul`, `-pak`), pluralized names, or prefixes like `Pt-`, which is often reinforced by a `p_missing` value of 100%.

### Suggested improvements

- Provide the official Finnish long name (`LongName`) for every local test code, as this would be the single most impactful improvement for resolving ambiguity.
- Provide a cross-reference or dictionary for common local abbreviations, especially for drugs of abuse, genetic targets, and panel components.
- Provide the official Finnish 4-digit national laboratory code for each test to help disambiguate methods and components.
- Implement a data quality check to automatically flag rows where information between columns is contradictory (e.g., test name vs. unit, national code vs. local prefix) for upstream review.
- Provide a reference catalogue of common allergen codes to aid in mapping specific IgE tests.

### Systematic data problems

- Source data contains many ambiguous, non-standard, or overly truncated local abbreviations that are unmappable without a `LongName` or a reference key.
- Records frequently contain contradictory information, such as a qualitative test name with quantitative units, or decile values that are inconsistent with the named analyte.
- A large number of test codes lack a prefix or other explicit information about the specimen type, making the `System` difficult to determine with certainty.
- The `UNIT` field contains errors, including typos, uninterpretable values (e.g., 'form'), and the erroneous application of quantitative units to qualitative tests.
- Local `TEST_NAME`s are often overloaded with information not part of the core test concept, such as clinical context, procedural details, billing terms, or multiple conflicting analyte names.
- Panel codes often have generic names (e.g., 'basic package') with no information about their specific components, making them impossible to map to a specific LOINC panel.
- Some test codes are clearly typos, garbled, or contain embedded metadata for data entry purposes (e.g., 'dummy record'), complicating the mapping task.
- Some records have decile values that are astronomically high or nonsensical for the named analyte, indicating data errors or unidentifiable, highly specific contexts.

