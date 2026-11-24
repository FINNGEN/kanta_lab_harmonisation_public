# 0_KantaAgregatedData

The input of the project, not a step: there is no `run.sh` or `scripts/` here.

The tables in `DATA/1_Input/0_KantaAgregatedData/` are copied in by hand from
the summary of the real Kanta data, produced on the secure environment by
[`kanta_lab_preprocessing`](https://github.com/FINNGEN/kanta_lab_preprocessing)
(`summarizePreprocessKantaData`). They hold only aggregates per `TEST_NAME` +
`MEASUREMENT_UNIT` pair (record counts, unit and value sources, value deciles,
small counts removed), never the real data. `kanta_summary.md` describes each
table.

The thresholds that go with these tables (the number of values and of subjects under which a pair counts as
having no values) are in `DATA/settings.yaml`, section `1_Input`, used by the whole repo.
