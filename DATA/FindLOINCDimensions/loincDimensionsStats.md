# LOINC Dimensions -- Stats

Source: `DATA/FindLOINCDimensions/codesWithLoincDimensions.tsv`

Rows (local `TEST_NAME`/`UNIT` combinations): 1984
Similarity groups covered: 30

## Dimension completeness

How many rows the model could fill for each axis. An empty value means the
model judged the axis not determinable from that row — the prompt asks it to
leave an axis empty rather than guess, so empties are expected, not failures.

| dimension | n_filled | pct_filled | n_empty | pct_empty | n_unique |
|---|---|---|---|---|---|
| has_component | 1745 | 88.0% |  239 | 12.0% | 475 |
| has_property | 1624 | 81.9% |  360 | 18.1% |  41 |
| has_time_aspect | 1743 | 87.9% |  241 | 12.1% |   8 |
| has_system | 1635 | 82.4% |  349 | 17.6% |  48 |
| has_scale_type | 1780 | 89.7% |  204 | 10.3% |   7 |
| has_method |  623 | 31.4% | 1361 | 68.6% |  30 |
| is_panel | 1984 | 100.0% |    0 | 0.0% |   2 |

**Core axes filled per row** (of the 6 LOINC axes, excluding `is_panel`):

| n_axes | n_rows | pct_rows |
|---|---|---|
| 0 |   83 | 4.2% |
| 1 |   81 | 4.1% |
| 2 |   43 | 2.2% |
| 3 |   80 | 4.0% |
| 4 |  198 | 10.0% |
| 5 | 1043 | 52.6% |
| 6 |  456 | 23.0% |

## `has_component`

The analyte/substance measured — the core identity of the test.

- Filled: 1745 / 1984 (88.0%)
- Unique values: 475

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| C reactive protein | 82 | 4.7% |
| Bacteria | 40 | 2.3% |
| Bacteria identified | 40 | 2.3% |
| Glucose | 38 | 2.2% |
| Sodium | 36 | 2.1% |
| SARS-CoV-2 antigen | 24 | 1.4% |
| Amylase | 21 | 1.2% |
| EKG.12 lead | 21 | 1.2% |
| Erythrocyte distribution width | 21 | 1.2% |
| Albumin | 20 | 1.1% |

## `has_property`

The kind of quantity reported (`Substance Concentration`, `Mass Concentration`, `Presence or Threshold`, ...), independent of the unit.

- Filled: 1624 / 1984 (81.9%)
- Unique values: 41

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Presence or Threshold | 364 | 22.4% |
| Substance Concentration | 239 | 14.7% |
| Mass Concentration | 205 | 12.6% |
| Finding | 173 | 10.7% |
| Arbitrary Concentration | 113 | 7.0% |
| Catalytic Concentration | 108 | 6.7% |
| Presence or Identity | 106 | 6.5% |
| Number Concentration |  72 | 4.4% |
| Number Fraction |  71 | 4.4% |
| Ratio |  45 | 2.8% |

## `has_time_aspect`

The timing of the collection (`Point in time (spot)` for a spot sample, `24 hours` for a 24-hour collection, ...).

- Filled: 1743 / 1984 (87.9%)
- Unique values: 8

**Top 8 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Point in time (spot) | 1712 | 98.2% |
| 24 hours |   21 | 1.2% |
| Point in in time (spot) |    5 | 0.3% |
| 12 hours |    1 | 0.1% |
| 48 hours |    1 | 0.1% |
| Point in a time (spot) |    1 | 0.1% |
| Point in an (spot) |    1 | 0.1% |
| Point in an unspecified time |    1 | 0.1% |

## `has_system`

The specimen or body system the sample was taken from (`Serum or Plasma`, `Blood`, `Urine`, `Cerebral spinal fluid`, ...).

- Filled: 1635 / 1984 (82.4%)
- Unique values: 48

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Serum | 484 | 29.6% |
| Blood | 266 | 16.3% |
| Plasma | 225 | 13.8% |
| Urine | 207 | 12.7% |
| ^Patient | 103 | 6.3% |
| Lymphocyte |  37 | 2.3% |
| Bone marrow |  35 | 2.1% |
| Cerebral spinal fluid |  31 | 1.9% |
| Stool |  31 | 1.9% |
| Platelet poor plasma |  28 | 1.7% |

## `has_scale_type`

The measurement scale of the result (`Qn` quantitative, `Ord` ordinal, `Nom` nominal, `Nar` narrative, `Doc` document).

- Filled: 1780 / 1984 (89.7%)
- Unique values: 7

**Top 7 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Qn | 958 | 53.8% |
| Ord | 393 | 22.1% |
| Nar | 283 | 15.9% |
| Nom |  78 | 4.4% |
| Doc |  57 | 3.2% |
| SemiQn |   7 | 0.4% |
| OrdQn |   4 | 0.2% |

## `has_method`

The analytical method, populated only when the code indicates one that changes clinical interpretation. Mostly empty by design.

- Filled: 623 / 1984 (31.4%)
- Unique values: 30

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Nucleic acid amplification with probe detection | 106 | 17.0% |
| Flow cytometry (FC) | 101 | 16.2% |
| Automated count |  90 | 14.4% |
| Organism specific culture |  65 | 10.4% |
| Molecular genetics |  51 | 8.2% |
| Immunoassay |  47 | 7.5% |
| Electrophoresis |  34 | 5.5% |
| Test strip |  26 | 4.2% |
| Coagulation assay |  25 | 4.0% |
| Calculated |  15 | 2.4% |

## `is_panel`

Whether the code bundles several separately reported component tests rather than being one reportable result.

- Filled: 1984 / 1984 (100.0%)
- Unique values: 2

**Top 2 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| FALSE | 1800 | 90.7% |
| TRUE |  184 | 9.3% |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA/FindLOINCDimensions/reflections.md`.

### Key findings

- The 'deciles' column is critically important for inferring or confirming the property, scale, and specific component, especially when the test code is ambiguous or the unit is missing or incorrect.
- A common pattern is the dual representation of a test: one quantitative row (with units and deciles) paired with another row with a high percentage of missing values, representing qualitative, narrative, or non-numeric results for the same test.
- Source data frequently contains contradictory information across columns (e.g., a name suggesting a qualitative test but deciles indicating a quantitative one). The quantitative data (deciles, units) is generally more trustworthy than descriptive text.
- A recurring data quality issue is having a 100% 'p_missing' value alongside a full set of 'deciles'. The consensus strategy is to trust the deciles, infer a quantitative scale, and assume the missing percentage is an artifact.
- Identifying panels is a key judgment call. Strong indicators include explicit terms ('paketti', 'seulonta'), names combining multiple analytes, high 'p_missing' rates without deciles, and specific suffixes (e.g., '-is' for isoenzymes).
- Expert knowledge is required to infer standard methods (e.g., Electrophoresis, Immunoassay) and apply LOINC-specific conventions (e.g., 'Platelet poor plasma' for coagulation tests), which significantly improves mapping quality.
- Grouping similar test codes is essential for interpreting typos, truncated names, and using context from clear entries to resolve ambiguities in others.
- The 'LongName' column is invaluable for confirming components, resolving ambiguous abbreviations, and identifying panels or complex procedures.
- Specific Finnish terms (e.g., '-nho' for nucleic acid, 'vieritesti' for point-of-care, 'osatutkimus' for component test) are consistent and powerful clues for mapping multiple axes.
- Administrative, billing, and pre-analytical (e.g., sample collection) codes are often mixed in with analytical test codes and must be identified and handled differently.

### Suggested improvements

- Create a glossary documenting local, non-standard codes, including prefixes (e.g., 'ap-', 'res-'), suffixes (e.g., 'ctgc'), ambiguous abbreviations, and common Finnish medical terms ('vieritesti', 'seulonta').
- Provide the 'LongName' (official Finnish long name) for more rows to reduce ambiguity and confirm component mappings derived from abbreviated local codes.
- Improve the 'p_missing' data by providing guidance on how to handle contradictions with 'deciles', and by distinguishing between null values and non-numeric text results to better classify tests as narrative versus having missing data.
- Provide a sample of the non-numeric text values for rows with high 'p_missing' to help differentiate between true narrative results (e.g., 'No growth'), error messages ('Hemolyzed'), or other statuses.

### Systematic data problems

- System (specimen) information is frequently missing or ambiguous due to the absence of standard prefixes (e.g., 'S-', 'P-') or the use of undocumented local prefixes.
- Local test codes are often ambiguous, non-standard, truncated, or contain typos, making them difficult to map without contextual clues or documentation.
- Data fields often contradict each other, such as a test name suggesting a qualitative result while the unit and deciles are clearly quantitative, or a high 'p_missing' value co-occurring with deciles.
- Units of measurement are frequently incorrect (e.g., biologically impossible values), nonsensical (e.g., a mass unit for a qualitative test), or inconsistent, especially for serology tests with many arbitrary unit variants.
- Source data contains many non-analytical codes for administration, billing, sample handling ('frozen'), or location-specific logistics, which are mixed in with clinical test codes.
- Test names can be misleading, describing the purpose of a test (e.g., 'recirculation') rather than the quantity being measured (a concentration), leading to potential mapping errors.
- Messy, concatenated codes that combine multiple test names or results into a single string are common and can be misleading.

