# MAPPING

Steps that modify the mapping tables. They read and write `DATA_MAPPINGS/`. Run
them in this order:

| Step | Purpose |
|---|---|
| `0_GetMeasurementOmopData` | Pull every standard OMOP `Measurement` concept with its LOINC axes. |
| `1_BuildHarmonizationTable` | Build the table that resolves each test and unit to its concept, target unit and conversion. |

`DATA_MAPPINGS/0_MappingTables` holds the tables the area starts from, not a step.
