# Understanding LOINC Groups

Source: `.scratchpad/Loinc_2.82/GroupFile/` (LOINC 2.82, Beta release).
Cross-checked against `DATA_v4/ReferenceMappings/lab_data_summary.csv` (`APPROVED`
rows only) and `DATA_v4/0_GetMeasurementOmopData/measurement_concept_attributes.tsv`.

## How the Group file is structured

Four levels, but only three are real tables:

```
Category  (label, lives only in GroupLoincTerms.csv)
  └─ ParentGroup   62 rows, ParentGroup.csv       — the grouping *rule*
       └─ Group    7,519 rows, Group.csv          — one value set
            └─ LoincNumber  43,813 memberships, GroupLoincTerms.csv
```

All 62 ParentGroups are `ACTIVE`. Of the 7,519 Groups, 7,445 are `Active`, 63
`Inactive` (0 or 1 member term) and 11 `Deprecated`.

## 1. Categories

17 values of `GroupLoincTerms.Category`:

| Category | memberships | ParentGroups |
|---|---|---|
| Radiology | 10,690 | 15 |
| Document groups | 10,435 | 3 |
| **Flowsheet - laboratory** | 8,885 | 6 |
| Reportable microbiology | 4,956 | 6 |
| **Mass-Molar conversion** | 4,706 | 1 |
| Drugs of abuse | 1,817 | 1 |
| Respiratory microbiology | 752 | 1 |
| Genitourinary microbiology | 450 | 1 |
| Social determinants of health | 276 | 1 |
| Smoking - history | 219 | 1 |
| Obstetrics | 215 | 4 |
| Exercise | 121 | 1 |
| `""` (empty) | 107 | 17 |
| Flowsheet - vital signs | 76 | 1 |
| Eye microbiology | 62 | 1 |
| Smoking - biochemical markers | 29 | 1 |
| Flowsheet - weight, height, and head circumference | 17 | 1 |

The empty category is 17 one-off ParentGroups for single analytes
(`C reactive protein|Pt|ANYBldSerPl`, `Creatinine|Pt|ANYBldSerPl|113.12 g/mole`,
`Fibrin D-dimer|Pt|ANYBldPPP`, `Glucose^1.5H post ANY challenge|Pt|ANYBldSerPl`, …)
— hand-built value sets that did not get a category label.

### The six ParentGroups of `Flowsheet - laboratory`

| ParentGroupId | Groups | terms | name |
|---|---|---|---|
| `LG100-4` | 1,968 | 4,577 | `Chem_DrugTox_Chal_Sero_Allergy<SAME:Comp\|Prop\|Tm\|Syst (except intravascular and urine)><ANYBldSerPlas,ANYUrineUrineSed><ROLLUP:Method>` |
| `LG74-7` | 771 | 1,817 | `Urine<SAME:Comp\|Prop\|Sys><ROLLUP:Tm\|Meth>` |
| `LG99-4` | 377 | 1,574 | `IsolateSusc<SAME:Comp\|Sys><ROLLUP:Tm\|Prop\|Method>` |
| `LG97-8` | 99 | 547 | `UrineAndSed<SAME:Comp><Sys:ANYUrineUrineSed><ROLLUP:Tm\|Prop\|Method>` |
| `LG27-5` | 147 | 341 | `CellDiffCount<SAME:Comp\|Prop\|Tm\|Sys><ROLLUP:Meth>` |
| `LG78-8` | 5 | 29 | `UrineMicroalbumin<SAME:Comp\|Prop\|Sys><ROLLUP:Tm\|Meth>` |

## 2. Category vs ParentGroup

They are different *kinds* of thing, not two levels of the same thing:

- **ParentGroup** is the **grouping rule**, encoded in its name:
  `Chem_DrugTox_Chal_Sero_Allergy<SAME:Comp|Prop|Tm|Syst><ANYBldSerPlas,ANYUrineUrineSed><ROLLUP:Method>`
  means *"one Group per (Component, Property, Time, System); roll up all Methods;
  treat all intravascular systems as one and all urine systems as one."* It is a
  machine-readable spec for how the LOINC axes get collapsed.
- **Category** is a **purpose label** attached to a set of ParentGroups — "what
  use case is this for".

The relation is a strict function: **ParentGroup → Category is many-to-one,
0 of 62 ParentGroups carry more than one Category.** So Category is a pure
roll-up of ParentGroups. Note that `Group.csv` does not carry it — it has to be
read from `GroupLoincTerms.csv`.

## 3. Tree or graph? — both, depending on the level

**Within a ParentGroup it is a clean tree.** Every `GroupId` has exactly one
`ParentGroupId` (0 of 7,519 exceptions), and checking every ParentGroup for a
LOINC code appearing in two of its own Groups: **all 62 are disjoint partitions
of their own member terms.** That is guaranteed by construction — the
ParentGroup name is a deterministic function of the LOINC axes.

**Across ParentGroups it is a graph.** 9,050 of the 31,418 LOINC codes in the
file sit in more than one Group. The same code gets sliced several ways for
several purposes.

## 4. Which Categories are non-overlapping trees?

**13 of 17 are disjoint**; 4 overlap:

| Category | overlapping codes | why |
|---|---|---|
| Document groups | 3,587 / 3,759 | 3 PGs slice DocOnt by Setting / TypeOfService / Role+SMD |
| Radiology | 3,336 / 7,256 | `RadRegion:*` PGs cross-cut the `Rad*<SAME:Meth…>` PGs |
| Reportable microbiology | 81 / 4,875 | SARS-CoV-2 PGs overlap the generic virus PG |
| **Flowsheet - laboratory** | **334 / 8,551** | urine PGs overlap the chem PG |

### Reading the "overlapping codes" column

Numerator = distinct LOINC codes in that Category that belong to **more than one
Group within the same Category**. Denominator = total distinct LOINC codes in
that Category.

Two things to watch:

- **The denominator is distinct codes, not memberships.** The §1 table counts
  rows of `GroupLoincTerms.csv`; this one counts unique `LoincNumber`s. The
  difference between the two is exactly the double-counting — Flowsheet -
  laboratory: 8,885 memberships − 8,551 codes = 334; Reportable microbiology:
  4,956 − 4,875 = 81.
- **Overlap is always between ParentGroups, never inside one.** All 62
  ParentGroups are internally disjoint (§3), so a Category can only overlap when
  it bundles two or more ParentGroups that index the same terms by different
  rules. That is why all 13 single-ParentGroup Categories are 0 — they cannot
  overlap by construction.

Degree distribution of the four that do overlap:

| Category | codes | in >1 group | in exactly 2 | in 3 | in 4+ |
|---|---|---|---|---|---|
| Flowsheet - laboratory | 8,551 | 334 (3.9%) | 334 | 0 | 0 |
| Reportable microbiology | 4,875 | 81 (1.7%) | 81 | 0 | 0 |
| Radiology | 7,256 | 3,336 (46%) | 3,263 | 55 | 18 |
| Document groups | 3,759 | 3,587 (95%) | 498 | 3,089 | 0 |

These are three structurally different situations.

**Document groups — three parallel complete indexes.** 3,089 of 3,759 codes sit
in *all three* ParentGroups. That is the design: `DocOnt<SAME:Setting>`,
`DocOnt<SAME:TypeOfService|KindOfDocument>` and `DocOnt<SAME:Role|SMD>` each
index the same document terms by a different axis. It is not a partition with
leakage, it is three complete views of one term set — picking "the" group for a
document code is meaningless, you pick the axis you want.

**Radiology — a rule index crossed with a body-region index, plus multi-region
studies.** The top overlapping ParentGroup pairs:

```
1133  RadRegion:LowerExtremity  +  RadExtremityWithFocus<SAME:Meth|ImagingFocus|Comp>
1054  RadRegion:UpperExtremity  +  RadExtremityWithFocus<SAME:Meth|ImagingFocus|Comp>
 282  RadRegion:Breast          +  RadBreast<SAME:Meth|ImagingFocus|Comp>
 177  RadRegion:Abdomen         +  RadRegion:Pelvis
 128  RadRegion:Head            +  RadRegion:Neck
 102  RadRegion:Abdomen         +  RadRegion:Chest
  83  RadRegion:Abdomen         +  RadKidney<SAME:Meth|Comp>
```

Two sources. The flat `RadRegion:*` body-region buckets cut across the
rule-based `Rad*<SAME:Meth|…>` ParentGroups (rows 1-3). Then `Abdomen+Pelvis`,
`Head+Neck`, `Abdomen+Chest` are studies that genuinely span two regions ("CT
Abdomen and Pelvis"), so even the region buckets overlap each other. The 55 + 18
codes at degree 3 and 4+ are multi-region studies that also carry a method-rule
group.

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

## 5. What to use for `lab_data_summary.csv` (APPROVED rows)

First, the number that governs everything else. The `APPROVED` rows carry
7,108 rows with a concept / **1,463 distinct LOINC codes**, and:

| | codes | |
|---|---|---|
| in ≥1 LOINC Group (any ParentGroup) | 716 | 48.9% |
| **in no Group at all** | **747** | **51.1%** |

Coverage by candidate selection:

| selection | codes covered | APPROVED rows |
|---|---|---|
| `LG100-4` (Chem…) alone | 345 (23.6%) | 2,929 / 7,070 |
| + `LG74-7` (Urine) | 417 (28.5%) | 3,225 |
| + `LG27-5` (CellDiffCount) | 444 (30.3%) | 3,553 |
| all 6 of Category `Flowsheet - laboratory` | 462 (31.6%) | 3,635 |
| + `LG55-6` (MassMolConc) | 592 (40.5%) | 4,386 |
| everything | 716 (48.9%) | 4,689 |

**So LOINC Groups cannot be the grouping backbone.** Half the `APPROVED` codes
are not in the file at all — the gap is concentrated in serology/allergy IgE
panels, CSF, stool, body fluids, bone marrow, titers and `Presence or Threshold`
qualitative tests:

| uncovered, by property | n | | uncovered, by system | n |
|---|---|---|---|---|
| Presence or Threshold | 127 | | Serum | 155 |
| Arbitrary Concentration | 109 | | Serum or Plasma | 103 |
| Mass Concentration | 72 | | XXX | 66 |
| Number Fraction | 56 | | Blood | 65 |
| `-` | 55 | | Cerebral spinal fluid | 55 |
| Presence or Identity | 54 | | Urine | 32 |

And where it does cover, the granularity is wrong for aggregation: those 462
`Flowsheet - laboratory` codes fall into **387 distinct Groups, 341 of them
singletons** (largest group: 6 terms, `Glucose|SCnc|Pt|ANYBldSerPl`).

### Use it where it actually earns its keep

**For unit harmonisation → `LG55-6` MassMolConc (Category `Mass-Molar conversion`).**
This is the one ParentGroup built for exactly the problem the `CONVERSION_FACTOR`
column solves: `<SAME:Comp|Tm|Sys|Meth><Prop:MCncORSCncORMSCnc>` — same analyte,
same specimen, mass vs molar vs mass-substance concentration in one group, with
the molecular weight carried in `GroupAttributes.csv` as
`MolecularWeightOfAnalyte`. It touches 234 groups in the `APPROVED` set, and
**14 of them bundle genuinely different concepts currently treated separately**:

```
Cholesterol|Pt|Ser/Plas|386.664 g/mole
    s-kol  [mg/ml]   Mass Concentration        Cholesterol [Mass/volume]
    p-kol  [mmol/l]  Substance Concentration   Cholesterol [Moles/volume]
Ethanol|Pt|Ser/Plas|46.07 g/mole
    s-etoh [g/l]     Mass Concentration        Ethanol [Mass/volume]
    p-etoh [mmol/l] / [promille]  Substance Concentration
Calcium|Pt|Ser/Plas|40.078 g/mole
    s-ca   [g/l]     Mass Concentration
    s-ca   [mmol/l]  Substance Concentration
```

That gives a vocabulary-sourced conversion factor instead of a hand-maintained
one. Highest-value use of this file for this repo.

**For "same test, different method" rollup → Category `Flowsheet - laboratory`
with the precedence rule in §4.** It collapses `Automated count` / `Microscopy` /
`Test strip` / `Refractometry` variants — one of the two main sources of
pipeline-vs-reference disagreement.

**Implemented** in `STEPS/6_EvaluateMapping`:
`scripts/buildLoincGroupIndex.R` flattens the three `Flowsheet` Categories into
one Group per LOINC code (precedence as in §4) and writes
`DATA/6_EvaluateMapping/loincGroupIndex.tsv`;
`scripts/summariseLoincToOmopMapping.R` then scores agreement at Group level
alongside the concept id. Point `LOINC_GROUP_FILE_DIR` at an unpacked GroupFile
to turn it on — the raw distribution stays out of `DATA/` (§7), only the derived
index is written there. Result on the current run:

| | codes | | events | |
|---|---|---|---|---|
| agrees on the concept id (exact) | 742 | 61.4% | 40,275,283 | 79.7% |
| agrees on the LOINC Group | **837** | **69.2%** | **41,359,188** | **81.9%** |
| — of which recovered by the Group | 95 | 7.9% | 1,083,905 | 2.1% |

Only 531 / 1,209 of the checked codes carry a Group on both sides, so 69.2% is a
floor, not a ceiling. The recovering splits `LG100-4` 63, `LG74-7` 18, `LG97-8`
8, `LG27-5` 6 — and the rows it recovers are exactly the specimen/method
decorations: `vp-ca-ion` (`Serum or Plasma` vs `Venous blood`), `p-ca19-9`
(methodless vs `by Immunoassay`), `u-sakka,eryt` (`Microscopy high power field`
vs `Automated count`).

**For a general taxonomy of the APPROVED set → do not use the Group file.**
Use `has_component` from
`DATA_v4/0_GetMeasurementOmopData/measurement_concept_attributes.tsv`: 1,015
distinct components over all 7,108 rows, 100% coverage, and it concentrates
where the data is (`C reactive protein` 197, `Hemoglobin` 130, `Observation`
127, `Leukocytes` 126, `Glucose` 116, `Lymphocytes/leukocytes` 92, `pH` 92).
Add `has_system` when specimen separation is needed. Then layer the LOINC
Groups on top as an *optional attribute* for the half of codes that have one.

## 6. Why half the reference codes have no group — it is not a version mismatch

The obvious suspicion is that `lab_data_summary.csv` was curated against a
different LOINC release than 2.82. Three tests say no.

### Age test

LOINC numeric prefixes are approximately chronological (higher = minted later).
If the uncovered codes were newer than 2.82 they would skew high. They skew
*low*:

| set | n | min | p25 | median | p75 | max |
|---|---|---|---|---|---|---|
| covered | 716 | 539 | 6,276 | 17,861 | 34,347 | 100,906 |
| **uncovered** | **747** | **533** | **13,316** | **30,385** | **55,936** | **100,898** |
| all GroupFile members | 31,418 | 1 | 25,426 | 42,386 | 80,773 | 112,423 |

The uncovered codes are *older* than the GroupFile's typical member (median
30,385 vs 42,386). Recently-minted codes (prefix >= 95000) are 0.7% of the
uncovered set and 0.8% of the covered set — indistinguishable. The oldest
uncovered codes are from LOINC's earliest releases:

```
533-0   Mycobacterium sp identified in Blood by Organism specific culture
543-9   Mycobacterium sp identified in Specimen by Organism specific culture
546-2   Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture
555-3   Candida sp identified in Specimen by Organism specific culture
562-9   Clostridioides difficile [Presence] in Stool by Organism specific culture
```

### Baseline test

The GroupFile contains 31,418 distinct LOINC codes against ~106,000 terms in
LOINC 2.82 — roughly **30% of LOINC overall**. Measured against the 68,106 LOINC
concepts in `measurement_concept_attributes.tsv`, only 18,539 (**27.2%**) appear
in the GroupFile.

So the reference set's 48.9% is nearly **double** the baseline. Its codes are
better covered than an average LOINC lab code, not worse.

### Vintage test — could the reference hold codes retired before 2.82?

LOINC 2.82 is the latest release, so any version skew must run the other way:
the reference could, in principle, carry a code that was valid in an older LOINC
and was retired before 2.82, which would survive in `lab_data_summary.csv` but
be absent from the GroupFile.

The skew is real, and it is OMOP that lags:

| | highest LOINC prefix | codes > 100000 |
|---|---|---|
| OMOP standard extract | 107,378 | 4,354 of 68,106 |
| GroupFile (LOINC 2.82) | 112,423 | 2,381 of 31,418 |

12,879 GroupFile codes (41%) are absent from the OMOP extract. That direction
only makes GroupFile codes missing from OMOP, never the reverse.

**That 41% is not LOINC churn** — it is almost entirely the `domainId =
Measurement` filter on the extract. Coverage by Category:

| Category | in GroupFile | in OMOP extract | |
|---|---|---|---|
| Flowsheet - laboratory | 8,551 | 7,705 | 90.1% |
| Reportable microbiology | 4,875 | 4,646 | 95.3% |
| Mass-Molar conversion | 4,706 | 4,296 | 91.3% |
| Drugs of abuse | 1,817 | 1,764 | 97.1% |
| Respiratory microbiology | 752 | 736 | 97.9% |
| Genitourinary microbiology | 450 | 429 | 95.3% |
| Obstetrics | 215 | 202 | 94.0% |
| Eye microbiology | 62 | 62 | 100.0% |
| **Radiology** | **7,256** | **81** | **1.1%** |
| **Document groups** | **3,759** | **1** | **0.0%** |
| Social determinants of health | 276 | 16 | 5.8% |
| Smoking - history | 219 | 0 | 0.0% |

Radiology orders, clinical documents, smoking questionnaires and SDOH surveys
are LOINC codes in other OMOP domains and were never pulled — **11,499 of the
12,879**. Of the remaining 1,380 lab-ish codes, 367 were minted after the newest
code in the OMOP snapshot (genuinely new in LOINC), and 1,013 exist in both but
are not standard `Measurement` concepts in OMOP. **In the lab space OMOP and
LOINC 2.82 agree on 90-100% of codes.**

And the retirement mechanism is ruled out by how the extract was built
(`STEPS/0_GetMeasurementOmopData`, `standardConceptFlag = S`): the attributes
table holds **only currently-standard concepts**, and OMOP demotes deprecated
LOINC codes to non-standard (`invalid_reason = 'D'`). All **1,488 of 1,488**
distinct `APPROVED` concept ids resolve in it — zero unresolved. Every reference
code is still standard today; none is a retired one. LOINC policy reinforces
this: codes are never deleted, only marked `DEPRECATED` and kept in the table.

One unrelated finding from the same check: **25 of the 1,488 `APPROVED`
concepts are SNOMED, not LOINC** — `Thrombophilia screening test`, `Lupus
anticoagulant assay`, `Bone marrow aspirate examination`, `Parainfluenza type
1/2/4 nucleic acid detection`, `Self-monitoring of blood glucose`, and others.
They can never appear in a LOINC group file by construction. They sit outside
the 1,463 LOINC codes so they do not contribute to the 747, but they matter if
the whole `APPROVED` set is ever grouped end to end.

### The two real reasons

**1. The project is deliberately partial.** 62 ParentGroups, each written for a
named use case. Microbiology has only `MicroResp`, `MicroGU` and `MicroEYE` —
there is no ParentGroup for blood, CSF, stool, skin or wound cultures, which is
where 41 of the uncovered codes live. Coagulation, cytology, molecular
pathology, titers and IgE allergen panels are largely absent too. Panels confirm
the scoping: 57 / 747 uncovered codes are panels, versus 5 / 716 covered.

**2. A Group needs at least 2 member terms to exist.** `GroupLoincTerms.csv`
contains zero groups of size 1 — the 63 `Inactive` Groups (0 or 1 term) and the
11 `Deprecated` ones are excluded from the terms file entirely. The smallest
real group has 2 terms, and 5,008 of the 7,445 live groups have exactly 2.

Consequently **539 of the 747 uncovered codes (72.2%) are the only LOINC in the
whole vocabulary with their (Component, Property, Time, System)** — there is no
sibling to roll a Method up with, so no Group is ever minted for them. The
comparable figure for covered codes is 50.6%, and those get picked up by the
cross-property `MassMolConc` rule instead.

The gap is structural. Re-downloading a newer LOINC release will not close it.

## 7. Stability — what is safe to depend on

Two different stability stories sit in this file, and they point to different
uses.

**LOINC codes are permanent.** They are never deleted and never reused. A term
that falls out of favour gets `STATUS = DEPRECATED` or `DISCOURAGED` and stays
in the table forever — which is why the entire `APPROVED` reference set still
resolves as a standard OMOP concept. As an identifier, a LOINC number is about
as stable as identifiers get. Safe as a join key: map to it, store it, compare
across years.

**What does move:**

- **Display names** are edited between releases — never key on
  `LongCommonName`.
- **Group membership is explicitly declared unstable.** From the GroupFile
  ReadMe: *"we intend to keep that logical definition stable in meaning over
  time. However, the members of the group may change as the underlying
  terminology (LOINC) evolves."* A Group is a value set regenerated from current
  LOINC content by a rule — new codes fall into it automatically, and a Group
  flips `Active` <-> `Inactive` as members come and go.
- **The Group project itself is Beta and incomplete.** Its ~30% coverage of
  LOINC is not version drift; it is 62 ParentGroups built so far for a handful
  of named use cases. LOINC states the groupings *"have not been vetted for use
  in either patient care or research and should be used with caution."*

**Practical rule for this repo:** treat LOINC Groups as a derived, regenerable
artifact. Pin the release used (2.82), re-derive on upgrade, and never persist a
`GroupId` as a key in pipeline output. Use Groups as a *lens* at analysis time —
"did the pipeline and the reference land in the same `MassMolConc` group?" — not
as part of the mapping identity. The mapping identity stays the OMOP concept id;
the taxonomy backbone stays `has_component` (§5).

## 8. Using the Mass-Molar conversion in FinnGen

Filtered from the full Group file to the groups whose `APPROVED` members span
**Mass Concentration <-> Substance Concentration** — a genuine unit conversion,
not a specimen or qualitative rollup. That is **15 groups / 14 distinct pairs**
(`Digoxin` appears in two groups with identical members). `n_events` is
`n_records` summed over the `APPROVED` rows pointing at that LOINC;
`n_events_group` is the group total.

All 15 belong to `MassMolConc` (`LG55-6`) except the duplicate
`Digoxin|Pt|ANYBldSerPl|780.9 g/mole`, which is its own one-off ParentGroup.

| group | MW | LOINC | loincName | property | units seen | n_events | n_events_group |
|---|---|---|---|---|---|---|---|
| `Cholesterol\|Pt\|Ser/Plas\|386.664 g/mole` | **386.664** | 2093-3 | Cholesterol [Mass/volume] in Serum or Plasma | Mass Conc | mg/ml | 9 | **2,073,565** |
|  |  | 14647-2 | Cholesterol [Moles/volume] in Serum or Plasma | Subst Conc | (none), mmol/l | 2,073,556 |  |
| `Calcium\|Pt\|Ser/Plas\|40.078 g/mole` | **40.078** | 17861-6 | Calcium [Mass/volume] in Serum or Plasma | Mass Conc | g/l | 8 | **520,975** |
|  |  | 2000-8 | Calcium [Moles/volume] in Serum or Plasma | Subst Conc | (none), mmol/l | 520,967 |  |
| `Parathyrin.intact\|Pt\|Ser/Plas` | — | 2731-8 | Parathyrin.intact [Mass/volume] in Serum or Plasma | Mass Conc | (none), ng/l | 136,886 | **167,377** |
|  |  | 14866-8 | Parathyrin.intact [Moles/volume] in Serum or Plasma | Subst Conc | pmol/l | 30,491 |  |
| `Choriogonadotropin.beta subunit.free\|Pt\|Ser/Plas` | — | 25373-2 | Choriogonadotropin.beta subunit free [Mass/volume] in Serum  | Mass Conc | (none), ug/l | 23,584 | **29,125** |
|  |  | 2115-4 | Choriogonadotropin.beta subunit free [Moles/volume] in Serum | Subst Conc | (none), pmol/l | 5,541 |  |
| `Digoxin\|Pt\|ANYBldSerPl\|780.9 g/mole` | 780.9 &#10033; | 10535-3 | Digoxin [Mass/volume] in Serum or Plasma | Mass Conc | ug/l | 652 | **25,993** |
|  |  | 14698-5 | Digoxin [Moles/volume] in Serum or Plasma | Subst Conc | (none), nmol/l | 25,341 |  |
| `Digoxin\|Pt\|Ser/Plas` | — | 10535-3 | Digoxin [Mass/volume] in Serum or Plasma | Mass Conc | ug/l | 652 | **25,993** |
|  |  | 14698-5 | Digoxin [Moles/volume] in Serum or Plasma | Subst Conc | (none), nmol/l | 25,341 |  |
| `Chromogranin A\|Pt\|Ser/Plas` | — | 9811-1 | Chromogranin A [Mass/volume] in Serum or Plasma | Mass Conc | ug/l | 11 | **16,765** |
|  |  | 25587-7 | Chromogranin A [Moles/volume] in Serum or Plasma | Subst Conc | (none), nmol/l | 16,754 |  |
| `Corticotropin\|Pt\|Plas\|4541.135 g/mole` | **4541.135** | 2141-0 | Corticotropin [Mass/volume] in Plasma | Mass Conc | ng/l | 10,000 | **10,007** |
|  |  | 14674-6 | Corticotropin [Moles/volume] in Plasma | Subst Conc | pmol/l | 7 |  |
| `Glucose\|Pt\|Urine\|180.156 g/mole` | **180.156** | 2350-7 | Glucose [Mass/volume] in Urine | Mass Conc | g/l | 18 | **8,250** |
|  |  | 15076-3 | Glucose [Moles/volume] in Urine | Subst Conc | (none), mmol/l | 8,232 |  |
| `Parathyrin related protein\|Pt\|Ser/Plas` | — | 2729-2 | Parathyrin related protein [Mass/volume] in Serum or Plasma | Mass Conc | (none), ng/l | 5,172 | **6,468** |
|  |  | 15087-0 | Parathyrin related protein [Moles/volume] in Serum or Plasma | Subst Conc | (none), pmol/l | 1,296 |  |
| `Ethanol\|Pt\|Ser/Plas\|46.07 g/mole` | **46.07** | 5643-2 | Ethanol [Mass/volume] in Serum or Plasma | Mass Conc | g/l | 134 | **6,410** |
|  |  | 14719-9 | Ethanol [Moles/volume] in Serum or Plasma | Subst Conc | mmol/l, promille | 6,276 |  |
| `Thiamine\|Pt\|Bld` | — | 2998-3 | Thiamine [Mass/volume] in Blood | Mass Conc | ug/l | 759 | **3,819** |
|  |  | 32554-8 | Thiamine [Moles/volume] in Blood | Subst Conc | nmol/l | 3,060 |  |
| `Theophylline\|Pt\|Ser/Plas` | — | 4049-3 | Theophylline [Mass/volume] in Serum or Plasma | Mass Conc | mg/l | 10 | **628** |
|  |  | 14915-3 | Theophylline [Moles/volume] in Serum or Plasma | Subst Conc | umol/l | 618 |  |
| `Risperidone\|Pt\|Ser/Plas` | — | 9393-0 | risperiDONE [Mass/volume] in Serum or Plasma | Mass Conc | ug/l | 12 | **401** |
|  |  | 39799-2 | risperiDONE [Moles/volume] in Serum or Plasma | Subst Conc | nmol/l | 389 |  |
| `Venlafaxine\|Pt\|Ser/Plas` | — | 9630-5 | Venlafaxine [Mass/volume] in Serum or Plasma | Mass Conc | ug/l | 12 | **367** |
|  |  | 34386-3 | Venlafaxine [Moles/volume] in Serum or Plasma | Subst Conc | nmol/l | 355 |  |

&#10033; `Digoxin|Pt|ANYBldSerPl|780.9 g/mole` carries the weight in its *group
name* but has no `MolecularWeightOfAnalyte` row in `GroupAttributes.csv`.

### Three things that matter for using this

**Only 5 of the 14 pairs ship a `MolecularWeightOfAnalyte` attribute** —
Cholesterol, Calcium, Corticotropin, Glucose (urine) and Ethanol. Digoxin has
780.9 g/mole in the group name only, so it has to be parsed out. The other 8
have no MW from LOINC at all. For the four proteins (`Parathyrin.intact`,
`Choriogonadotropin.beta subunit free`, `Chromogranin A`, `Parathyrin related
protein`) that is defensible — heterogeneous forms, no single molecular weight,
and clinically they are converted with assay-specific factors rather than
stoichiometry. For Thiamine, Theophylline, Risperidone and Venlafaxine it is
simply unpopulated; they have well-defined molecular weights that have to be
supplied locally.

**The volume is overwhelmingly one-sided**, which fixes the conversion
direction. Cholesterol: 2,073,556 molar against 9 mass. Calcium: 520,967
against 8. Corticotropin runs the other way — 10,000 mass (ng/l) against 7
molar. In practice this is folding a handful of stray rows into the dominant
concept, with ACTH the exception.

**`Parathyrin.intact` is the substantive find** — 136,886 events in `ng/l`
against 30,491 in `pmol/l`, both `APPROVED`, and no MW supplied. That is a
167,377-event harmonisation gap the reference carries today, and the largest in
this list by minority-side volume.

