# 2a_FinnGenHarmonisedUnits

The input of the block, not a step: there is no `run.sh` or `scripts/` here.

`DATA/3_Target/2a_FinnGenHarmonisedUnits/conceptid_target_unit.tsv` is FinnGen's own
table of the unit each OMOP concept is harmonised to (`concept_id`,
`HARMONISED_UNIT`; 974 concepts), made by hand for the Kanta mapping and copied in
from the earlier version of this project. `2a_GetHarmonisedUnitFromLab2Clean` merges it with the
lab2clean units.
