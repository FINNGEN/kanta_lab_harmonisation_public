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
| named | 1890 | 95.3% |
| left empty (not determinable) |   94 | 4.7% |
| named as a panel |  206 | 10.4% |
| distinct names guessed |  843 |  |

## Coverage by evidence level

`evidence_level` is computed from the row itself: whether it carries a `UNIT`,
a `deciles` distribution, both, or neither. The named rate should be high at
every level: the name is a search query, so the prompt asks for one whenever
the code carries any usable hint and reserves an empty name for text nothing
can be read out of. A `name` row still cannot fix its quantity — it is named
from its analyte and specimen, and `FixLOINCDimensions` settles the property
against real candidates or declines there.

| evidence_level | n_rows | n_named | pct_named |
|---|---|---|---|
| name | 1014 | 930 | 91.7% |
| name+unit+values |  573 | 573 | 100.0% |
| name+unit |  217 | 208 | 95.9% |
| name+values |  180 | 179 | 99.4% |

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
| carries a [Property] | 1519 | 80.4% |
| carries an `in <System>` | 1628 | 86.1% |
| carries a `by <Method>` |  459 | 24.3% |
| is a panel name (contains ' panel') |  206 | 10.9% |
| full `C [P] in S` shape | 1510 | 79.9% |

## Most frequently guessed names

A name guessed for many rows is usually right — the same test recurs under many local spellings — but a very high count can also mean the model fell back on a generic name for codes it could not tell apart.

| guessed LOINC name | n | pct |
|---|---|---|
| C-reactive protein [Mass/volume] in Plasma | 37 | 2.0% |
| C-reactive protein [Mass/volume] in Serum or Plasma | 26 | 1.4% |
| 12 lead EKG panel | 22 | 1.2% |
| Transferrin saturation [Molar ratio] in Serum or Plasma | 20 | 1.1% |
| CBC with platelet panel - Blood by Automated count | 19 | 1.0% |
| Erythrocyte distribution width [Ratio] in Blood by Automated count | 16 | 0.8% |
| SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen | 15 | 0.8% |
| Sodium [Moles/volume] in Serum or Plasma | 15 | 0.8% |
| Spirometry panel | 15 | 0.8% |
| Albumin/Creatinine [Mass Ratio] in Urine | 14 | 0.7% |
| Phosphatidylethanol [Moles/volume] in Blood | 14 | 0.7% |
| Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 13 | 0.7% |
| Soluble transferrin receptor [Mass/volume] in Serum or Plasma | 13 | 0.7% |
| Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum | 12 | 0.6% |
| Specimen collection procedure | 12 | 0.6% |
| Transglutaminase IgA Ab [Units/volume] in Serum | 12 | 0.6% |
| Urinalysis macro (dipstick) panel - Urine | 12 | 0.6% |
| Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 10 | 0.5% |
| Glucose [Moles/volume] in Serum or Plasma | 10 | 0.5% |
| C-reactive protein [Mass/volume] in Blood |  9 | 0.5% |

## `[Property]` used

Which LOINC property display forms the guesses carry. These should be LOINC's own bracket spellings (`[Moles/volume]`, `[Mass/volume]`), not OMOP attribute names (`Substance Concentration`).

| [property] | n | pct |
|---|---|---|
| Presence | 278 | 18.3% |
| Moles/volume | 275 | 18.1% |
| Mass/volume | 236 | 15.5% |
| Units/volume | 161 | 10.6% |
| Enzymatic activity/volume | 130 | 8.6% |
| #/volume |  94 | 6.2% |
| # Ratio |  83 | 5.5% |
| Ratio |  61 | 4.0% |
| Identifier |  31 | 2.0% |
| Mass Ratio |  26 | 1.7% |
| Molar ratio |  25 | 1.6% |
| Titer |  21 | 1.4% |
| #/area |  11 | 0.7% |
| Moles/time |  11 | 0.7% |
| Time |  11 | 0.7% |

## `in <System>` used

Which specimens the guesses name.

| in <system> | n | pct |
|---|---|---|
| Serum or Plasma | 353 | 21.7% |
| Blood | 279 | 17.1% |
| Serum | 240 | 14.7% |
| Plasma | 162 | 10.0% |
| Urine | 139 | 8.5% |
| Respiratory specimen |  91 | 5.6% |
| Specimen |  53 | 3.3% |
| Stool |  34 | 2.1% |
| Cerebral spinal fluid |  30 | 1.8% |
| 24 hour Urine |  18 | 1.1% |
| Throat |  17 | 1.0% |
| Urine sediment |  16 | 1.0% |
| Capillary blood |  13 | 0.8% |
| Apheresis product |  10 | 0.6% |
| Bone marrow |  10 | 0.6% |

## `by <Method>` used

Which methods the guesses name. LOINC omits Method for most chemistry, so a long tail here means the model is inventing methods the codes do not state — which makes the search miss the plain term.

| by <method> | n | pct |
|---|---|---|
| Automated count | 120 | 26.1% |
| NAA with probe detection |  94 | 20.5% |
| Culture |  37 | 8.1% |
| Molgen |  32 | 7.0% |
| NAA |  30 | 6.5% |
| Organism specific culture |  30 | 6.5% |
| Test strip |  18 | 3.9% |
| Electrophoresis |  12 | 2.6% |
| Rapid immunoassay |  12 | 2.6% |
| Microscopy |  10 | 2.2% |
| Stain |   6 | 1.3% |
| Microscopy light |   5 | 1.1% |
| Subculture |   5 | 1.1% |
| FISH |   4 | 0.9% |
| Hemagglutination |   4 | 0.9% |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA/FindLOINCDimensions/reflections.md`.

### Key findings

- The `deciles` (value distribution) and `unit` columns are critical for disambiguating tests, such as distinguishing individual results from a panel, qualitative from quantitative tests, and resolving garbled or concatenated codes.
- Inferring the specimen (System) based on clinical context is frequently necessary and essential for effective mapping, as it is often missing from the source test code.
- Recognizing and correctly distinguishing panels from single-analyte tests is a core, recurring task that relies on interpreting local abbreviations, `LongName` fields, and the structure of the test name.
- A consistent set of rules is needed to resolve conflicts in the data, such as prioritizing the descriptive test name over a contradictory specimen prefix, and prioritizing quantitative data (units, values) over ambiguous text qualifiers.
- Interpreting a wide variety of local Finnish abbreviations, synonyms, and naming patterns (e.g., for methods, timings, isoenzymes, screening tests) is fundamental to the mapping process.
- Identifying codes for non-laboratory procedures (e.g., sample collection, billing, therapies, clinical assessments) and mapping them to appropriate LOINC procedure concepts or leaving them empty is an important part of the workflow.
- For creating effective search queries, it is often better to simplify the LOINC guess by omitting the method (e.g., 'Point-of-care') or using a broader system (e.g., 'Serum or Plasma').
- Distinguishing between different LOINC properties for the same analyte (e.g., absolute vs. relative counts, qualitative vs. quantitative results) requires careful analysis of units, prefixes, and context.
- Using external clinical knowledge is unavoidable for tasks like inferring the most likely specimen for a pathogen or specifying whether a nucleic acid is DNA or RNA.
- Grouping codes by string similarity is a powerful tool for interpreting truncated or misspelled local codes by providing context from clearer examples.

### Suggested improvements

- Provide a comprehensive dictionary or codebook that maps local abbreviations, prefixes, and panel names to official long names and their meanings.
- Ensure the `LongName` field is populated for as many codes as possible, as it is indispensable for interpreting ambiguous codes, especially panels and pathology procedures.
- Include the original specimen type as a separate data field, as this would significantly improve mapping accuracy for microbiology and nucleic acid tests where this information is often missing from the code.
- For ratio tests, the source data should explicitly name the denominator component in the `LongName` to avoid requiring inference from the unit.
- Implement a pre-processing step to identify and flag codes that represent administrative, procedural, or logistical tasks (e.g., sample collection, billing) rather than laboratory observations.

### Systematic data problems

- The source data contains a high frequency of ambiguous, non-standard, or garbled abbreviations that are uninterpretable without external context or a `LongName`.
- Crucial information is frequently missing from the source codes, most notably the specimen type (System), but also units for quantitative tests and the clinical context for stimulation/suppression tests.
- The data is cluttered with non-mappable codes representing administrative tasks (billing), logistics (storage), and pre-analytical procedures (sample collection) mixed in with laboratory tests.
- Individual test codes often contain contradictory information, such as a qualitative text hint with a quantitative unit, or a specimen prefix that conflicts with the test's descriptive name.
- The same clinical test is often represented by many different local synonyms, abbreviations, and naming variations, requiring normalization.
- Data entry errors are common, including typos in units, misspelled test names, and formatting artifacts like leading hyphens or stuttered suffixes.
- Some test codes are created by concatenating multiple abbreviations, making them difficult to parse without understanding the local conventions.

