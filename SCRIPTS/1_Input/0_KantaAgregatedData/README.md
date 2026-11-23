# 0_KantaAgregatedData

The input of the project, not a step: there is no `run.sh` or `scripts/` here.

The tables in `DATA/1_Input/0_KantaAgregatedData/` are copied in by hand from
the summary of the real Kanta data, produced on the secure environment by
[`kanta_lab_preprocessing`](https://github.com/FINNGEN/kanta_lab_preprocessing)
(`summarizePreprocessKantaData`). They hold only aggregates per `TEST_NAME` +
`PREPROCESED_UNIT` pair (record counts, unit and value sources, value deciles,
small counts removed), never the real data. `kanta_summary.md` describes each
table.

`upstreamSettings.yaml` holds the settings that go with these tables, written by hand and used by the
whole repo instead of hard-coded values:

| Key | Value | Meaning |
|---|---|---|
| `n_records_no_value_threshold` | `1000` | A pair with fewer non-missing values than this is considered as having no values. |
| `n_subjects_no_value_threshold` | `60` | A pair with fewer subjects than this is considered as having no values. |

`1_BuildKantaAgregatedTable` requires deciles only for a pair at or above both; `5_EvaluateHarmonisedData` and
`6_BuildDashboard` count a pair under either as "No value".
