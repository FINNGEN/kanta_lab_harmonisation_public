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
| has_component | 1722 | 86.8% |  262 | 13.2% | 469 |
| has_property | 1558 | 78.5% |  426 | 21.5% |  44 |
| has_time_aspect | 1635 | 82.4% |  349 | 17.6% |  11 |
| has_system | 1639 | 82.6% |  345 | 17.4% |  51 |
| has_scale_type | 1634 | 82.4% |  350 | 17.6% |   7 |
| has_method |  709 | 35.7% | 1275 | 64.3% |  39 |
| is_panel | 1981 | 99.8% |    3 | 0.2% |   2 |

**Core axes filled per row** (of the 6 LOINC axes, excluding `is_panel`):

| n_axes | n_rows | pct_rows |
|---|---|---|
| 0 |  44 | 2.2% |
| 1 | 151 | 7.6% |
| 2 |  79 | 4.0% |
| 3 | 124 | 6.2% |
| 4 | 203 | 10.2% |
| 5 | 894 | 45.1% |
| 6 | 489 | 24.6% |

## `has_component`

The analyte/substance measured — the core identity of the test.

- Filled: 1722 / 1984 (86.8%)
- Unique values: 469

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| C reactive protein | 88 | 5.1% |
| Bacteria | 70 | 4.1% |
| Glucose | 38 | 2.2% |
| Sodium | 36 | 2.1% |
| SARS-CoV-2 antigen | 25 | 1.5% |
| EKG study | 22 | 1.3% |
| Albumin | 21 | 1.2% |
| Amylase | 21 | 1.2% |
| Specimen collection procedure | 20 | 1.2% |
| Albumin/Creatinine | 19 | 1.1% |

## `has_property`

The kind of quantity reported (`Substance Concentration`, `Mass Concentration`, `Presence or Threshold`, ...), independent of the unit.

- Filled: 1558 / 1984 (78.5%)
- Unique values: 44

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Presence or Threshold | 270 | 17.3% |
| Substance Concentration | 210 | 13.5% |
| Mass Concentration | 183 | 11.7% |
| Finding | 174 | 11.2% |
| Presence or Identity | 130 | 8.3% |
| Arbitrary Concentration | 114 | 7.3% |
| Catalytic Concentration | 111 | 7.1% |
| Number Concentration |  82 | 5.3% |
| Ratio |  57 | 3.7% |
| Number Fraction |  56 | 3.6% |

## `has_time_aspect`

The timing of the collection (`Point in time (spot)` for a spot sample, `24 hours` for a 24-hour collection, ...).

- Filled: 1635 / 1984 (82.4%)
- Unique values: 11

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Point in time (spot) | 1575 | 96.3% |
| 24 hours |   21 | 1.3% |
| Study |   21 | 1.3% |
| Night time |    8 | 0.5% |
| Point in in time (spot) |    2 | 0.1% |
| Procedure duration |    2 | 0.1% |
| Reporting Period |    2 | 0.1% |
| 12 hours |    1 | 0.1% |
| 48 hours |    1 | 0.1% |
| Point in a time (spot) |    1 | 0.1% |

## `has_system`

The specimen or body system the sample was taken from (`Serum or Plasma`, `Blood`, `Urine`, `Cerebral spinal fluid`, ...).

- Filled: 1639 / 1984 (82.6%)
- Unique values: 51

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Serum | 471 | 28.7% |
| Blood | 276 | 16.8% |
| Plasma | 270 | 16.5% |
| Urine | 218 | 13.3% |
| ^Patient |  82 | 5.0% |
| Bone marrow |  37 | 2.3% |
| Lymphocytes |  37 | 2.3% |
| Stool |  34 | 2.1% |
| Cerebral spinal fluid |  31 | 1.9% |
| Serum or Plasma |  16 | 1.0% |

## `has_scale_type`

The measurement scale of the result (`Qn` quantitative, `Ord` ordinal, `Nom` nominal, `Nar` narrative, `Doc` document).

- Filled: 1634 / 1984 (82.4%)
- Unique values: 7

**Top 7 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Qn | 891 | 54.5% |
| Ord | 286 | 17.5% |
| Nar | 226 | 13.8% |
| Nom | 145 | 8.9% |
| Doc |  50 | 3.1% |
| SemiQn |  25 | 1.5% |
| OrdQn |  11 | 0.7% |

## `has_method`

The analytical method, populated only when the code indicates one that changes clinical interpretation. Mostly empty by design.

- Filled: 709 / 1984 (35.7%)
- Unique values: 39

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Immunoassay | 127 | 17.9% |
| Nucleic acid amplification with probe detection | 110 | 15.5% |
| Automated count |  73 | 10.3% |
| Molecular genetics |  50 | 7.1% |
| Rapid immunoassay |  49 | 6.9% |
| Organism specific culture |  38 | 5.4% |
| Culture |  36 | 5.1% |
| Test strip |  36 | 5.1% |
| Electrophoresis |  29 | 4.1% |
| Calculated |  25 | 3.5% |

## `is_panel`

Whether the code bundles several separately reported component tests rather than being one reportable result.

- Filled: 1981 / 1984 (99.8%)
- Unique values: 2

**Top 2 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| FALSE | 1763 | 89.0% |
| TRUE |  218 | 11.0% |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA/FindLOINCDimensions/reflections.md`.

### Key findings

- A very common pattern is a pair of local codes for the same analyte: one quantitative (with units and numeric results) and one qualitative or narrative (no unit, high `p_missing`), likely representing numeric results vs. non-numeric comments, order codes, or cancellations.
- Identifying panels is a primary task requiring recognition of diverse local conventions, including explicit keywords (`paketti`, `seula`), multi-analyte abbreviations (`p-k+na`, `amfet,bents...`), and generic procedure names (`täydellinenverenkuva`).
- The `deciles` and `UNIT` columns are crucial for disambiguating ambiguous components, especially for distinguishing individual components that are reported under a generic panel code (e.g., identifying Hemoglobin from a `B-PVK` blood count code based on its `g/l` unit and typical values).
- Local test names frequently contain explicit clues for other LOINC axes, such as the Method (`nukl.haponos.`, `viljely`, `pika`), System (`nielusta`, `Pt-`), and Time Aspect (`dU-`, `24h`).
- A significant portion of codes represent administrative actions (`lisämaksu`, `pakaste`) or procedures (`näytteenotto`, `kuljetus`), not lab measurements. These are identifiable by Finnish keywords and a universal lack of numeric data.
- Differentiating between absolute hematology counts (e.g., in `E9/L`, System: Blood) and relative fractions (in `%`, System: White Blood Cells) is a key task, often signaled by different local prefixes (`B-` vs `L-`) and units.
- The Finnish term `osatutkimus` ('component study') consistently indicates that a code represents a single component result, not a panel, which is a crucial localism to understand.

### Suggested improvements

- Provide the official `LongName` from the national codebook for all local codes. This is the most critical improvement, needed to resolve abbreviations, confirm component identity, and validate mappings for panels and obscure codes.
- Create and maintain a glossary of local and non-standard prefixes (e.g., `cp-`, `aP-`, `fE-`), suffixes (e.g., `-nho`), and terminology (`vieritesti`, `osatutk`) to improve mapping accuracy and consistency.
- Establish clearer guidelines for handling ambiguous or non-standard specimen information, for example, when to generalize a specific source (e.g., arterial plasma) to its parent specimen (Plasma) vs. its collection site (Blood arterial).
- For resolving definitive conflicts between a test's name and its numeric data (e.g., a ratio test reported in `mmol/l`), provide access to a sample of the original raw result strings.

### Systematic data problems

- A very common data quality issue is a contradiction where a code has `p_missing=100%` but also has a complete `deciles` distribution, making the `p_missing` field unreliable for determining if a test is quantitative.
- A large number of codes lack a standard specimen prefix (e.g., `S-`, `P-`) or use an ambiguous placeholder (e.g., a leading hyphen `-`), preventing the mapping of the crucial `has_system` axis.
- Test names frequently conflict with their associated quantitative data. Examples include names implying 'qualitative' for tests with `mg/l` units, or names implying 'ratio' for tests with `mmol/l` units and value ranges.
- The source data contains widespread typos, inconsistent abbreviations for the same analyte, and obscure local codes that are unmappable without external context or an official `LongName`.
- Evidence of 'code collision' exists, where a single local code is misused for multiple different tests, or results for panel components are stored under the main panel order code, creating nonsensical data combinations.
- Many codes have incorrect units (e.g., wrong order of magnitude), uninformative units (e.g., `1`, `form`), or ambiguous units (`%`) that prevent accurate component or property identification.
- Some codes exhibit bimodal value distributions, suggesting that results from two different underlying tests or units have been merged, making a single valid mapping impossible.

