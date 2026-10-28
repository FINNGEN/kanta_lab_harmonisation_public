# 0_GetMeasurementOmopData

Pulls the OMOP reference data the mappings are checked against: every standard
`Measurement`-domain concept's LOINC axes (component, property, method, scale
type, system, time aspect), whether it is a panel, and which LOINC Groups it
belongs to. Independent of every other
step, which is why it runs first.

## Inputs

None from `DATA_MAPPINGS/`. This step pulls directly from the FinnGen OMOP CDM
vocabulary tables (`concept`, `concept_relationship`) via `FinnGenUtilsR`.

## Outputs

In `DATA_MAPPINGS/0_GetMeasurementOmopData/`:

- `measurement_concept_attributes.tsv` — one row per standard
  `Measurement`-domain concept:

| Column | Type | Description |
|---|---|---|
| concept_id | Integer | OMOP concept id |
| concept_code | Character | Concept code in its vocabulary |
| concept_name | Character | Concept name |
| vocabulary_id | Character | Vocabulary of the concept (e.g. `LOINC`, `SNOMED`) |
| is_panel | Logical | `TRUE` if the concept has any outgoing `Panel contains` relationship (it bundles several component tests, e.g. a metabolic panel) |
| has_component | Character | Analyte or substance measured (e.g. Glucose) |
| has_property | Character | Kind of quantity reported (e.g. Mass Concentration, Presence) |
| has_method | Character | Analytical method (e.g. Test strip, Immunoassay) |
| has_scale_type | Character | Result scale (`Qn`, `Ord`, `Nom`, `Nar`, `Doc`) |
| has_system | Character | Specimen or body system (e.g. Serum or Plasma, Urine) |
| has_time_aspect | Character | Timing of the collection (e.g. Point in time (spot), 24 hours) |

- `flowsheet_loinc_groups.tsv` — one row per (standard `Measurement` concept,
  Flowsheet Group it belongs to). Only the Groups whose name starts with
  `Flowsheet` are kept: `Flowsheet - laboratory` (6 Groups), `Flowsheet - vital
  signs` and `Flowsheet - weight, height, and head circumference`. A concept
  keeps **one** `Flowsheet - laboratory` Group, the most specific one (see
  [Why one Flowsheet rule per concept](#why-one-flowsheet-rule-per-concept)). It
  can still have two rows when it is in two categories: concepts `3023540` and
  `3025315` are in both the laboratory and the weight/height/head circumference
  Flowsheet Groups.

| Column | Type | Description |
|---|---|---|
| concept_id | Integer | OMOP concept id, joins to `measurement_concept_attributes.tsv` |
| group_concept_id | Integer | OMOP concept id of the LOINC Group |
| group_concept_code | Character | The `LG...` code of the Group |
| group_concept_name | Character | Name of the Group |
| n_descendants | Integer | How many standard `Measurement` concepts the Group holds |
| is_parent_group | Logical | `TRUE` if the Group subsumes other Groups, a grouping rule and not a value set (e.g. `LG100-4` "Flowsheet - laboratory") |

- `log.txt` — run log.

The six `has_*` columns are LOINC's 6 core axes, the same attributes Athena
(athena.ohdsi.org) shows on a concept's page. They let later steps check that a
mapped `concept_id` matches the intended analyte, specimen and result type.

## Action

`scripts/pullMeasurementConceptAttributes.R` queries the vocabulary schema for
every standard concept in the `Measurement` domain (any vocabulary except
`OMOP Genomic`, whose gene-variant concepts never carry the 6 core attributes):

1. Pulls the 6 core LOINC attribute relationships (`Has component`, `Has method`,
   `Has property`, `Has scale type`, `Has system`, `Has time aspect`) for every
   concept and pivots them into one column per relationship, using the *name* of
   the related concept, not its id.
2. Flags concepts with an outgoing `Panel contains` relationship as `is_panel`.
3. Joins these onto the base concept table and writes the result.

`scripts/pullLoincGroupMembership.R` queries the same schema for LOINC Group
membership: `concept_ancestor` rows whose ancestor is a
`concept_class_id = 'LOINC Group'` concept, scoped to the same domain, standard
flag and vocabulary exclusion, so both outputs join on `concept_id` without a
gap. It computes each Group's descendant count and flags the ParentGroups in the
same query. The query keeps every Group; the script then keeps only the Groups
whose name starts with `Flowsheet` (`groupNamePrefix`). Of the six
`Flowsheet - laboratory` ParentGroups a concept keeps the most specific one,
`LG78-8 > LG74-7 > LG97-8 > LG27-5 > LG99-4 > LG100-4`, and the script logs how
many rows each step leaves.

Taken from the CDM rather than from LOINC's GroupFile distribution because the
ancestor model answers the question *do these two concepts share a Group* as a
set intersection, needs no precedence rule, keys on `concept_id`, drops a
licensed file from the inputs, and stays on the same vocabulary release as every
other concept this step pulls. See `RESEARCH/UnderstandingGroups.md`.

## Why one Flowsheet rule per concept

The Groups kept here are ParentGroups: the *rules* that build the real value
sets, not sets of equivalent tests. The six ParentGroups of `Flowsheet -
laboratory` overlap, so a concept can sit in two of them. The notes below are
copied from `RESEARCH/UnderstandingGroups.md` (section 4), written when this was
decided on the LOINC GroupFile. The CDM data here gives slightly different counts
(it drops 195 `LG100-4` and 106 `LG97-8` rows, not 227 and 107), but the same
overlap pairs and the same rule.

### The six ParentGroups of `Flowsheet - laboratory`

| ParentGroupId | Groups | terms | name |
|---|---|---|---|
| `LG100-4` | 1,968 | 4,577 | `Chem_DrugTox_Chal_Sero_Allergy<SAME:Comp\|Prop\|Tm\|Syst (except intravascular and urine)><ANYBldSerPlas,ANYUrineUrineSed><ROLLUP:Method>` |
| `LG74-7` | 771 | 1,817 | `Urine<SAME:Comp\|Prop\|Sys><ROLLUP:Tm\|Meth>` |
| `LG99-4` | 377 | 1,574 | `IsolateSusc<SAME:Comp\|Sys><ROLLUP:Tm\|Prop\|Method>` |
| `LG97-8` | 99 | 547 | `UrineAndSed<SAME:Comp><Sys:ANYUrineUrineSed><ROLLUP:Tm\|Prop\|Method>` |
| `LG27-5` | 147 | 341 | `CellDiffCount<SAME:Comp\|Prop\|Tm\|Sys><ROLLUP:Meth>` |
| `LG78-8` | 5 | 29 | `UrineMicroalbumin<SAME:Comp\|Prop\|Sys><ROLLUP:Tm\|Meth>` |

**Flowsheet - laboratory and Reportable microbiology — local, enumerable
leakage.** Every overlapping code is in exactly 2 groups, and the colliding
pairs are the four listed below (urine PGs vs the chem PG) and the SARS-CoV-2
PGs vs the generic virus PG. These are the two Categories where a precedence
rule genuinely recovers a partition, because the overlap is 4% and 2% and the
colliding ParentGroups sit in a clear specific-to-general order.

For `Flowsheet - laboratory` the overlaps are narrow and fully enumerable:

```
223  Chem_DrugTox_Chal_Sero_Allergy  &  Urine
104  Urine                           &  UrineAndSed
  4  Chem_DrugTox_Chal_Sero_Allergy  &  UrineMicroalbumin
  3  UrineMicroalbumin               &  UrineAndSed
```

So it can be made a tree with a precedence rule — most specific wins:

```
LG78-8 (UrineMicroalbumin) > LG74-7 (Urine) > LG97-8 (UrineAndSed)
       > LG27-5 (CellDiffCount) > LG99-4 (IsolateSusc) > LG100-4 (Chem…)
```

Applying this yields a clean disjoint assignment: **8,644 codes -> 3,225
groups, exactly one each.** It drops 227 `LG100-4` memberships and 107 `LG97-8`
memberships; nothing else moves. (Visual walk-through of the collisions:
`RESEARCH/temp.md`.)

### Can you just drop the finer ParentGroup instead?

Tempting, because the `UrineAndSed` group often *contains* the `Urine` group —
e.g. `Yeast|PrThr|Urine` (3 terms) sits entirely inside `Yeast|Urine/Urine sed`
(10 terms). If that held generally, keeping only `LG97-8` and deleting `LG74-7`
would resolve the overlap for free. It does not hold, for two separate reasons.

**Reason 1 — containment is not the rule.** Relation between the two colliding
groups, for every one of the 334 overlapping codes:

| pair | n | coarse contains fine | identical | reversed | **partial — neither contains the other** |
|---|---|---|---|---|---|
| `LG100-4` & `LG74-7` | 223 | 141 (`LG100-4` in `LG74-7`) | 75 | 2 | **5** |
| `LG74-7` & `LG97-8` | 104 | 54 (the `Yeast` case) | 2 | 2 | **46** |
| `LG100-4` & `LG78-8` | 4 | 0 | 0 | 0 | **4** |
| `LG78-8` & `LG97-8` | 3 | 0 | 0 | 0 | **3** |

For the `Urine`/`UrineAndSed` pair only **54 of 104 (52%)** behave like `Yeast`;
44% are partial. Across all 334: 199 strict containment, 77 identical, **58
partial**.

Partial overlap happens because the two ParentGroups roll up *different axes*,
so neither is a refinement of the other:

- `LG74-7 Urine` = `SAME: Comp|Prop|Sys`, `ROLLUP: Tm|Meth` -> keeps the
  property, absorbs **timed collections**
- `LG97-8 UrineAndSed` = `SAME: Comp`, `ROLLUP: Tm|Prop|Meth`, system widened to
  urine **+ sediment**

```
 term                                               LG74-7            LG97-8
                                                 Protein·MCnc·Urine  Protein·Urine/sed
 ───────────────────────────────────────────────  ──────────────────  ────────────────
 2888-6    Protein [Mass/volume] in Urine               ███                ███   both
 35663-4   Protein [Mass/volume] in Urine unspec dur    ███                ███   both
 50561-0   Protein [Mass/volume] by Automated strip     ███                ███   both
 5804-0    Protein [Mass/volume] by Test strip          ███                ███   both
 12842-1   Protein [Mass/volume] in 12 hour Urine       ███                 ·    <- timed: LG97-8 excludes
 21482-5   Protein [Mass/volume] in 24 hour Urine       ███                 ·    <- timed: LG97-8 excludes
 26034-9   Protein [Mass/volume] in Urine (deprecated)  ███                 ·
 2887-8    Protein [Presence] in Urine                   ·                 ███   <- other property
 20454-5   Protein [Presence] in Urine by Test strip     ·                 ███   <- other property
 57735-3   Protein [Presence] by Automated test strip    ·                 ███   <- other property
 32209-9   Protein [Presence] in 24 hour Urine strip     ·                 ███   <- other property
 27298-9   Protein [Units/volume] in Urine               ·                 ███   <- other property
 32551-4   Protein [Mass] in Urine unspec duration       ·                 ███   <- other property
 18373-1   Protein [Mass/time] in 6 hour Urine           ·                 ███   <- other property
                                                 ──────────────────  ────────────────
                                                     7 terms            11 terms
                                                        4 shared, 3 + 7 exclusive
```

**Reason 2 — and this is the decisive one — coverage.** `LG97-8` was never built
to replace `LG74-7`; it is a small supplementary rollup for the handful of
analytes that appear in both urine and sediment:

```
LG74-7 Urine        1,817 codes
LG97-8 UrineAndSed    547 codes
                    ─────────
codes in LG74-7 with NO LG97-8 group at all:  1,713   <- lost if LG74-7 is deleted
codes in LG97-8 with no LG74-7 group:           443
```

**So reorder, do not delete.** If the goal is one bucket per urine analyte
regardless of how it was measured — the intuition the `Yeast` case triggers —
put `LG97-8` *first* in the precedence instead of removing `LG74-7`:

```
LG78-8  >  LG97-8  >  LG74-7  >  LG27-5  >  LG99-4  >  LG100-4
```

| | fine-first (`LG74-7` wins) | coarse-first (`LG97-8` wins) |
|---|---|---|
| codes | 8,644 | 8,644 |
| groups | 3,225 | **3,211** |
| codes in `LG97-8` | 440 | **544** |
| codes in `LG74-7` | 1,817 | 1,713 |
| singleton groups | 5 | 15 |

The 104 shared codes go to the coarse analyte bucket, and the 1,713 codes
`LG97-8` has never heard of still get their `LG74-7` group. Nothing is lost
either way — it is purely which rung of the ladder wins when both apply.


### References

- `RESEARCH/UnderstandingGroups.md` — the full analysis: the Group file
  structure, Category vs ParentGroup (section 2), which Categories overlap
  (section 4, copied above), why LOINC Groups cannot be the grouping backbone
  (section 5, only 49% of the approved codes are in any Group), and why the
  pipeline uses the CDM and not the GroupFile (section 9).
- `ARCHIVE/STEPS/0_GetMeasurementOmopData/README.md` — the earlier version of
  this step, with the reasons for taking the Groups from the CDM's
  `concept_ancestor`.
- `ARCHIVE/STEPS/6_EvaluateMapping/README.md` and
  `ARCHIVE/DATA_v4/6_EvaluateMapping/loincToOmopMappingStats.md` — how the Groups
  were used to score the mapping, and the earlier rule of reporting the most
  specific shared Group (fewest descendants).

## Env vars

- `FG_DATABASE_ENV` — which FinnGenUtilsR/database environment to connect to
  (e.g. `build`, `preview`); passed to `FinnGenUtilsR::fg_getDatabaseConnector()`.
  Set in the `ENVIRONMENTS/<ENV_NAME>.env` file selected by `--env`. That file's
  GCP variables are consumed internally by `FinnGenUtilsR` when it opens the
  connection.

## How to run

```
./STEPS/MAPPING/0_GetMeasurementOmopData/run.sh <PATH_TO_DATA_MAPPINGS> --env <ENV_NAME>
```
