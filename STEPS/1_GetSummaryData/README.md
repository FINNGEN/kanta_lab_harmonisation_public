# 1_GetSummaryData

Turns the raw `source_kanta_summary` extract into one row per local
`TEST_NAME`/`UNIT`: how many records, what share came from a plain source
value vs. an injected/corrected unit or an extracted/QC-failed value, and
the observed value's deciles. This `labSummary.tsv` is the base table every
later step builds on.

## Inputs

- `DATA/source_kanta_summary/summaryTest.tsv` — one row per `TEST_NAME` +
  `MEASUREMENT_UNIT`, with `n_records` (see
  `DATA/source_kanta_summary/kanta_summary.md`).
- `DATA/source_kanta_summary/summaryUnitSource.tsv` (**optional**) — one row
  per `TEST_NAME` + `MEASUREMENT_UNIT` + `unit_source` (`Source` /
  `PrimaryInjection` / `SecondaryCorrection`), with `n_records`. Some
  `source_kanta_summary` vintages never had this table at all (e.g. one
  converted from the older v3 extract) — when it is missing,
  `unit_source_injection_correction_na_p` reads `[0,0,0,100]%` for every pair
  (100% "no unit_source recorded", which is exactly true).
- `DATA/source_kanta_summary/summaryValuesSource.tsv` — one row per
  `TEST_NAME` + `MEASUREMENT_UNIT` + `value_source` (`Source` / `Extracted` /
  `QCOut`), with `n_records`.
- `DATA/source_kanta_summary/summaryValues.tsv` — one row per `TEST_NAME` +
  `MEASUREMENT_UNIT` + `decile` (0.1 .. 0.9), with `decile_MEASUREMENT_VALUE`.

## Outputs

- `DATA/1_GetSummaryData/labSummary.tsv` — one row per `TEST_NAME`/`UNIT`:
  - `TEST_NAME`, `UNIT`.
  - `n` — total records (`summaryTest.tsv`'s `n_records`), the denominator
    every percentage below is taken against.
  - `unit_source_injection_correction_na_p` — `[source%,injection%,correction%,na%]`:
    the share of `n` recorded plainly as `Source`, via `PrimaryInjection`, via
    `SecondaryCorrection`, and via none of the three (no `unit_source`
    recorded at all for that many of the pair's records).
  - `value_missing_p` — the same `na` share as below, on its own: the percent
    of `n` with no `value_source` at all (no recorded, extracted, or
    QC-failed value).
  - `value_source_extracted_qcout_na_p` — `[source%,extracted%,qcout%,na%]`:
    the share of `n` recorded plainly as `Source`, via `Extracted`, via
    `QCOut`, and missing entirely (`value_missing_p` again).
  - `value_deciles` — `[d1, d2, ..., d9]`, the observed value's 9 deciles.
    Empty for the pairs `summaryValues.tsv` has no deciles for (the low-volume
    majority — see Action).
- `DATA/1_GetSummaryData/labSummaryStats.md` — stats on `labSummary.tsv` (see
  below).
- `DATA/1_GetSummaryData/log.txt` — run log.

## Action

`scripts/getSummaryData.R` joins the input tables on `TEST_NAME` + `UNIT`
(`summaryTest.tsv`'s `MEASUREMENT_UNIT`, renamed). `run.sh` checks for
`summaryUnitSource.tsv` itself and, if it is missing, warns and passes the
script no path for it at all — the script then treats it as a source with
zero rows rather than failing.

Before anything else, rows whose `TEST_NAME` is the literal text `NA` are
dropped, and the count and record total are logged as a warning — same
case-sensitive, exact match as `2_AppendKnownInformation`'s own filter
(lowercase `na` is a real code and survives). These are not a test: the
upstream extract renders a missing value as the text `NA` (R's `write.table`
default), so records with no test name at all arrive as a `TEST_NAME` of
`"NA"`, one row per `UNIT` they happened to be grouped into. They carry no
information that could be mapped to a lab test. (`2_AppendKnownInformation`
keeps its own copy of this filter too — belt and suspenders, since it reads
`labSummary.tsv` from whichever `source_kanta_summary` vintage produced it.)

Then:

1. Each of `summaryUnitSource.tsv` and `summaryValuesSource.tsv` is widened
   from one-row-per-label to one row per pair, with one column per label
   (`Source`, plus the two non-default labels each table carries). A pair
   entirely absent from one of these tables (no record of that kind at all)
   gets `0` in every one of its label columns after the join, not a dropped
   row.
2. The **na** bucket is computed the same way for both: `n` minus the sum of
   every labeled column. It is not read off a label in the source data —
   there is no explicit "missing" label there — it is what remains after
   every known label is subtracted from the pair's total record count.
3. Percentages are `100 * records / n`, rounded to 2 decimals and printed
   without trailing zeros (`30`, `5.05`, `0`, not `30.00`, `5.05000`,
   `0.00`) — the four numbers in `unit_source_injection_correction_na_p` /
   `value_source_extracted_qcout_na_p` sum to `100` (rounding aside).
4. `value_deciles` comes from pivoting `summaryValues.tsv`'s long
   `decile`/`decile_MEASUREMENT_VALUE` rows (ascending by `decile`) into one
   bracketed string per pair. Deciles are only computed upstream for
   higher-volume pairs (5,354 of 26,828 in the current
   `source_kanta_summary`); the rest are left empty.

`summaryValues.tsv` and `summaryValuesSource.tsv` are independent upstream
aggregates (their own `kanta_summary.md` documents each on its own), each with
its own low-volume suppression — so a handful of pairs carry a `value_deciles`
distribution despite `value_missing_p` reading 100. That is the source data,
not a computation bug here: it is not resolvable from these four tables alone.

Then `scripts/summariseLabSummaryStats.R` reads `labSummary.tsv` back and
writes `labSummaryStats.md`:

- **Overview** — pair counts (total, with `value_deciles`).
- **Name / unit / value coverage** — one row per combination of three
  yes/no facts about a pair (has a real `TEST_NAME`, i.e. not the upstream's
  stringified missing value `"NA"`; has a recorded `UNIT`; has `value_missing_p`
  under 100, i.e. at least one record with a value), each as `n rows` / `% rows`
  / `n records` / `% records`, plus a totals row. "Has a value" is independent
  of `value_deciles` — a pair can have real values but too few for the
  upstream decile computation, or (per the caveat above) the reverse.
- **Name / unit / deciles coverage** — the same table with `value_deciles`
  computed in place of "has a value". Deliberately kept separate rather than
  folded into one four-way table: the two are different facts (see above),
  and this table's `X`s are always a subset of the value-coverage table's.
- **Unit / value source composition** — the same four counts per
  `unit_source`/`value_source` bucket, recovered by parsing each bucket's
  share back out of its bracketed percentage string and multiplying by `n`
  (rounded, so counts are approximate near very small shares).

## Env vars

None required.

## How to run

```
./STEPS/1_GetSummaryData/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME>
```
