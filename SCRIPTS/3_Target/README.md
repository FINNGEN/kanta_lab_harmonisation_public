# 3_Target

Steps that build the target the input is mapped into: the OMOP standard
`Measurement` concepts with their LOINC axes, LOINC Groups and harmonised units. They read and write `DATA/3_Target/`. Run them
in this order:

| Step | Purpose |
|---|---|
| `1_GetMeasurementOmopData` | Pull every standard OMOP `Measurement` concept with its LOINC axes. |
| `2_GetHarmonisedUnitFromLab2Clean` | Get the SI unit and the LOINC Group lab2clean gives to each concept; save the conventional-to-SI conversion table. |
| `3_GetLoincGroupsData` | Pull the LOINC Groups and which concepts are in each; conventional concepts go to the Groups of their SI partner. |
| `4_BuildTargetTable` | Join them into one table, one row per concept and Group, with the concept's harmonised unit (lab2clean, or none for a qualitative concept or a panel). |

`1_GetMeasurementOmopData` runs first: the report of `3_GetLoincGroupsData` reads its
table. 

The block is built only from the source data (OMOP, lab2clean): nothing in it is edited by hand. A
target unit that is missing or wrong is fixed in `2_Harmonisation/harmonisedUnitOverwrite.tsv`, which
`4_BuildHarmonisationTable` applies.

## How the LOINC Groups are built

A LOINC Group is a set of LOINC codes that LOINC considers the same test measured differently (usually
the same component, property and system, any method). Two Kanta tests mapped to concepts of one Group
are compared with each other in `5_EvaluateHarmonisedData`. Every Group is a LOINC Group (an `LG...`
code); what differs is who says which concept is in which Group. `targetTable.tsv` records it in
`group_source`.

### `lab2clean` Groups (`2_GetHarmonisedUnitFromLab2Clean`)

lab2clean's `loinc_reference_unit_v1` gives some LOINC codes a `property_group_id`, written
`<ParentGroup>/<Group>` (e.g. `LG100-4/LG51386-7`). `2` keeps the Group part and saves it in
`harmonisedGroup_lab2clean.tsv`.

- Only 3,881 of lab2clean's 33,197 codes have one, and each code has at most one Group.
- They come from four ParentGroups only: `LG100-4` (Chem, drugs, serology…), `LG74-7` (Urine), `LG27-5`
  (Cell differential counts) and `LG78-8` (Urine microalbumin).
- lab2clean picks one reference unit per Group: all the codes of a lab2clean Group share one unit (0 of
  1,701 Groups have more than one). `4_BuildTargetTable` checks it (an ERROR if not).

### `LOINC` Groups (`3_GetLoincGroupsData`)

lab2clean leaves most concepts without a Group, so `3` takes the Groups straight from the OMOP vocabulary:
every `LOINC Group` ancestor of each standard `Measurement` concept (`concept_ancestor`). Then:

1. It keeps only the concepts in a `Flowsheet` ParentGroup (lab tests, vital signs, weight and height).
2. It drops the ParentGroups themselves: they subsume other Groups and are grouping rules, not sets of
   equivalent tests (e.g. `LG100-4` "Flowsheet - laboratory").
3. It drops the panels: a panel is in no Group.
4. It drops the Groups of two ParentGroups:
   - `LG55-6` Mass-Molar conversion: each Group pairs a mass concept with its substance concept.
   - `LG97-8` UrineAndSed: it keeps only the component and rolls up the property and the system (urine
     and sediment), so a Group mixes cells per field (`/[HPF]`), per volume (`10*6/L`), mass and presence.
     lab2clean does not use it either.
5. A conventional concept takes the Groups of its SI partner (it is removed from the target anyway).
6. A concept keeps all its remaining Groups: "do two concepts share a Group" is a set intersection, so
   no precedence rule is needed.

### Joining them (`4_BuildTargetTable`)

Every membership of `3` is a row of `targetTable.tsv`. `group_source` is `lab2clean` when the
(concept, Group) pair is the one lab2clean gives the concept, else `LOINC`. Every lab2clean pair of a
concept kept in the target is also a membership of `3`, so no Group is lost. Today:

| group_source | concept-Group rows | Groups | concepts |
|---|---|---|---|
| `lab2clean` | 3,503 | 1,701 | 3,503 |
| `LOINC` | 4,001 | 1,234 | 3,643 |

(A Group can have rows of both sources: 2,899 Groups, 6,843 concepts in a Group.)

The `LOINC` memberships widen the Groups beyond lab2clean, but lab2clean's one-unit guarantee does not
cover them: 102 Groups mix units (a WARNING in `targetTable.md`). In `4_BuildHarmonisationTable` an
approved pair in a Group whose approved pairs have different target units gets
`ERROR:LoincGroupUnitsMissmatch`. The ones left are the `LG74-7` urine panel Groups, which hold a
collection volume (`mL`), a duration (`h`), concentrations and 24 h amounts.

### Choices considered

The overlap of the urine ParentGroups is studied in `ARCHIVE/development/RESEARCH/UnderstandingGroups.md`.
Two ways to stop `LG97-8` from mixing units in a Group were compared:

- **Precedence** (`LG78-8 > LG74-7 > LG97-8 > LG27-5 > LG99-4 > LG100-4`, one Group per concept): it
  moves the concepts that are also in an `LG74-7` Group out of `LG97-8`, but what stays in `LG97-8` still
  mixes `/[HPF]`, `/[LPF]`, `/min`, `10*9/L`; any new mapping to those concepts would bring the error back.
- **Drop `LG97-8`** (chosen): as lab2clean does. It removes 98 Groups; 15 mapped concepts (mostly
  sediment counts per field) are left in no Group and are compared with their own concept instead.
