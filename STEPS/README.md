# STEPS

The project has two areas. Each has its own steps and its own data folder.

| Area | Steps | Data | Purpose |
|---|---|---|---|
| [`MAPPING`](MAPPING/README.md) | Steps that modify the mapping tables | `DATA_MAPPINGS/` | Build and maintain the tables that map source lab codes and units to OMOP. |
| [`SUMMARY`](SUMMARY/README.md) | Steps that work on the summary of the real data | `DATA_SUMMARY/` | Build the summary of the real Kanta data, and later harmonize it with the mappings. |
