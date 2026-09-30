# Guessed Names -> OMOP Concepts -- Stats

Source: `DATA/FixLOINCDimensions/codesWithOmopConcepts.tsv`

Rows (local `TEST_NAME`/`UNIT` combinations): 1984
Similarity groups covered: 30

## Overview

An unmapped row is not automatically a failure: the prompt tells the model to
leave the id empty when no candidate is right, which is the correct answer for
a code too garbled to identify, for a non-laboratory code, and for a test whose
concept the search did not return.

| bucket | n | pct |
|---|---|---|
| total rows | 1984 | 100.0% |
| named by FindLOINCDimensions | 1890 | 95.3% |
| mapped to an OMOP concept | 1566 | 78.9% |
| named but left unmapped |  326 | 16.4% |
| unnamed and unmapped |   92 | 4.6% |
| unnamed but still mapped |    2 | 0.1% |
| distinct concepts chosen |  605 |  |

## Did the search find anything?

Per distinct guessed name, whether Hecate returned any concept at all and how
close the best one was. This separates *the search failed* from *the model
rejected what the search found* — two problems with completely different fixes:
the first is about how the guess is phrased, the second about the evidence in
the row.

| bucket | n | pct |
|---|---|---|
| distinct names guessed | 843 | 100.0% |
| returned at least one concept | 842 | 99.9% |
| returned nothing |   1 | 0.1% |
| best hit scored >= 0.90 | 531 | 63.0% |
| best hit scored 0.75 - 0.90 | 264 | 31.3% |
| best hit scored < 0.75 |  47 | 5.6% |

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
| mapped rows | 1566 | 100.0% |
| chose a LOINC Top 2000 concept |  743 | 47.4% |
| chose a concept already used in Finnish mappings |  903 | 57.7% |
| chose one that is both |  530 | 33.8% |
| chose one that is neither |  450 | 28.7% |

## Most chosen concepts

The concepts the most local codes were mapped to. A concept collecting a very
large number of rows is worth checking: it may genuinely be the test that
recurs under many local spellings, or it may be where codes the model could
not tell apart ended up.

| omop_concept_id | omop_concept_name | n_rows | top2000 |
|---|---|---|---|
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 47 |  |
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 33 | yes |
| 36033641 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 24 |  |
| 3044889 | 12 lead EKG panel | 22 |  |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 21 | yes |
| 3009814 | Iron saturation [Molar fraction] in Serum or Plasma | 19 | yes |
| 21493451 | Spirometry panel | 17 |  |
| 3019897 | Erythrocyte [DistWidth] in Red Blood Cells by Automated count | 16 | yes |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 16 | yes |
| 3046538 | Tissue transglutaminase IgA Ab [Units/volume] in Serum by Immunoassay | 16 | yes |
| 3001802 | Microalbumin/Creatinine [Mass Ratio] in Urine | 14 | yes |
| 3015399 | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | 13 |  |
| 40760140 | CBC W Auto Differential panel - Blood | 13 |  |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 12 | yes |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 12 |  |
| 40761511 | CBC panel - Blood by Automated count | 12 |  |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 11 | yes |
| 3026910 | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | 11 | yes |
| 3019900 | Cholesterol [Moles/volume] in Serum or Plasma | 10 | yes |
| 3019902 | Methicillin resistant Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 10 | yes |

## How sure the model says it is

One overall certainty per mapped row, self-reported. It is a claim, not a
measurement — but a `low` row is one the model is telling you to check, and
those are cheap to act on.

| certainty | n_rows | pct |
|---|---|---|
| high | 1296 | 82.8% |
| medium |  246 | 15.7% |
| low |   24 | 1.5% |
| (not stated) |    0 | 0.0% |

A reasoning trail — why each part of the chosen name is right, clause by clause — was given for **1566 / 1566** mapped rows. It is in the `reasoning` column of `codesWithOmopConcepts.tsv`, and it is what makes a mapping reviewable without re-deriving it.

Certainty against the evidence the row actually carried. A concept claimed
`high` on a `name` row is worth checking, since such a row has no unit
and no values to fix a quantity with:

| evidence_level | high | low | medium |
|---|---|---|---|
| name | 483 |  9 | 192 |
| name+unit | 141 | 13 |  17 |
| name+unit+values | 516 |  1 |  23 |
| name+values | 156 |  1 |  14 |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA/FixLOINCDimensions/reflections.md`.

### Key findings

- The systematic nature of Finnish local codes, using prefixes for specimen (e.g., S-, P-, Li-) and suffixes for method (e.g., -nho, -vi), is a major facilitator of accurate mapping.
- The presence of quantitative data (units and value distributions) is critical for correctly identifying the LOINC property (e.g., Mass vs. Moles, Quantitative vs. Qualitative, Absolute count vs. Ratio) and is often the deciding factor in whether a code can be mapped.
- The candidate lists generated by semantic search are frequently of high quality and contain the correct concepts, especially for common analytes.
- Prioritizing 'Top-2000' LOINC concepts is a useful heuristic for mapping common, standardized tests, promoting consistency.
- Mapping local panel codes is a recurring challenge, often requiring a compromise between mapping to a more generic panel or leaving the code unmapped if no suitable candidate exists.
- A common and effective mapping strategy involves generalizing when a specific concept is unavailable, for instance by mapping to a 'Specimen' concept when a specific site is not in the candidate list.
- Specific Finnish terms such as 'pika' and 'vieritesti' reliably identify point-of-care or rapid tests, allowing for more specific mappings when corresponding LOINC concepts are available.
- The automatically generated 'loinc_name_guess' serves as a good initial starting point, but expert review is essential to select the most appropriate concept based on all available evidence.

### Suggested improvements

- Improve the candidate search to more reliably retrieve concepts with ratio or fraction properties (e.g., %, index, molar fraction), as these are frequently missing for flow cytometry and serology tests.
- Improve the candidate search to better handle panels, including retrieving concepts for common combinations (e.g., CBC with reticulocytes), and providing more generic panel options when a specific local panel does not have an exact LOINC match.
- Broaden the candidate search to include concepts for a wider variety of specimen types for a given analyte, as candidates are often missing for less common but valid specimens like CSF, amniotic fluid, or pancreatic juice.
- Enhance the candidate search to better recognize and retrieve concepts with specific timing or challenge details (e.g., '1 hour post meal', 'post challenge', 'screening' vs 'confirmatory').
- For source codes that describe a procedure (e.g., 'specimen collection'), the candidate search should retrieve LOINC procedure concepts, not just descriptive attribute concepts like 'collection method'.
- Ensure the candidate search retrieves all relevant property types for an analyte (e.g., both Mass/volume and Moles/volume) when multiple exist, to avoid unmappable rows due to property mismatches.

### Systematic data problems

- A significant number of local codes are ambiguous, uninterpretable, or truncated abbreviations, making them impossible to map with confidence.
- The source data contains many codes that do not represent laboratory results, but rather administrative/billing actions, sample handling procedures (e.g., 'frozen sample'), or internal lab workflow steps (e.g., 'subculture').
- The frequent absence of unit or value distribution data for a given local code is a primary blocker to mapping, as it makes it impossible to reliably determine the measurement's property.
- Some local codes are too generic for a precise mapping, such as not specifying an immunoglobulin subclass (IgA vs IgG), the exact components of a panel, or the specific analyte in a screening test.
- Many local codes represent locally defined, non-standard panels or bundles of tests that do not correspond to any available LOINC panel concept.
- There are occasional conflicts within the source data, such as a test name suggesting a qualitative result being paired with quantitative units and values.

