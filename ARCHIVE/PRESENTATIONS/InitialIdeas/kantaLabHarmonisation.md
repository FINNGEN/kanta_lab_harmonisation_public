---
marp: true
theme: default
paginate: true
header: 'Kanta lab harmonisation — local code → OMOP/LOINC'
footer: 'FinnGen · DATA_v4 · gemini-2.5-pro, 30 of 164 groups'
style: |
  section {
    font-size: 23px;
    padding: 50px 60px;
  }
  section.lead { text-align: center; }
  section.lead h1 { font-size: 54px; margin-bottom: 0.2em; }
  h1 { font-size: 36px; color: #1a3d5c; }
  h2 { font-size: 28px; color: #1a3d5c; margin-bottom: 0.3em; }
  section table { font-size: 17px; width: 100%; border-collapse: collapse; margin: 0 0 10px 0; }
  section th { background: #1a3d5c; color: #fff; font-weight: 600; }
  section td, section th { padding: 4px 8px; border: 1px solid #cfd8de; }
  section tr:nth-child(even) td { background: #f4f7f9; }
  section li { margin-bottom: 6px; }
  section p { margin: 8px 0; }
  .cols { display: flex; gap: 28px; }
  .cols > div { flex: 1; min-width: 0; }
  .cols table { font-size: 15px; }
  code { font-size: 0.9em; background: #eef2f5; padding: 1px 4px; }
  .msg {
    background: #eaf3ea; border-left: 5px solid #3c7a3c;
    padding: 10px 16px; margin-top: 14px; font-size: 21px;
  }
  .warn {
    background: #fdf1e7; border-left: 5px solid #c4761a;
    padding: 10px 16px; margin-top: 14px; font-size: 21px;
  }
  .small { font-size: 16px; color: #5a6b76; }
  header { font-size: 15px; color: #5a6b76; }
  footer { font-size: 14px; color: #8a98a3; }
---

<!-- _class: lead -->
<!-- _paginate: false -->

# Harmonising Kanta lab codes to OMOP

### From a local `TEST_NAME` + `UNIT` to a LOINC-backed OMOP concept

A six-step pipeline, an LLM that has to say *why*,
and an honest score against a hand-curated reference

---

# Input data: v3 → v4

Every `TEST_NAME`/`UNIT` pair against the three things it may carry:
a real name, a recorded unit, and at least one record with a value.

<div class="cols">
<div>

**v3**

| name | unit | value | n rows | % rows | n records | % rec |
|---|---|---|---|---|---|---|
| X | X | X | 8,606 | 32.3% | 179,527,254 | **69.8%** |
| X | X |  | 150 | 0.6% | 17,034 | 0.0% |
| X |  | X | 3,541 | 13.3% | 61,271,567 | 23.8% |
| X |  |  | 14,316 | 53.8% | 16,547,150 | 6.4% |
| total |  |  | 26,613 | 100% | 257,363,005 | 100% |

</div>
<div>

**v4**

| name | unit | value | n rows | % rows | n records | % rec |
|---|---|---|---|---|---|---|
| X | X | X | 8,745 | 32.6% | 212,508,947 | **82.4%** |
| X | X |  | 170 | 0.6% | 31,102 | 0.0% |
| X |  | X | 2,928 | 10.9% | 10,479,927 | 4.1% |
| X |  |  | 14,955 | 55.8% | 34,795,820 | 13.5% |
| total |  |  | 26,798 | 100% | 257,815,796 | 100% |

</div>
</div>

<p class="small">
<code>DATA_v3/1_GetSummaryData/labSummaryStats.md</code> ·
<code>DATA_v4/1_GetSummaryData/labSummaryStats.md</code>
</p>

---

# Input data: v3 → v4

<div class="msg">

**More records now carry a unit.** The share of records with name + unit + value
rises from **69.8% → 82.4%**, and the "value but no unit" bucket collapses from
23.8% to 4.1% of records.

The row counts barely move (26,613 → 26,798). What changed is not *which codes
exist* but *how much each code tells us about itself* — and the unit is the single
field that decides a measurement's quantity.

</div>

<div class="warn">

Still open: **55.8% of rows carry neither a unit nor a value** (13.5% of records).
Those rows are the hard part of everything that follows.

</div>

---

# Step 1 — The initial data

Five codes that will follow us through the whole deck.

| TEST_NAME | UNIT | n | value_missing_p | value_deciles |
|---|---|---|---|---|
| `p-na` | mmol/l | 7,320,578 | 0.03 | 134.0, 136.4, 138.0, 139, 139.9, 140, 141, 142, 143 |
| `p-na` | *(none)* | 81,059 | 100 | *(none)* |
| `u-gluk-o` | *(none)* | 658,060 | 100 | *(none)* |
| `ab-ca-ion` | mmol/l | 52,238 | 0 | 1.00, 1.04, 1.07, 1.10, 1.12, 1.14, 1.16, 1.18, 1.22 |
| `b-hba1c` | mmol/mol | 1,976,825 | 0 | 33.1, 35.1, 36.9, 38.4, 40.0, 42.0, 45.1, 50.3, 60.3 |

<div class="msg">

Note rows 1 and 2: **the same `TEST_NAME`, split by unit.** The pipeline maps
`(TEST_NAME, UNIT)` pairs, not names — because `p-na` in `mmol/l` and `p-na` with
no unit are not the same measurement as far as LOINC is concerned.

</div>

<p class="small">Source: <code>DATA_v4/1_GetSummaryData/labSummary.tsv</code> · 26,798 rows</p>

---

# Step 2 — Append what we already know

Before asking a model anything, attach every fact that already exists:
the official long name from **Koodistopalvelu**, and the meaning of the
**prefix** / **suffix** from the Finnish lab-code convention document.

| TEST_NAME | UNIT | LongName | prefix_meaning | suffix_meaning |
|---|---|---|---|---|
| `p-na` | mmol/l | P -Natrium | Plasma | Native preparation |
| `p-na` | *(none)* | P -Natrium | Plasma | Native preparation |
| `u-gluk-o` | *(none)* | U -Glukoosi (kval) | Urine | Qualitative test (also semi-quantitative) |
| `ab-ca-ion` | mmol/l | *(none)* | Arterial blood | Ionized |
| `b-hba1c` | mmol/mol | B -Hemoglobiini-A1c | Blood | *(none)* |

<div class="msg">

This is where most of the signal comes from. `u-gluk-o` has **no unit and no
values** — but `(kval)` in the long name and `-o` in the suffix dictionary say
*qualitative*, which is enough to fix the whole measurement.

</div>

<p class="small">Source: <code>DATA_v4/2_AppendKnownInformation/knownInformation.tsv</code></p>

---

# Step 3 — Group the codes by string similarity

Codes are clustered on string distance so that near-identical spellings of the
same test land in one prompt, and the model sees them side by side.

| step | value |
|---|---|
| Rows in | 26,798 |
| Minimum records to keep a row (`MIN_N`) | **100** |
| Maximum distinct `TEST_NAME` per group (`GROUP_SIZE`) | **100** |
| Rows out | 13,431 (9,211 distinct `TEST_NAME`) |
| Groups formed | **164** |
| Group size — mean / median / min / max | 56.2 / 57 / 1 / 100 names |

**Sanity check.** Mean within-group pairwise string distance over 20 sampled
groups: **10.18** for the distance-ordered groups vs **18.4** for groups formed by
alphabetical order. Lower is more similar — the clustering is doing real work.

<div class="msg">

From here on, **every count is over codes with ≥ 100 records**. Everything below
that floor is a long tail of one-off spellings that no amount of modelling fixes.

</div>

---

# Step 3 — Where our five codes landed

| TEST_NAME | UNIT | group_id | group_path |
|---|---|---|---|
| `p-na` | mmol/l | **42** | 2.1.1.2.1.2.1 |
| `p-na` | *(none)* | **42** | 2.1.1.2.1.2.1 |
| `u-gluk-o` | *(none)* | **79** | 2.1.2.2.2.1.1.2 |
| `ab-ca-ion` | mmol/l | **89** | 2.1.2.2.2.2.1.1.2.2.1 |
| `b-hba1c` | mmol/mol | **126** | 2.1.2.2.2.2.2.2.1.1 |

Both `p-na` rows sit in the same group, so the model sees the unit-bearing row and
the unit-less row **in one prompt** and can reason about them together.

<p class="small">
Source: <code>DATA_v4/3_GroupCodesByStringDistance/knownInformationGrouped.tsv</code> ·
the full dendrogram is in <code>knownInformationGroupedStats.md</code>
</p>

---

# Step 4 — Ask the model to name the LOINC

Each group goes to the LLM as one prompt. The model returns a **LOINC long common
name** per row — not a code — so it is writing a description, not recalling an
identifier it may hallucinate.

| TEST_NAME | UNIT | group | loinc_name_guess |
|---|---|---|---|
| `p-na` | mmol/l | 42 | Sodium [Moles/volume] in Plasma |
| `p-na` | *(none)* | 42 | Sodium [Moles/volume] in Plasma |
| `u-gluk-o` | *(none)* | 79 | Glucose [Presence] in Urine by Test strip |
| `ab-ca-ion` | mmol/l | 89 | Calcium.ionized [Moles/volume] in Arterial blood |
| `b-hba1c` | mmol/mol | 126 | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |

<div class="warn">

Both `p-na` rows get the **same** guess. This step names the *test*; it does not
yet decide whether the evidence is sufficient. That decision is step 5's.

</div>

<p class="small">
Example cached prompt:
<a href="../../DATA_v4/4_FindLOINC/groupsCache/42_prompt.md"><code>DATA_v4/4_FindLOINC/groupsCache/42_prompt.md</code></a>
· answer: <code>42.json</code> · 2,687 rows from 30 groups, USD 4.25
</p>

---

# Step 5 — Retrieve candidates, then ask again

The guessed name is run through **Hecate** (semantic search over the OMOP/LOINC
vocabulary). The model is then shown the real candidates and must pick one —
or decline.

Candidates for `Sodium [Moles/volume] in Plasma`:

| concept_id | concept_name | score |
|---|---|---|
| **3019550** | **Sodium [Moles/volume] in Serum or Plasma** | **0.934** |
| 3000285 | Sodium [Moles/volume] in Blood | 0.913 |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.909 |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.870 |

<div class="msg">

The model can only choose from concepts that **actually exist** in the vocabulary.
Seven independent chances to be wrong (one per LOINC axis) are replaced by one
choice from a real shortlist.

</div>

<p class="small">
1,083 distinct guessed names needed candidates · 20,295 cached candidate rows ·
example prompt:
<a href="../../DATA_v4/5_FixLOINC/groupsCache/42_prompt.md"><code>DATA_v4/5_FixLOINC/groupsCache/42_prompt.md</code></a>
</p>

---

# Step 5 — What it picked, and why

| TEST_NAME | UNIT | picked concept | certainty |
|---|---|---|---|
| `p-na` | mmol/l | Sodium [Moles/volume] in Serum or Plasma | high |
| `p-na` | *(none)* | *— declined —* | — |
| `u-gluk-o` | *(none)* | Glucose [Presence] in Urine by Test strip | high |
| `ab-ca-ion` | mmol/l | Calcium.ionized [Moles/volume] in Arterial blood | high |
| `b-hba1c` | mmol/mol | *— declined —* | — |

<div class="msg">

Two of the five are **declined on purpose**. An empty answer that says why is worth
more than a guess that cannot be checked.

</div>

---

# Step 5 — Every answer carries its reasoning

Clause by clause, so the decision — or the refusal — can be read rather than guessed at.

**`p-na [mmol/l]`** → *"Sodium bcs LongName 'Natrium' ; **[Moles/volume] bcs UNIT 'mmol/l' and value deciles [134..143]** ; in Serum or Plasma bcs prefix 'p-' (Plasma), for which S/P is the correct LOINC system."*

**`p-na []`** → *"**The property cannot be determined from the name alone.** Without a unit or values, the choice between different properties is ambiguous."*

**`u-gluk-o []`** → *"[Presence] bcs **LongName ends in '(kval)' and suffix is '-O'** ; in Urine bcs prefix is 'U-' ; by Test strip bcs this is the standard method for qualitative urine glucose."*

**`ab-ca-ion [mmol/l]`** → *"Calcium.ionized bcs 'ab-ca-ion' ; [Moles/volume] bcs unit mmol/l and values ~1.0-1.2 ; **in Arterial blood bcs prefix 'ab-'**."*

**`b-hba1c [mmol/mol]`** → *"Cannot map. **The concept for HbA1c in IFCC units (`mmol/mol`), which has a [Substance Ratio] property, is not in the candidate list.**"*

<div class="warn">

The last one is a **retrieval** failure, not a reasoning one — the model was right to
decline. Reasoning text is what makes that distinction visible at all.

</div>

---

# Step 6 — Results: the funnel

| step | n_codes | p_codes | n_events | p_events |
|---|---|---|---|---|
| total | 2,687 | 100.0% | 51,790,415 | 100.0% |
| has a guessed loinc | 2,577 | 95.9% | 51,567,886 | 99.6% |
| has a fixed loinc | 2,077 | 77.3% | 47,581,148 | 91.9% |
| exists in reference | 1,209 | 45.0% | 50,528,414 | 97.6% |
| agrees with reference (concept id) | 742 | 27.6% | 40,275,283 | **77.8%** |
| agrees with reference (LOINC Group) | 845 | 31.4% | 41,457,043 | **80.0%** |

<div class="msg">

Read the **events** column. The codes the reference covers are the codes that carry
the data: 45% of codes, but **97.6% of all records**. Agreement on **80% of
records** is the number that matters operationally.

</div>

<p class="small">
The reference (<code>DATA_v4/ReferenceMappings/lab_data_summary.csv</code>, <code>APPROVED</code> rows)
is the best mapping available, not ground truth — read these as <em>agreement</em>, not correctness.
</p>

---

# Step 6 — Results: by evidence level

| evidence_level | n_codes | n_ai_mapped | n_agree | n_agree_group | p_ai_mapped | p_agree | p_agree_group |
|---|---|---|---|---|---|---|---|
| name+unit+values | 590 | 570 | 428 | 485 | 96.6% | 75.1% | **85.1%** |
| name | 441 | 292 | 177 | 210 | **66.2%** | 60.6% | 71.9% |
| name+values | 138 | 136 | 107 | 114 | 98.6% | 78.7% | 83.8% |
| name+unit | 40 | 39 | 30 | 36 | 97.5% | 76.9% | 92.3% |
| total | 1,209 | 1,037 | 742 | 845 | 85.8% | 71.6% | **81.5%** |

<div class="warn">

**Message 1 — almost all the loss is name-only rows.** With a unit or values the
pipeline answers 97-99% of the time. With a name alone it answers **66.2%** — it
declines on purpose, because the unit is what fixes the *quantity*. `p-na [mmol/l]`
maps; the same `p-na` with no unit does not.

</div>

---

# Step 6 — Results: what the disagreements are

| level | n_codes | % of checked | n_events | % of events |
|---|---|---|---|---|
| agrees on the concept id (exact) | 742 | 61.4% | 40,275,283 | 79.7% |
| agrees on the LOINC Group | 845 | 69.9% | 41,457,043 | 82.0% |
| — of which recovered by the Group | **103** | 8.5% | 1,181,760 | 2.3% |

A **LOINC Group** is a value set of concepts that differ only in an axis the
Group's rule rolls up — method above all. Two concepts in one Group are the
same test measured differently. Membership is pulled from the OMOP vocabulary
(`concept_class_id = 'LOINC Group'`), and the test is whether the two concepts
**share** a Group.

<div class="warn">

**Message 2 — most disagreements are decoration, not the wrong analyte.** 103 of
the 295 disagreements are the same test with a different specimen or method
label. 90 of those share a Group with only 2-10 members, so the claim is tight.

</div>

---

# Step 6 — Results: disagreements that are really agreements

| TEST_NAME | ours | reference | shared Group | members |
|---|---|---|---|---|
| `ab-ca-ion` | Calcium.ionized … in **Arterial blood** | Calcium.ionized … in **Serum or Plasma** | Calcium.ionized \| Substance Concentration \| Moment in time \| Blood, Serum or Plasma | 8 |
| `u-ph-hy` | pH of Urine | pH of Urine **by Test strip** | pH \| Log Substance Concentration \| Urine | 8 |
| `b-neutrofiilit,…` | Neutrophils … **by Automated count** | Neutrophils … | Neutrophils \| Number Concentration (count/vol) \| Moment in time \| Blood | 3 |

<div class="msg">

`ab-ca-ion` is our running example: the pipeline reads the prefix `ab-` literally and
says **Arterial blood**; the reference uses the generic **Serum or Plasma**. Same
analyte, same property, same time — a specimen convention, not an error.

</div>

<p class="small">
Reported with the Group's member count so a weak rollup can be discounted rather
than taken on trust. Background: <code>RESEARCH/UnderstandingGroups.md</code>
</p>

---

# What is left

<div class="warn">

**Name-only rows.** 441 of 1,209 checked codes, and the pipeline declines on a
third of them. The reference maps them anyway by convention; the pipeline holds
out for evidence that will never arrive. This is a policy choice to revisit, not
a modelling failure.

</div>

<div class="warn">

**Retrieval gaps.** `b-hba1c [mmol/mol]` has 1.98M records, a unit, and values —
and still fails, because the IFCC `[Substance Ratio]` concept never appeared in
the shortlist. The model was right to decline. The search was wrong to omit it.

</div>

<div class="msg">

**Where the Group score cannot help.** Only 737 of 1,209 checked codes carry a
LOINC Group on both sides — about half the LOINC vocabulary has no Group at all
(coagulation, cytology, CSF have no grouping rule). 80.0% is a **floor**, not a
ceiling.

</div>

---

<!-- _class: lead -->
<!-- _paginate: false -->

# Summary

**80.0% of records** agree with the curated reference

Almost all remaining loss is **rows with no unit**,
and most remaining disagreement is **method/specimen decoration**

<p class="small">
Reproduce: <code>STEPS/0..6/run.sh &lt;DATA&gt; --env build</code> ·
full report: <code>DATA_v4/6_EvaluateMapping/loincToOmopMappingStats.md</code> ·
background: <code>RESEARCH/UnderstandingGroups.md</code>
</p>
