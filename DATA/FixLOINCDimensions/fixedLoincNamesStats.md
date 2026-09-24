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
| named by FindLOINCDimensions | 1790 | 90.2% |
| mapped to an OMOP concept | 1599 | 80.6% |
| named but left unmapped |  200 | 10.1% |
| unnamed and unmapped |  185 | 9.3% |
| unnamed but still mapped |    9 | 0.5% |
| distinct concepts chosen |  631 |  |

## Did the search find anything?

Per distinct guessed name, whether Hecate returned any concept at all and how
close the best one was. This separates *the search failed* from *the model
rejected what the search found* — two problems with completely different fixes:
the first is about how the guess is phrased, the second about the evidence in
the row.

| bucket | n | pct |
|---|---|---|
| distinct names guessed | 785 | 100.0% |
| returned at least one concept | 785 | 100.0% |
| returned nothing |   0 | 0.0% |
| best hit scored >= 0.90 | 545 | 69.4% |
| best hit scored 0.75 - 0.90 | 213 | 27.1% |
| best hit scored < 0.75 |  27 | 3.4% |

## What kind of concept was chosen

The prompt asks the model to break ties by preferring a concept on the **LOINC
Top 2000+ (SI)** recommended list, and then one Finland already maps codes to.
A high share in neither bucket means the model is routinely landing on obscure
concepts, which is worth a look even when the concept is defensible.

| bucket | n | pct |
|---|---|---|
| mapped rows | 1599 | 100.0% |
| chose a LOINC Top 2000 concept |  746 | 46.7% |
| chose a concept already used in Finnish mappings | 1026 | 64.2% |
| chose one that is both |  563 | 35.2% |
| chose one that is neither |  390 | 24.4% |

## Most chosen concepts

The concepts the most local codes were mapped to. A concept collecting a very
large number of rows is worth checking: it may genuinely be the test that
recurs under many local spellings, or it may be where codes the model could
not tell apart ended up.

| omop_concept_id | omop_concept_name | n_rows | top2000 |
|---|---|---|---|
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 69 | yes |
| 3044889 | 12 lead EKG panel | 22 |  |
| 3009814 | Iron saturation [Molar fraction] in Serum or Plasma | 19 | yes |
| 3019897 | Erythrocyte [DistWidth] in Red Blood Cells by Automated count | 19 | yes |
| 3001802 | Microalbumin/Creatinine [Mass Ratio] in Urine | 18 | yes |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 18 | yes |
| 36660087 | Specimen Collection procedure comment | 18 |  |
| 40758558 | Short blood count panel - Blood | 18 |  |
| 36033641 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 16 |  |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 14 | yes |
| 3015399 | Transferrin receptor.soluble [Mass/volume] in Serum or Plasma | 13 |  |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 13 |  |
| 3021337 | Troponin I.cardiac [Mass/volume] in Serum or Plasma | 12 | yes |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 12 |  |
| 3026008 | Bacteria identified in Urine by Culture | 11 | yes |
| 3026910 | Gamma glutamyl transferase [Enzymatic activity/volume] in Serum or Plasma | 11 | yes |
| 3001784 | Prostate Specific Ag Free/Prostate specific Ag.total in Serum or Plasma |  9 | yes |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma |  9 | yes |
| 3014037 | CD3+CD4+ (T4 helper) cells/cells in Blood |  9 | yes |
| 3018251 | Fasting glucose [Moles/volume] in Serum or Plasma |  9 | yes |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA/FixLOINCDimensions/reflections.md`.

### Key findings

- The candidate lists frequently lack necessary LOINC concepts, which is the most common reason for being unable to map a code. This includes missing panel concepts (especially for toxicology, microbiology, and genetics), qualitative '[Presence]' concepts, concepts for specific specimen-analyte combinations, and generic concepts (e.g., 'total antibody') when only specific ones are offered.
- Successful mapping critically depends on combining multiple source data attributes, particularly specimen prefixes, units, `LongName` keywords, and the presence of decile values, which help distinguish between quantitative and qualitative tests, especially when units are missing.
- Strategic mapping decisions are necessary to handle ambiguity, such as preferring Top 2000 concepts or those with high pre-existing usage in Finland, selecting more general LOINC concepts for generic local codes, and occasionally mapping to a parent or superset concept as a 'best fit' approximation.
- A core task is distinguishing between different test types based on the data, such as quantitative vs. qualitative, absolute vs. relative counts, panels vs. single analytes, and timed vs. spot collections.
- Local data contains many synonyms and variations for the same test (e.g., 'S-', 'P-', 'fS-' prefixes for serum/plasma; multiple names for ACR or RDW), which must be collapsed into a single standard LOINC concept.

### Suggested improvements

- Enrich the candidate lists by adding missing panel concepts for toxicology, microbiology, and hematology; qualitative `[Presence]` concepts for common analytes; and concepts for specific but common tests that were frequently absent (e.g., Factor II gene analysis, lupus screen/confirm pairs, platelet function tests).
- Improve the candidate retrieval logic to ensure it fetches both generic and specific versions of a test (e.g., total antibody vs. IgG; generic panel vs. specific panel) and includes concepts for all relevant properties (e.g., Mass/volume, Moles/volume, and Presence) for an analyte.
- Provide clear guidelines on when it is acceptable to use a proxy mapping, such as to a less specific parent concept, a superset panel, or a concept with a similar but not identical specimen.
- Allow mappers to override incorrect source data flags, such as changing `is_panel` from false to true when the local data or LOINC concept indicates it is a panel.

### Systematic data problems

- Many local codes are unmappable because their names are ambiguous, cryptic, or overly truncated abbreviations with no clarifying `LongName` (e.g., 'p-fs', 'u-alvhu4a', 'hoikemseul').
- Source data contains numerous codes for administrative, billing, or pre-analytical procedural steps (e.g., 'specimen collection', 'frozen sample', 'billing package') that do not correspond to a LOINC laboratory observation.
- The source data has inconsistencies and errors, such as having quantitative decile values for a row with 100% missing values, reporting nonsensical quantitative units for qualitative tests, or having incorrect `is_panel` flags.
- Some local test names are too generic to allow for a precise mapping, such as not specifying an immunoglobulin class for an antibody test or not listing the components of a local panel.

