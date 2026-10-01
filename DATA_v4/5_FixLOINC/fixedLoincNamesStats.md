# Guessed Names -> OMOP Concepts -- Stats

Source: `DATA_v4/FixLOINCDimensions/codesWithOmopConcepts.tsv`

Rows (local `TEST_NAME`/`UNIT` combinations): 2687
Similarity groups covered: 30

## Overview

An unmapped row is not automatically a failure: the prompt tells the model to
leave the id empty when no candidate is right, which is the correct answer for
a code too garbled to identify, for a non-laboratory code, and for a test whose
concept the search did not return.

| bucket | n | pct |
|---|---|---|
| total rows | 2687 | 100.0% |
| named by FindLOINCDimensions | 2577 | 95.9% |
| mapped to an OMOP concept | 2082 | 77.5% |
| named but left unmapped |  496 | 18.5% |
| unnamed and unmapped |  109 | 4.1% |
| unnamed but still mapped |    1 | 0.0% |
| distinct concepts chosen |  710 |  |

## Did the search find anything?

Per distinct guessed name, whether Hecate returned any concept at all and how
close the best one was. This separates *the search failed* from *the model
rejected what the search found* — two problems with completely different fixes:
the first is about how the guess is phrased, the second about the evidence in
the row.

| bucket | n | pct |
|---|---|---|
| distinct names guessed | 1083 | 100.0% |
| returned at least one concept | 1076 | 99.4% |
| returned nothing |    7 | 0.6% |
| best hit scored >= 0.90 |  612 | 56.5% |
| best hit scored 0.75 - 0.90 |  398 | 36.7% |
| best hit scored < 0.75 |   66 | 6.1% |

## What kind of concept was chosen

The prompt asks the model to break ties by preferring a concept on the **LOINC
Top 2000+ (SI)** recommended list — an external recommendation. The Finnish
usage column is a *diagnostic here only*: it comes from the curated reference
mappings, which the prompt is never shown, since feeding the thing this
pipeline is measured against back into it would make the evaluation circular.
A high share in neither bucket means the model is routinely landing on obscure
concepts, which is worth a look even when the concept is defensible.

| bucket | n | pct |
|---|---|---|
| mapped rows | 2082 | 100.0% |
| chose a LOINC Top 2000 concept | 1002 | 48.1% |
| chose a concept already used in Finnish mappings | 1303 | 62.6% |
| chose one that is both |  811 | 39.0% |
| chose one that is neither |  588 | 28.2% |

## Most chosen concepts

The concepts the most local codes were mapped to. A concept collecting a very
large number of rows is worth checking: it may genuinely be the test that
recurs under many local spellings, or it may be where codes the model could
not tell apart ended up.

| omop_concept_id | omop_concept_name | n_rows | top2000 |
|---|---|---|---|
| 3011173 | Microscopic observation [Identifier] in Tissue by Hematoxylin and eosin stain | 57 |  |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 39 |  |
| 3018251 | Fasting glucose [Moles/volume] in Serum or Plasma | 35 | yes |
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 35 | yes |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 34 | yes |
| 3021347 | Calcium.ionized [Moles/volume] in Serum or Plasma | 33 | yes |
| 3016431 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Serum or Plasma | 29 |  |
| 3016701 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 25 | yes |
| 3033543 | Specific gravity of Urine | 22 | yes |
| 3009814 | Iron saturation [Molar fraction] in Serum or Plasma | 18 | yes |
| 3015024 | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 17 | yes |
| 3019050 | Tissue transglutaminase IgA Ab [Units/volume] in Serum | 17 | yes |
| 3019902 | Methicillin resistant Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 16 | yes |
| 3044889 | 12 lead EKG panel | 16 |  |
| 3020491 | Glucose [Moles/volume] in Blood | 15 | yes |
| 3024135 | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | 15 | yes |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 15 |  |
| 3004410 | Hemoglobin A1c/Hemoglobin.total in Blood | 14 | yes |
| 36032269 | Testosterone Free [Moles/volume] in Serum or Plasma by calculation | 14 |  |
| 3000963 | Hemoglobin [Mass/volume] in Blood | 13 | yes |

## How sure the model says it is

One overall certainty per mapped row, self-reported. It is a claim, not a
measurement — but a `low` row is one the model is telling you to check, and
those are cheap to act on.

| certainty | n_rows | pct |
|---|---|---|
| high | 1700 | 81.7% |
| medium |  344 | 16.5% |
| low |   38 | 1.8% |
| (not stated) |    0 | 0.0% |

A reasoning trail — why each part of the chosen name is right, clause by clause — was given for **2082 / 2082** mapped rows. It is in the `reasoning` column of `codesWithOmopConcepts.tsv`, and it is what makes a mapping reviewable without re-deriving it.

Certainty against the evidence the row actually carried. A concept claimed
`high` on a `name` row is worth checking, since such a row has no unit
and no values to fix a quantity with:

| evidence_level | high | low | medium |
|---|---|---|---|
| name | 586 | 29 | 259 |
| name+unit | 163 |  2 |  27 |
| name+unit+values | 720 |  4 |  38 |
| name+values | 231 |  3 |  20 |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA_v4/FixLOINCDimensions/reflections.md`.

### Key findings

- Quantitative evidence, especially units (`UNIT`) and value distributions (`value_deciles`), is crucial for reliably distinguishing between LOINC concepts with different properties (e.g., Moles/volume vs. Mass/volume) and for confirming mappings.
- The Finnish local codes are highly structured and informative, with specimen prefixes (e.g., `S-`, `B-`, `Li-`), method/analyte suffixes (e.g., `-nho`, `-vi`), and descriptive qualifiers (e.g., `pika`, `herkkä`) providing strong evidence for mapping.
- Mapping often requires inference and abstraction, such as deducing a test's property from value ranges, abstracting specific specimens to broader LOINC system terms (e.g., arterial plasma to 'Serum or Plasma'), or mapping a specific local test to a more generic LOINC concept when an exact match is unavailable.
- Identifying and mapping panels (often prefixed `Pt-` or named with terms like `paketti`) is a distinct and common challenge, requiring matching a group of local components to a single LOINC panel concept.
- Context is critical for disambiguation, as some local codes are cryptic until viewed with related codes, while others are used inconsistently (e.g., a qualitative suffix on a quantitative test) or represent multiple different analytes, requiring other evidence to resolve.

### Suggested improvements

- The candidate generation process must be improved to include common, fundamental LOINC concepts that were frequently missing, such as HbA1c in IFCC units (`mmol/mol`, property `[Substance Ratio]`), basic aPTT with a `Time` property, and common questionnaires like AUDIT/AUDIT-C.
- Improve retrieval of common pathology method concepts, which were consistently absent from candidate lists, including those for immunohistochemistry (IHC), in situ hybridization (ISH), FISH, frozen section, and macroscopic/gross observation.
- Enhance the search to find and propose a wider range of panel concepts, as many local codes for specific diagnostic panels (e.g., 6-drug screen, immunofixation, fungus culture + microscopy) could not be mapped.
- Broaden search results to include candidates for specific analytes, methods, properties, or specimens that were frequently missing, such as point-of-care tests, specific genetic variants (e.g., CYP3A5), specific isomers (beta-CTX), or tests on less common body sites (e.g., Perineum).
- Improve the search to retrieve concepts for procedures and imaging studies (e.g., PET, SPECT, bone scan, audiology), as these are common in the source data but consistently lack candidates.

### Systematic data problems

- A large number of source records lack quantitative information (units or values), making it impossible to determine the correct property (e.g., mass vs. molar concentration) and preventing a confident mapping.
- The source data contains many codes that do not represent reportable laboratory results, including administrative/billing codes, procedural codes, sample collection/storage codes, and lab workflow steps (e.g., subculture).
- Many local codes are too ambiguous, generic, or cryptic to be safely mapped to a specific LOINC concept without further context.
- The source data contains internal contradictions, such as local codes with a qualitative suffix (`-O`) but quantitative units and values, requiring the mapper to prioritize one piece of conflicting evidence.
- Some records have clear data quality errors, such as nonsensical units for an analyte or values that are impossible for the test, which undermines mapping confidence.
- A single local code is sometimes used to represent multiple distinct analytes (e.g., one code for both Hematocrit and MCV), requiring disambiguation using units and value ranges.

