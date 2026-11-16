# 3_Target

Steps that build the target the input is mapped into: the OMOP standard
`Measurement` concepts with their LOINC axes and LOINC Groups, and the
harmonised unit of each Group. They read and write `DATA/3_Target/`. Run them
in this order:

| Step | Purpose |
|---|---|
| `0_GetMeasurementOmopData` | Pull every standard OMOP `Measurement` concept with its LOINC axes. |
| `0_GetLoincGroupsData` | Pull the LOINC Groups, which concepts are in each, and the harmonised unit of each Group (from lab2clean). |
| `1_BuildTargetTable` | Join them into one table, one row per concept and Group. |

`0_GetMeasurementOmopData` runs first: the report of `0_GetLoincGroupsData` reads its table. Neither needs any other step.
