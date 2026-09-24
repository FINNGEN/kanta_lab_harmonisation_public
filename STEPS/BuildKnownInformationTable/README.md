# BuildKnownInformationTable

## Inputs

- `DATA/getSummaryData/labSummary.tsv` — one row per `TEST_NAME`/`UNIT`, with
  `n`, `p_missing`, `deciles`.
- `DATA/SourceLabelingData/lab_codes_kodistopalvely.tsv` — the Kanta
  Kodistopalvelu lab code table, with `Abbreviation` and `LongName`.
- `DATA/SourceLabelingData/code_prefixes.tsv` — specimen/system prefix codes,
  with `id` and `prefix_meaning`.
- `DATA/SourceLabelingData/code_suffixes.tsv` — result-type/method suffix
  codes, with `id` (including the leading hyphen) and `suffix_meaning`.

## Outputs

- `DATA/BuildKnownInformationTable/knownInformation.tsv` — `labSummary.tsv`,
  minus the rows with no recorded test name (see Action), sorted by
  `TEST_NAME` ascending, with three columns appended:
  - `LongName` — from `lab_codes_kodistopalvely.tsv`, joined on
    `TEST_NAME = lowercase(Abbreviation)` with all spaces removed. `NA` when
    no `Abbreviation` normalizes to that `TEST_NAME`. A handful of normalized
    abbreviations collide with a different `LongName` (superseded codes); all
    are kept, joined with `"; "`.
  - `prefix_meaning` — the meaning of `TEST_NAME`'s leading 1- or 2-letter
    specimen/system code (`code_prefixes.tsv`), matched by requiring the
    prefix to be immediately followed by `-`. `NA` when `TEST_NAME` has no
    recognized prefix. `id` `fb` has two source rows (`fB` = fasting blood,
    `Fb` = foreign body — a genuine collision in the source, not a
    transcription error); both meanings are kept, joined with `"; "`.
  - `suffix_meaning` — the meaning of `TEST_NAME`'s trailing `-<suffix>`
    (`code_suffixes.tsv`), matched by requiring an exact match of the id
    (which includes its leading hyphen) at the end of `TEST_NAME`; the
    longest matching id wins. `NA` when `TEST_NAME` has no recognized suffix.
- `DATA/BuildKnownInformationTable/knownInformationStats.md` — stats on
  `knownInformation.tsv` (see below).
- `DATA/BuildKnownInformationTable/log.txt` — run log (written by `run.sh`'s
  `tee`; both R scripts log through `ParallelLogger::logInfo()` with no
  logger registered, per `development/STYLE.md`).

## Action

Before anything else, rows whose `TEST_NAME` is the literal text `NA` are
dropped, and the count is logged as a warning. These are not a test: the
upstream extract (`test_unit_counts.txt`) renders a missing value as the text
`NA` (R's `write.table` default), so records with no test name at all arrived
as a `TEST_NAME` of `"NA"`, one row per `UNIT` they were grouped into — 31 rows
spanning 31 unrelated units (`mmol/l`, `e9/l`, `fl`, `mm/h`, `ml/min/173m2`,
...) that belong to completely different assays, none of them carrying
deciles. They carry no information that could be mapped to a lab test.

The match is **case-sensitive and exact**: uppercase `NA` is the only uppercase
`TEST_NAME` in the dataset (every real code is lowercased), whereas lowercase
`na` is a real code with a genuine decile distribution and is kept. This is
also why the file is read with `na = ""` rather than readr's default
`c("", "NA")` — the default would destroy the real `na` too.

Then two scripts, run in order:

1. `scripts/buildKnownInformationTable.R` builds `knownInformation.tsv` as
   described above.
2. `scripts/summariseKnownInformationStats.R` reads `knownInformation.tsv`
   and writes `knownInformationStats.md`:
   - **Overview**, each table a plain `bucket`/`n`/`%` read with its own
     stated total, plus a short explanation of what it shows:
     - *Distinct TEST_NAME + UNIT* — one table: `total`; `with recorded data`
       (rows where `p_missing < 95.0`); `with deciles computed` (rows where
       `deciles` is not `NA`).
     - *Distinct TEST_NAME* — one row per `TEST_NAME`, with `n` summed across
       its `UNIT` rows. The same four buckets (`is number` — `TEST_NAME` is a
       bare digit code, never resolved to an abbreviation; `with long name`;
       `with prefix`; `with suffix`) are shown three times, once per
       event-volume tier — *All TEST_NAME*, *TEST_NAME with n_events > 100*,
       *TEST_NAME with n_events > 500* — each as its own table so `%` is
       always relative to that tier's own total (stated in its heading), not
       mixed across tiers in one row.
   - **Prefixes** — n distinct prefixes used, and a table of every
     `prefix_meaning` with the number of distinct `TEST_NAME` using it,
     sorted descending.
   - **Suffixes** — the same, for `suffix_meaning`.

## Env vars

None required.

## How to run

```
./STEPS/BuildKnownInformationTable/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME>
```
