# 3_Target

Steps that build the target the input is mapped into: the OMOP standard
`Measurement` concepts with their LOINC axes, LOINC Groups and harmonised units. They read and write `DATA/3_Target/`. Run them
in this order:

| Step | Purpose |
|---|---|
| `1_GetMeasurementOmopData` | Pull every standard OMOP `Measurement` concept with its LOINC axes. |
| `2a_GetHarmonisedUnitFromLab2Clean` | Get the SI unit lab2clean gives to each concept; save the conventional-to-SI conversion table. |
| `2b_HarmonisedUnitFixes` | The units set by hand for concepts lab2clean does not cover (a table, not a step). |
| `3_GetLoincGroupsData` | Pull the LOINC Groups and which concepts are in each; conventional concepts go to the Groups of their SI partner. Saves the conventional-to-SI conversion table. |
| `4_BuildTargetTable` | Join them into one table, one row per concept and Group, with the concept's harmonised unit (fix first, else lab2clean). |

`1_GetMeasurementOmopData` runs first: the report of `3_GetLoincGroupsData` reads its
table. 

`2a_FinnGenHarmonisedUnits` (`DATA/3_Target/2a_FinnGenHarmonisedUnits`) is an input copied in from
outside, kept for reference: no step reads it now. `2b_HarmonisedUnitFixes` is a hand-edited input.
