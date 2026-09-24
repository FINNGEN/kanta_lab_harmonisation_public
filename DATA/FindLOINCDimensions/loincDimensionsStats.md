# LOINC Dimensions -- Stats

Source: `DATA/FindLOINCDimensions/codesWithLoincDimensions.tsv`

Rows (local `TEST_NAME`/`UNIT` combinations): 3617
Similarity groups covered: 50

## Dimension completeness

How many rows the model could fill for each axis. An empty value means the
model judged the axis not determinable from that row — the prompt asks it to
leave an axis empty rather than guess, so empties are expected, not failures.

| dimension | n_filled | pct_filled | n_empty | pct_empty | n_unique |
|---|---|---|---|---|---|
| has_component | 3250 | 89.9% |  367 | 10.1% | 765 |
| has_property | 2745 | 75.9% |  872 | 24.1% |  49 |
| has_time_aspect | 3310 | 91.5% |  307 | 8.5% |   4 |
| has_system | 3010 | 83.2% |  607 | 16.8% |  89 |
| has_scale_type | 3213 | 88.8% |  404 | 11.2% |   5 |
| has_method |  840 | 23.2% | 2777 | 76.8% |  63 |
| is_panel | 3617 | 100.0% |    0 | 0.0% |   2 |

**Core axes filled per row** (of the 6 LOINC axes, excluding `is_panel`):

| n_axes | n_rows | pct_rows |
|---|---|---|
| 0 |   62 | 1.7% |
| 1 |  136 | 3.8% |
| 2 |  194 | 5.4% |
| 3 |  135 | 3.7% |
| 4 |  447 | 12.4% |
| 5 | 2207 | 61.0% |
| 6 |  436 | 12.1% |

## `has_component`

The analyte/substance measured — the core identity of the test.

- Filled: 3250 / 3617 (89.9%)
- Unique values: 765

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| C-reactive protein | 118 | 3.6% |
| Hemoglobin |  89 | 2.7% |
| Histology |  58 | 1.8% |
| Glomerular filtration rate/1.73 sq M.predicted |  49 | 1.5% |
| Lymphocytes |  45 | 1.4% |
| pH |  45 | 1.4% |
| Prothrombin time |  42 | 1.3% |
| Eosinophils |  40 | 1.2% |
| Albumin |  37 | 1.1% |
| Sodium |  37 | 1.1% |

## `has_property`

The kind of quantity reported (`MCnc` mass concentration, `SCnc` substance concentration, `PrThr` presence or threshold, ...), independent of the unit.

- Filled: 2745 / 3617 (75.9%)
- Unique values: 49

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| PrThr | 921 | 33.6% |
| MCnc | 416 | 15.2% |
| ACnc | 313 | 11.4% |
| SCnc | 269 | 9.8% |
| NFr |  84 | 3.1% |
| Prid |  80 | 2.9% |
| Find |  73 | 2.7% |
| CCnc |  65 | 2.4% |
| Ratio |  64 | 2.3% |
| Titr |  59 | 2.1% |

## `has_time_aspect`

The timing of the collection (`Pt` for a spot sample, `24H` for a 24-hour collection, ...).

- Filled: 3310 / 3617 (91.5%)
- Unique values: 4

**Top 4 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Pt | 3268 | 98.7% |
| 24H |   40 | 1.2% |
| 1H |    1 | 0.0% |
| 48H |    1 | 0.0% |

## `has_system`

The specimen or body system the sample was taken from (`Ser`, `Plas`, `Bld`, `Urine`, `CSF`, ...).

- Filled: 3010 / 3617 (83.2%)
- Unique values: 89

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Ser | 948 | 31.5% |
| Plas | 459 | 15.2% |
| Bld | 353 | 11.7% |
| Urine | 294 | 9.8% |
| ^Patient | 221 | 7.3% |
| Ser/Plas | 115 | 3.8% |
| Stool |  84 | 2.8% |
| RBC |  66 | 2.2% |
| CSF |  61 | 2.0% |
| Tiss |  54 | 1.8% |

## `has_scale_type`

The measurement scale of the result (`Qn` quantitative, `Ord` ordinal, `Nom` nominal, `Nar` narrative, `Doc` document).

- Filled: 3213 / 3617 (88.8%)
- Unique values: 5

**Top 5 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| Qn | 1646 | 51.2% |
| Ord |  987 | 30.7% |
| Nar |  417 | 13.0% |
| Nom |  102 | 3.2% |
| Doc |   61 | 1.9% |

## `has_method`

The analytical method, populated only when the code indicates one that changes clinical interpretation. Mostly empty by design.

- Filled: 840 / 3617 (23.2%)
- Unique values: 63

**Top 10 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| NAA | 147 | 17.5% |
| NAA+probe | 121 | 14.4% |
| NAA with probe detection |  84 | 10.0% |
| Test strip |  73 | 8.7% |
| Culture |  59 | 7.0% |
| Automated count |  44 | 5.2% |
| CKD-EPI formula |  34 | 4.0% |
| Complement fixation |  28 | 3.3% |
| EKG |  20 | 2.4% |
| Mass Spectrometry |  16 | 1.9% |

## `is_panel`

Whether the code bundles several separately reported component tests rather than being one reportable result.

- Filled: 3617 / 3617 (100.0%)
- Unique values: 2

**Top 2 most used values:**

| value | n | pct_of_filled |
|---|---|---|
| FALSE | 3287 | 90.9% |
| TRUE |  330 | 9.1% |

## Findings

Distilled by `gemini-2.5-pro` from the per-group reflections in `DATA/FindLOINCDimensions/reflections.md`.

### Key findings

- Distinguishing between quantitative and qualitative/ordinal tests is a primary task, reliably achieved by combining the `UNIT`, `p_missing`, and `deciles` columns. A present unit and/or numeric deciles indicates quantitative, while a missing unit and high `p_missing` indicates qualitative, narrative, or a panel code.
- Identifying panels versus single-analyte tests is a frequent and critical challenge requiring inference. Panels are identified by keywords (`paketti`, `seulonta`, `tutkimus`), plural nouns, `p_missing` of 100%, or domain knowledge about procedures like Spirometry, OGTT, and CBCs.
- Mapping requires significant domain and language knowledge, including Finnish medical vocabulary, microbiology (e.g., RNA vs. DNA viruses), immunology (e.g., IGRA structure), and clinical context (e.g., eGFR is always a `^Patient` system test).
- System (specimen) inference is a core task. The `prefix_meaning` column is the best source, but when absent, the system must be inferred from words in the `TEST_NAME` (e.g., `virtsasta`), sibling rows, or lab conventions. If no evidence exists, it is left blank.
- When data is contradictory, a clear hierarchy of trust is applied: `deciles` and `UNIT` are trusted over `p_missing` and sometimes even over `TEST_NAME` fragments or incorrect prefixes.
- The context provided by grouping similar codes is essential for decoding typos, abbreviations, and inconsistencies, and for inferring missing information like the specimen type.
- It is crucial to recognize and appropriately map codes that are not direct analytical results, such as orderable panels, procedures (ECG), clinical assessments (GDS-15), and administrative flags.
- The `Method` axis is often inferred from specific Finnish terms (`vieritesti`, `pikatesti`), explicit methods mentioned in the name (`immunofluoresenssi`), or the nature of the component (`fraction` implies `Electrophoresis`).

### Suggested improvements

- Provide the `LongName` (official full name) for all codes, as this is the single most effective way to resolve ambiguities from abbreviations, truncations, and uninformative local codes, especially for rows with high `p_missing`.
- Create and provide a dictionary of local terms, including common Finnish medical vocabulary, acronyms, abbreviations (`nho`, `-tutkimus`), and non-standard system prefixes (`ap`, `cp`, `vp`).
- Improve the quality and consistency of source data by populating `prefix_meaning` and `suffix_meaning` more reliably and resolving contradictions between columns, especially between `p_missing` and `deciles`.
- Provide clear documentation on how non-numeric results (e.g., 'Not detected', values below the limit of quantification) are represented in the data, to resolve ambiguity for quantitative tests with high `p_missing` rates.
- Formalize rules for identifying panel codes, for example by using a dedicated flag or a standardized list of keywords (`tutkimus`, `paketti`, `seulonta`), to make this key decision more systematic and less subjective.
- Consider a rule change to allow propagation of a confirmed System (e.g., `S-` for Serum) to other highly similar rows within the same group that lack a prefix, to improve completeness.
- Develop a more advanced parser for `TEST_NAME`s that can identify secondary clues for specimen type, such as embedded Finnish words (`plasmasta`) or national codes, when a standard prefix is missing.

### Systematic data problems

- System (specimen) information is the most common missing data point. The standard system prefix is often absent from the test code, forcing inference or resulting in information loss.
- Contradictory data within a single row is a frequent issue, most commonly `p_missing` being high or 100% while the `deciles` column is fully populated. Other examples include nonsensical units for a given test or a system prefix that conflicts with the test's biological nature.
- Test names (`TEST_NAME`) are highly inconsistent, vague, and messy. They contain numerous typos, non-standard abbreviations, truncations, and concatenated strings that mix panel, component, and qualifier information.
- The dataset contains many non-clinical or unmappable codes for administrative, billing, or logistical purposes, as well as completely opaque local abbreviations that cannot be mapped without a dictionary.
- The same local code is sometimes used for multiple distinct measurements (e.g., `E-MCV` for both mean cell volume and hematocrit), making the `TEST_NAME` an unreliable identifier on its own.
- It is often ambiguous whether a quantitative test with a high `p_missing` rate represents a true qualitative version of the test, a narrative result, or simply a data entry pattern for results below the limit of quantification.
- Provided metadata can be misleading. For instance, `prefix_meaning` can be biologically incorrect for the given component, or a `(kval)` suffix can appear on a clearly quantitative test.

