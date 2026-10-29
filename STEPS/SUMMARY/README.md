# SUMMARY

Steps that work on the summary of the real Kanta data. They read and write
`DATA_SUMMARY/` (a step can also read `DATA_MAPPINGS/`, never write it), and never change the mappings. Run them in this order:

| Step | Purpose |
|---|---|
| `1_BuildKantaSummaryData` | Combine the Kanta summary tables into one long `KantaSummaryData` table. |
| `2_HarmonizeKantaSummaryData` | Join the harmonization table to `KantaSummaryData` and convert the decile values to the harmonised unit. |

`DATA_SUMMARY/0_KantaSummaryTables` is the input of the area (written outside
this repo), not a step.
