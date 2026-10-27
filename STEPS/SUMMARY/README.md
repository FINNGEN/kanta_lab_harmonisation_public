# SUMMARY

Steps that work on the summary of the real Kanta data. They read and write
`DATA_SUMMARY/`, and never change the mappings. Run them in this order:

| Step | Purpose |
|---|---|
| `1_BuildKantaSummaryData` | Combine the Kanta summary tables into one long `KantaSummaryData` table. |

`DATA_SUMMARY/0_KantaSummaryTables` is the input of the area (written outside
this repo), not a step.
