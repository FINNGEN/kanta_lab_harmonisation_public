[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

**Those guesses exist only to fetch the candidate list. They have already done their job, and they carry no authority over your decision.** The earlier pass was told to write a name whenever the code gave it anything at all to work with, because a near-miss still retrieves the right neighbourhood of concepts while silence retrieves nothing. So a guess may be a careful reading or a shot in the dark, and nothing marks which. Use it as a pointer to where in the vocabulary to look, never as an answer to confirm. **Decide from the row's own `TEST_NAME`, `LongName`, `UNIT` and `value_deciles`.** When the row's evidence and the guess disagree, the row wins.

Your task: for each row, decide **which real OMOP concept the code actually maps to**, choosing from a list of genuine LOINC concepts retrieved for this group, and return that concept's `omop_concept_id`.

You are the step that turns a plausible-sounding name into a real, usable identifier. Nothing downstream can tell a confidently wrong concept id from a correct one, so an id you are not willing to defend is worse than no id at all.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen the sample came from, mostly from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `E` = erythrocyte, `L` = leukocyte.
- The **test abbreviation** is a mnemonic of the test's long Finnish name, occasionally an established international one (`CRP`, `TSH`).
- The optional **suffix** qualifies the result type or method: `-O` (qualitative/semi-quantitative), `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture), `-Nh` (nucleic acid), `-Ion` (ionized), `-V` (free/unconjugated).

Finnish compounds run together: "transferriininrautakyllästeisyys" = transferrin iron saturation.

# What you are given

**The candidate table** — real OMOP LOINC concepts, found by running every guessed name in this group through a semantic search over the LOINC vocabulary and pooling the results. The candidates are pooled and deduplicated **across the whole group**, so a concept retrieved by one row's guess is offered to every row: sibling codes in a group are near-identical strings, and the right concept for one row is often the one another row's guess found. Columns:

- `omop_concept_id` — the id to return. Copy it digit for digit.
- `omop_concept_name` — the concept's real LOINC Long Common Name, as OMOP spells it today.
- `score` — how semantically close this concept was to the closest guess in the group, 0 to 1. **A high score only means the guess and the concept read alike.** The guess itself may have been wrong, so a 0.95 candidate for a misread code is a confident route to the wrong concept. Treat `score` as "the search found this", never as "this is correct".
- `top2000` — the concept's rank in the **LOINC Top 2000+ Lab Observations (SI edition)**: the ~2000 codes Regenstrief publishes as the recommended mapping targets, covering ~99.8% of the test volume of three large laboratory organisations. The SI edition is the relevant one here, since Finland reports in molar/SI units. Empty means the concept is not on the list.

**The rows table** — one row per local lab test/unit combination:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty, and may be wrong.
- `unit_share` — what percentage of this `TEST_NAME`'s records carry this row's `UNIT`.
- `n` — number of records.
- `value_missing_p` — percentage (0-100) of records with no numeric value.
- `value_deciles` — the 9 deciles of observed values, when available.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess, which is what the search was run on. A search query, not a hypothesis you owe any deference to: it was written under instructions to guess rather than stay silent, so its confidence is not calibrated and a fluent name may rest on very little. When it is a panel name, the earlier pass judged the code to order a bundle rather than report one result — check that against the code yourself.

# How to read the evidence

A row is one **`TEST_NAME` + `UNIT`** combination, and that pair is what you are naming. Two rows of the same code with different units are two different observations and may well belong to two different LOINC concepts. Decide each row on its own.

**The name is the source of truth.** `prefix_meaning` and `suffix_meaning` were derived from the `TEST_NAME` string by an earlier step, so when a name is misspelled, truncated or locally invented, the decoded prefix and suffix are wrong in exactly the same way. Treat them as extra information that can confirm what the name says — never as something that outranks it. The specimen in particular is often spelled out as a Finnish word rather than carried by a prefix: `veri` = blood, `seerumi` = serum, `plasma` = plasma, `virtsa` = urine, `likvori` = cerebrospinal fluid, `uloste` = feces, `sylki` = saliva. `c-reaktiivinenproteiini,pikatesti,veri` names blood and has no decoded prefix at all — and its leading `c-` is the start of "C-reactive", not a specimen code.

**Missing values are not evidence.** `value_missing_p` describes this extract, not the laboratory test: a row with no values is a row where the numbers were not recorded or not carried through. Never conclude "no numbers, therefore qualitative". A test is qualitative when the CODE says so — the `-O` suffix, a `LongName` naming a qualitative or screening test, a component only ever reported as detected/not-detected.

**Never borrow from another row.** The rows are grouped by string similarity of `TEST_NAME`, so a group is a bag of codes that merely look alike. A neighbouring row's unit is not evidence about this row, and the same code can also appear in another group carrying units you cannot see here — so the units visible around you are not the units this code uses. Do not take a unit, a quantity or an answer from a sibling row, not even from a row whose `TEST_NAME` is identical.

**What you may conclude depends on what the row actually has.** The `evidence_level` column states it. Every row has a name; the label says what is there *in addition*:

| `evidence_level` | what the row has | what you may do |
|---|---|---|
| `name+unit+values` | a unit and a value distribution | The strongest case. If the values contradict the unit, distrust the **unit** — units are typed by hand at hundreds of source systems and are often wrong, especially at a low `unit_share` — and decide as if the unit were absent. |
| `name+unit` | a unit, no values | Trust the unit. It is the only quantity evidence there is, and it is usually right. |
| `name+values` | values, no unit | Read the quantity off the magnitudes. Creatinine at 60-110 is µmol/l and takes `[Moles/volume]`; the same analyte at 0.6-1.2 is mg/dl and takes `[Mass/volume]`. |
| `name` | neither | **You cannot fix the quantity.** Do not guess one and do not copy a sibling. Choose a concept only when the name alone settles it — a panel, which carries no property at all, or an analyte that has exactly one LOINC form. Otherwise **leave `omop_concept_id` empty**. An honest gap is worth more than a concept resting on nothing. |

**Some units are ratios, not concentrations.** `mmol/mol` is HbA1c IFCC, a substance ratio. `mg/mmol` is an albumin/creatinine ratio. `ml/min/173m2` is eGFR, a rate per body surface area. `%` is ambiguous by nature: it may be a fraction of a cell population, a fraction of a total mass, or activity as a percentage of normal.

**A repeated lowest decile is a detection limit, not a measurement.** When the first deciles are the same round number — `[5, 5, 6.2, 8.3, ...]` — the assay is censored at that floor and everything below was reported as "<5". Read the floor as the assay's sensitivity rather than the population's real low end: a CRP censored at 5 mg/l is an ordinary CRP, while a high-sensitivity assay reads down to about 0.1 mg/l, so that floor argues *against* a high-sensitivity concept.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `value_deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
2. **Pick the candidate that matches that reading**, and return its `omop_concept_id`. The unit and the values decide between candidates that differ only in property: `mmol/l` takes `[Moles/volume]`, `g/l` takes `[Mass/volume]`, `U/l` takes `[Enzymatic activity/volume]`. The specimen comes from the name — a decoded prefix where there is one, a Finnish specimen word otherwise; LOINC's `Serum or Plasma` is the right term for most routine chemistry, and fasting is not part of the specimen (`fS` is still serum).
3. **Precision must be earned by the name.** LOINC holds both a plain and a qualified concept for most tests. Take the **more precise** candidate whenever the row's name positively states the qualifier — `-Vi` really does say culture, `pikatesti` really does say a rapid test, `dU` really does say a 24-hour collection, `herkka` really does say high sensitivity. Take the plainer candidate when the name does not state it.

   The error to avoid is **inventing** a qualifier, not being specific. Measured against the curated Finnish mappings, this step added a method the reference leaves blank 59 times (usually `Automated count` on a bare blood-count code), took `--trough` variants for plain drug levels, and narrowed `Serum or Plasma` to `Capillary blood` on codes that said no such thing. Of every qualifier you are about to accept, ask: **which characters of this code say so?** If you cannot point at them, take the plainer concept.
4. **A guess that is itself a real concept is weak evidence, never an instruction.** If `loinc_name_guess` appears in the candidate table as an exact name at a score of 1.000, the earlier pass — reading this same row — happened to write the exact name of a concept that exists. That is mildly reassuring and nothing more: the earlier pass writes a name for almost every code it can read anything out of, so landing on a real name can be recognition or coincidence. Never adopt a candidate *because* it equals the guess. Take a different candidate, including a more precise one, whenever the row's own name, unit and values support it better — and take none at all if none fits, however well the guess matched.
5. **When two or more candidates still fit equally well**, prefer a candidate with a `top2000` rank. That list is LOINC's own recommendation for what laboratories should map to, so a concept on it is the intended target and a near-duplicate off it usually is not. It breaks ties and nothing more: a top-2000 concept in the wrong specimen or the wrong units is still the wrong answer.
6. **Leave `omop_concept_id` empty when no candidate is right.** That is a correct, useful answer — it says "this code has no match in what the search returned", which is a fact the next iteration can act on. Common reasons: the code is too truncated or garbled to identify; it is a local administrative or non-laboratory code; or the search simply did not return the concept you know is right.
7. **Never return an id that is not in the candidate table.** Not one you remember, not one you derive from a LOINC code, not a plausible-looking number. Ids that are not in the table are discarded and the row is logged as unanswered, so inventing one only loses the row.

Specific things to watch:

- **A panel is not its components.** If the code orders a bundle, the answer is a panel concept, not one of the bundled analytes: `B-PVK` (perusverenkuva, the basic blood count) and `B-TVK` (taydellinen verenkuva, the complete count with differential) are panels, not hemoglobin. Match the panel's breadth to the code: a basic count is not the same concept as a count with a differential. Conversely, do not map a single reported result to a panel concept just because a panel candidate scored well.
- **Deprecated near-duplicates are already filtered out** of the candidate list — every candidate is a standard, current concept — so you never need to judge validity, only fit.
- **The group is a bag of look-alike codes, not a set of equivalent ones.** It was built by string similarity, so it mixes genuinely different tests whose names happen to resemble each other. Answer every row from its own name, unit and values; never give rows one id because they sit together.
- **A row whose guess was empty can still be mapped** — the pooled list may hold the concept its own name points to. Map it on that row's own evidence, though, never because a neighbouring row was mapped there.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `omop_concept_id` — the chosen concept's id, copied from the candidate table. Empty if no candidate is right.
- `omop_concept_name` — that candidate's `omop_concept_name`, copied verbatim. Used only to cross-check that the id you copied is the concept you meant; leave it empty when the id is empty.

Then justify and grade what you chose:

- `reasoning` — why each part of the name you chose is right, as **one clause per part, separated by ` ; `**. Each clause names the part and then the evidence it rests on, pointing at the specific characters of the row that carry it. Cover the component, the bracketed property, the specimen, and the method when the name has one. Keep it terse — this is a justification trail, not prose:

      <component> bcs <evidence> ; <[property]> bcs <evidence> ; in <system> bcs <evidence> ; by <method> bcs <evidence>

  Where a part rests on nothing in the row, say that instead of inventing a reason — "no specimen stated in the code" is a useful thing for a reader to find here.

  **When you choose no concept, `reasoning` still matters — it is the only thing you leave behind.** Say what blocked you, specifically: the code is too garbled to identify; it is not a laboratory test; the search returned nothing for this analyte; the candidates were all the wrong specimen; the evidence cannot settle the quantity. "Nothing fitted" is not an answer. A reader must be able to tell a code that is unidentifiable from one the search simply failed on, because those need opposite fixes.
- `certainty` — `high`, `medium` or `low`: how sure you are, on all the evidence together, that this concept is the right one for this row. Weigh the parts by what a wrong answer would cost: a doubtful analyte makes the mapping useless, while an unstated method is a smaller error. A row whose `evidence_level` is `name` should rarely be `high`, since nothing fixes its quantity. Use `low` freely — these are read downstream to decide which mappings can be trusted without review, so a `high` you cannot defend is worse than an honest `low`. Leave it empty when you chose no concept.

Return an entry for EVERY row, including ones you leave unmapped.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which rows you could map and which you could not, where the candidate list was missing the concept you knew was right, where the earlier pass's guess sent the search astray, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 105.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 44816655 | Soluble fms-like tyrosine kinase-1/placental growth factor [Ratio] in Serum | 0.962 |  |
| 1259807 | Pepsinogen I/Pepsinogen II [Mass Ratio] in Serum | 0.960 |  |
| 3005578 | Mitotane [Mass/volume] in Serum or Plasma | 0.956 |  |
| 3007452 | Citrate [Moles/volume] in Serum or Plasma | 0.955 |  |
| 43055442 | Apixaban [Mass/volume] in Serum or Plasma | 0.953 |  |
| 43055458 | Rivaroxaban [Mass/volume] in Serum or Plasma | 0.950 |  |
| 3021347 | Calcium.ionized [Moles/volume] in Serum or Plasma | 0.947 | 182 |
| 3014576 | Chloride [Moles/volume] in Serum or Plasma | 0.941 | 8 |
| 3021119 | Calcium.ionized [Moles/volume] in Blood | 0.939 | 130 |
| 3014111 | Lactate [Moles/volume] in Serum or Plasma | 0.938 | 346 |
| 3023103 | Potassium [Moles/volume] in Serum or Plasma | 0.938 | 3 |
| 3019550 | Sodium [Moles/volume] in Serum or Plasma | 0.934 | 5 |
| 3005491 | Lactate [Moles/volume] in Plasma venous | 0.932 | 1070 |
| 3005456 | Potassium [Moles/volume] in Blood | 0.927 | 106 |
| 3020410 | Lactate [Moles/volume] in Arterial plasma | 0.925 |  |
| 1092155 | Tau protein.phosphorylated 217 [Mass/volume] in Serum or Plasma by Immunoassay | 0.920 |  |
| 3047181 | Lactate [Moles/volume] in Blood | 0.919 | 475 |
| 3031847 | von Willebrand factor (vWf) Ag [Units/volume] in Platelet poor plasma | 0.918 |  |
| 3018572 | Chloride [Moles/volume] in Blood | 0.918 | 295 |
| 3000285 | Sodium [Moles/volume] in Blood | 0.913 | 129 |
| 46235078 | Potassium [Moles/volume] in Serum, Plasma or Blood | 0.912 |  |
| 46235784 | Sodium [Moles/volume] in Serum, Plasma or Blood | 0.909 |  |
| 3035279 | Calcium.ionized [Moles/volume] in Capillary blood | 0.906 |  |
| 3044331 | Calcium.ionized [Moles/volume] in Arterial blood | 0.905 |  |
| 44786873 | Apixaban [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.903 |  |
| 46235783 | Chloride [Moles/volume] in Serum, Plasma or Blood | 0.903 |  |
| 3033705 | Calcium.ionized [Moles/volume] in Venous blood | 0.894 |  |
| 3029431 | Calcium.ionized [Moles/volume] in Body fluid | 0.894 |  |
| 44786870 | Rivaroxaban [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.892 |  |
| 3016431 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Serum or Plasma | 0.887 |  |
| 3048816 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Blood | 0.886 |  |
| 3002124 | von Willebrand factor (vWf) Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.884 | 1520 |
| 3041354 | Potassium [Moles/volume] in Venous blood | 0.882 |  |
| 3043409 | Potassium [Moles/volume] in Arterial blood | 0.879 |  |
| 3028271 | Lactate [Moles/volume] in Capillary blood | 0.877 |  |
| 3015774 | Calcium.ionized [Moles/volume] in Serum or Plasma by calculation | 0.876 |  |
| 3004825 | Lactate [Moles/volume] in Body fluid | 0.874 |  |
| 3037553 | Citrate [Mass/volume] in Serum or Plasma | 0.873 |  |
| 3041473 | Sodium [Moles/volume] in Venous blood | 0.870 |  |
| 3041671 | Calcium.ionized [Moles/volume] adjusted to pH 7.4 in Venous blood | 0.870 |  |
| 44816654 | Soluble fms-like tyrosine kinase-1 [Mass/volume] in Serum | 0.870 |  |
| 3043706 | Sodium [Moles/volume] in Arterial blood | 0.866 |  |
| 3022810 | Sodium [Moles/volume] in Body fluid | 0.866 |  |
| 3008037 | Lactate [Moles/volume] in Venous blood | 0.865 |  |
| 3040893 | Potassium [Moles/volume] in Capillary blood | 0.864 |  |
| 3035285 | Chloride [Moles/volume] in Venous blood | 0.864 |  |
| 3013194 | Chloride [Moles/volume] in Body fluid | 0.863 |  |
| 3044319 | Citrate [Moles/volume] in Urine | 0.862 |  |
| 3038702 | Sodium [Moles/volume] in Capillary blood | 0.861 |  |
| 3031248 | Chloride [Moles/volume] in Arterial blood | 0.861 |  |
| 3036243 | Potassium [Moles/volume] in Body fluid | 0.859 |  |
| 3039964 | Chloride [Moles/volume] in Capillary blood | 0.859 |  |
| 3018405 | Lactate [Moles/volume] in Arterial blood | 0.858 | 1277 |
| 3011832 | Coagulation factor VIII activity [Units/volume] in Platelet poor plasma by Chromogenic method | 0.858 |  |
| 3023023 | von Willebrand factor (vWf) ristocetin cofactor [Units/volume] in Platelet poor plasma | 0.855 |  |
| 43534000 | von Willebrand factor (vWf).activity [Units/volume] in Platelet poor plasma by Immunoassay | 0.852 |  |
| 3022426 | Pepsinogen II [Mass/volume] in Serum or Plasma | 0.849 |  |
| 3033888 | Pepsinogen I [Mass/volume] in Serum or Plasma | 0.848 |  |
| 3020748 | Chloride [Moles/volume] in Water | 0.848 |  |
| 3044014 | Lactate [Moles/volume] in Urine | 0.846 |  |
| 21491077 | Lactyl lactate [Moles/volume] in Serum or Plasma | 0.846 |  |
| 3009024 | Chloride [Moles/volume] in Specimen | 0.844 |  |
| 3008561 | Activated protein C resistance [Time Ratio] in Platelet poor plasma by Coagulation assay | 0.842 | 797 |
| 36306070 | von Willebrand factor.ristocetin cofactor inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.842 |  |
| 44786869 | Apixaban [Mass/volume] in Platelet poor plasma by Chromogenic method | 0.842 |  |
| 3013098 | Potassium [Moles/volume] in Specimen | 0.842 |  |
| 3024765 | Citrate [Moles/volume] in 24 hour Urine | 0.841 |  |
| 1469953 | von Willebrand factor activity.ristocetin cofactor (GPIbR) actual/normal in Platelet poor plasma by Turbidimetry | 0.839 |  |
| 3007733 | Chloride [Moles/volume] in Urine | 0.838 | 697 |
| 3012127 | Citrate [Moles/volume] in Semen | 0.834 |  |
| 3026681 | Sodium [Moles/volume] in Specimen | 0.833 |  |
| 3007204 | Coagulation factor IX activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.832 |  |
| 3013823 | Potassium [Moles/volume] in Red Blood Cells | 0.832 |  |
| 3002907 | Coagulation factor XII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.832 |  |
| 3016038 | Potassium [Moles/volume] in Urine | 0.832 | 493 |
| 44816763 | Rivaroxaban [Mass/volume] in Platelet poor plasma by Chromogenic method | 0.831 |  |
| 3013364 | Pepsinogen [Mass/volume] in Serum or Plasma | 0.830 |  |
| 3000688 | Coagulation factor XI activity [Units/volume] in Platelet poor plasma by Chromogenic method | 0.830 |  |
| 3011901 | Tau protein [Mass/volume] in Serum | 0.830 |  |
| 3041934 | Coagulation factor XI activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.827 |  |
| 3012335 | Coagulation factor VIII Activity.Xa activator [Units/volume] in Platelet poor plasma by Chromogenic method | 0.826 |  |
| 3031627 | von Willebrand factor (vWf).collagen binding activity/von Willebrand factor Ag [Ratio] in Platelet poor plasma by Immunoassay | 0.825 |  |
| 3003181 | Sodium [Moles/volume] in Urine | 0.825 | 412 |
| 648199 | Tau protein.phosphorylated 217/Amyloid beta 42 peptide [Ratio] in Serum or Plasma | 0.825 |  |
| 3001183 | Coagulation factor XII activity [Units/volume] in Platelet poor plasma by Chromogenic method | 0.823 |  |
| 3037884 | Follitropin/Lutropin [Molar ratio] in Serum or Plasma | 0.823 |  |
| 3001838 | Sodium [Moles/volume] in Red Blood Cells | 0.821 |  |
| 3032768 | Coagulation factor VIII activity actual/normal in Platelet poor plasma by Chromogenic method | 0.821 |  |
| 36660713 | Coagulation factor VIII activity and inhibitor panel - Platelet poor plasma by Chromogenic method | 0.821 |  |
| 1001704 | Coagulation factor VIII inhibitor [Units/volume] in Platelet poor plasma by Chromogenic method | 0.818 |  |
| 3038198 | Pepsinogen [Mass/volume] in Blood | 0.817 |  |
| 3026498 | Coagulation factor IX activity [Units/volume] in Platelet poor plasma by Chromogenic method | 0.817 |  |
| 3025317 | Coagulation factor VII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.816 |  |
| 3029847 | von Willebrand factor (vWf).collagen binding activity actual/normal in Platelet poor plasma by Immunoassay | 0.815 |  |
| 43055459 | Dabigatran [Mass/volume] in Serum or Plasma | 0.815 |  |
| 1175829 | Coagulation factor VIII.recombinant.bound/von Willebrand factor (vWf) Ag in Plasma by Immunoassay | 0.813 |  |
| 3037533 | von Willebrand factor (vWf) actual/normal in Platelet poor plasma by Aggregometry.ristocetin cofactor activity | 0.812 | 1003 |
| 21493869 | von Willebrand factor (vWf) ristocetin cofactor/von Willebrand factor (vWf) Ag [Ratio] in Platelet poor plasma | 0.811 |  |
| 3026685 | Coagulation factor VII activity [Units/volume] in Platelet poor plasma by Chromogenic method | 0.810 |  |
| 3006109 | Coagulation factor IX activity actual/normal in Platelet poor plasma by Coagulation assay | 0.809 | 1724 |
| 3022520 | Coagulation factor VIII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.808 |  |
| 3035613 | Coagulation factor XIII activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.807 |  |
| 647604 | Coagulation factor VIII Ag [Measurement] in Platelet poor plasma | 0.806 |  |
| 3013706 | Coagulation factor VIII inhibitor [Presence] in Platelet poor plasma by Chromogenic method | 0.805 |  |
| 3028173 | Coagulation factor IX Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.802 |  |
| 40770918 | von Willebrand factor (vWf).activity actual/normal in Platelet poor plasma by Immunoassay | 0.801 |  |
| 1469950 | Coagulation factor VIII activity actual/normal in Platelet poor plasma by Bovine factor X substrate + Chromogenic | 0.801 |  |
| 1470010 | Tau protein.phosphorylated 217/Tau protein.unphosphorylated 217 [Mass Ratio] in Plasma by LC/MS/MS | 0.800 |  |
| 3027613 | 2-Methylcitrate [Moles/volume] in Serum or Plasma | 0.799 |  |
| 3001850 | Coagulation factor XI activity actual/normal in Platelet poor plasma by Coagulation assay | 0.798 |  |
| 44816662 | Soluble fms-like tyrosine kinase-1 and placental growth factor panel - Serum or Plasma | 0.797 |  |
| 3033659 | Coagulation factor XII Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.797 |  |
| 36660563 | Coagulation factor VIII inhibitor [Interpretation] in Platelet poor plasma by Chromogenic method | 0.797 |  |
| 36304905 | Coagulation factor IX activity actual/normal in Platelet poor plasma by Chromogenic method | 0.797 |  |
| 3012989 | Citrate [Moles/time] in 24 hour Urine | 0.796 | 1252 |
| 3040976 | Activated protein C resistance [Presence] in Platelet poor plasma by Coagulation assay | 0.796 |  |
| 3053342 | Fondaparinux [Mass/volume] in Serum or Plasma | 0.795 |  |
| 21493390 | Coagulation factor XI inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.795 |  |
| 3034423 | Pepsinogen I [Mass/volume] in Urine | 0.795 |  |
| 3038156 | Coagulation factor XI Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.794 |  |
| 44816701 | von Willebrand factor (vWf).activity actual/normal in Control Platelet poor plasma by Immunoassay | 0.793 |  |
| 3017528 | Coagulation factor IX Ag actual/normal in Platelet poor plasma by Immunoassay | 0.791 |  |
| 3002348 | Coagulation factor XII activity actual/normal in Platelet poor plasma by Coagulation assay | 0.791 |  |
| 3042349 | von Willebrand factor (vWf) cleaving protease inhibitor [Units/volume] in Platelet poor plasma | 0.790 |  |
| 3009366 | Coagulation factor XIII Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.790 |  |
| 44816700 | von Willebrand factor (vWf).activity actual/normal in Platelet poor plasma by Immunoassay --immediately after 1:1 addition of normal plasma | 0.790 |  |
| 3033554 | Citrate [Mass/volume] in Urine | 0.789 |  |
| 44816653 | Placental growth factor [Mass/volume] in Serum | 0.787 |  |
| 3010846 | Coagulation factor VIII Ab [Units/volume] in Platelet poor plasma by Immunoassay | 0.784 |  |
| 3036035 | von Willebrand factor (vWf) Ag actual/normal in Platelet poor plasma by Immunoassay | 0.784 | 1126 |
| 3045209 | Lutropin/Follitropin [Ratio] in Serum or Plasma | 0.783 |  |
| 3009450 | Coagulation factor VIII Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.783 |  |
| 3026785 | Coagulation factor VII activity actual/normal [Molar ratio] in Platelet poor plasma by Coagulation assay | 0.783 |  |
| 3000089 | Coagulation factor XI inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.781 |  |
| 3011547 | Coagulation factor VII activity actual/normal in Platelet poor plasma by Coagulation assay | 0.781 | 1752 |
| 36303808 | von Willebrand factor collagen binding adhesion inhibitor [Units/volume] in Platelet poor plasma by Chromogenic method | 0.781 |  |
| 36032215 | Coagulation factor II inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.780 |  |
| 3028163 | Coagulation factor VII Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.780 |  |
| 645389 | Coagulation factor XIII inhibitor [Measurement] in Platelet poor plasma | 0.780 |  |
| 3019423 | Coagulation factor IX inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.780 |  |
| 3015418 | Coagulation factor VIII [Interpretation] in Specimen | 0.779 |  |
| 36031709 | Coagulation factor XII inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.779 |  |
| 3004009 | Coagulation factor IX inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.778 |  |
| 1259607 | Regorafenib [Mass/volume] in Serum or Plasma | 0.777 |  |
| 3028460 | Coagulation factor VII+Acarboxy Ag [Units/volume] in Platelet poor plasma by Immunoassay | 0.777 |  |
| 3024402 | Coagulation factor VII+Acarboxy Ag activity actual/normal in Platelet poor plasma by Immunoassay | 0.777 |  |
| 3046629 | Coagulation factor II inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.775 |  |
| 3019757 | Coagulation factor XIII coagulum dissolution [Units/volume] in Platelet poor plasma by Coagulation assay | 0.775 |  |
| 3019908 | Coagulation factor VIII Ag [Mass/volume] in Platelet poor plasma by Immunoassay | 0.775 |  |
| 3020066 | Coagulation factor XIII activity actual/normal in Platelet poor plasma by Chromogenic method | 0.774 |  |
| 3029727 | Coagulation factor XIII inhibitor [Presence] in Platelet poor plasma by Chromogenic method | 0.774 |  |
| 3033904 | Coagulation factor XI Ag actual/normal in Platelet poor plasma by Immunoassay | 0.773 |  |
| 3048887 | Activated protein C resistance [Interpretation] in Platelet poor plasma | 0.773 |  |
| 646418 | von Willebrand factor activity.GPIbM/von Willebrand factor (vWf) Ag [Ratio] in Platelet poor plasma by Turbidimetry | 0.773 |  |
| 36031637 | Coagulation factor IX activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.773 |  |
| 36032226 | Coagulation factor XI activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.773 |  |
| 3019250 | Coagulation factor VIII activity actual/normal in Platelet poor plasma by Coagulation assay | 0.772 | 794 |
| 1469707 | Coagulation factor XIII inhibitor [Units/volume] in Platelet poor plasma by Chromogenic method | 0.772 |  |
| 40760870 | Coagulation factor XIII inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.770 |  |
| 3034792 | Coagulation factor XII Ag actual/normal in Platelet poor plasma by Immunoassay | 0.769 |  |
| 3036931 | Citrate [Mass/volume] in 24 hour Urine | 0.769 |  |
| 42870512 | Rivaroxaban [Units/volume] in Platelet poor plasma by Chromogenic method | 0.768 |  |
| 3964710 | von Willebrand factor.platelet binding activity without ristocetin [Units/volume] in Platelet poor plasma by Latex agglutination | 0.767 |  |
| 42528613 | Edoxaban [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.767 |  |
| 44816979 | Isocitrate [Moles/volume] in Serum or Plasma | 0.766 |  |
| 3013178 | Coagulation factor XIII Ag actual/normal in Platelet poor plasma by Immunoassay | 0.765 |  |
| 46237003 | Prothrombin activity [Units/volume] in Platelet poor plasma by Coagulation assay --immediately after addition of factor II depleted plasma | 0.765 |  |
| 3000818 | Coagulation factor XII inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.765 |  |
| 36032236 | Coagulation factor II activity and inhibitor panel - Platelet poor plasma by Coagulation assay | 0.764 |  |
| 3000242 | Tau protein [Mass/volume] in Cerebral spinal fluid | 0.763 |  |
| 3030424 | Coagulation factor VII Ag actual/normal in Platelet poor plasma by Immunoassay | 0.762 |  |
| 21494685 | Coagulation factor VII inhibitor [Presence] in Platelet poor plasma by Coagulation assay | 0.761 |  |
| 3035325 | Coagulation factor XIII inhibitor [Units/volume] in Platelet poor plasma by Coagulation assay | 0.761 |  |
| 1002334 | von Willebrand factor (vWf) cleaving protease activity [Enzymatic activity/volume] in Platelet poor plasma by Chromogenic method | 0.758 |  |
| 46235718 | Delta aPTT [Time] in Platelet poor plasma by Coagulation assay | 0.758 |  |
| 1469900 | von Willebrand factor activity.glycoprotein Ib gain of function (GPIbM)von Willebrand factor activity.glycoprotein Ib gain of function (GPIbM) actual/normal in Platelet poor plasma by Turbidimetry | 0.757 |  |
| 3001036 | Coagulation factor VII+Coagulation factor X actual/normal in Platelet poor plasma by Coagulation assay | 0.757 |  |
| 3030094 | Coagulation factor II circulating inhibitor [Presence] in Platelet poor plasma | 0.754 |  |
| 1259472 | Olaparib [Mass/volume] in Serum or Plasma | 0.752 |  |
| 40758492 | Argatroban [Mass/volume] in Platelet poor plasma | 0.751 |  |
| 1259844 | Rucaparib [Mass/volume] in Serum or Plasma | 0.749 |  |
| 645565 | von Willebrand factor activity.glycoprotein Ib gain of function (GPIbM)von Willebrand factor activity.glycoprotein Ib gain of function (GPIbM) actual/normal in Platelet poor plasma by Immunoassay | 0.747 |  |
| 3965947 | Tau protein [Mass/volume] in Cerebral spinal fluid by Immunoassay | 0.745 |  |
| 3045755 | Tau protein [Presence] in Body fluid | 0.743 |  |
| 3005445 | Coagulation factor X activity [Units/volume] in Platelet poor plasma by Coagulation assay | 0.742 |  |
| 3031430 | Propofol [Mass/volume] in Serum or Plasma | 0.740 |  |
| 3010816 | Methoxychlor [Mass/volume] in Serum or Plasma | 0.736 |  |
| 3050218 | Voriconazole [Mass/volume] in Serum or Plasma | 0.736 |  |
| 3025481 | Topiramate [Mass/volume] in Serum or Plasma | 0.733 | 1804 |
| 21493536 | Voriconazole N-oxide [Mass/volume] in Serum or Plasma | 0.733 |  |
| 3021925 | Trypsin+Trypsinogen [Mass/volume] in Serum or Plasma | 0.732 |  |
| 3038158 | Molindone [Mass/volume] in Serum or Plasma | 0.732 |  |
| 1001553 | PT mixing study panel - Platelet poor plasma by Coagulation assay | 0.730 |  |
| 1259491 | Phosphorylated tau 181 [Mass/volume] in Plasma by Immunoassay | 0.729 |  |
| 3964616 | Tau protein/Tau protein.phosphorilated 181 [Mass Ratio] in Cerebral spinal fluid | 0.729 |  |
| 3029242 | Protein C/Coagulation factor X [Mass Ratio] in Platelet poor plasma | 0.728 |  |
| 3035693 | Dimethadione [Mass/volume] in Serum or Plasma | 0.728 |  |
| 1092350 | aPTT.factor substitution [Time Ratio] in Control Platelet poor plasma by Coagulation assay --2H post incubation with 1:1 normal plasma | 0.726 |  |
| 1617375 | aPTT mixing study panel - Platelet poor plasma | 0.726 |  |
| 3019885 | Itraconazole [Mass/volume] in Serum or Plasma | 0.725 |  |
| 3018008 | Dimethoate [Mass/volume] in Serum or Plasma | 0.725 |  |
| 3048571 | Activated protein C resistance panel - Platelet poor plasma | 0.725 |  |
| 3035737 | Plasminogen activator tissue type Ag [Mass/volume] in Platelet poor plasma by Immunoassay --10 minutes post venistasis | 0.724 |  |
| 1091858 | Prothrombin time (PT) factor substitution [Time Ratio] in Control Platelet poor plasma by Coagulation assay --2H post incubation with 1:1 normal plasma | 0.723 |  |
| 3041944 | Activated partial thromboplastin time (aPTT) in Platelet poor plasma by Coagulation assay -- after addition of protein C activator/Activated partial thromboplastin time (aPTT) | 0.721 |  |
| 647304 | Coagulation factor VIII inhibitor [Measurement] in Platelet poor plasma | 0.721 |  |
| 3007211 | Activated protein C resistance [Presence] in Blood by NAA with probe detection | 0.720 | 1755 |
| 3020052 | Plasminogen activator tissue type Ag [Mass/volume] in Platelet poor plasma by Immunoassay --20 minutes post venistasis | 0.720 |  |
| 36031547 | Activated clotting time (ACT) of Blood | 0.718 |  |
| 3023763 | Trypsinogen [Mass/volume] in Serum or Plasma | 0.716 |  |
| 3015374 | Plasminogen activator tissue type [Units/volume] in Platelet poor plasma by Chromogenic method --20 minutes post venistasis | 0.716 |  |
| 1091208 | aPTT.factor substitution [Time Ratio] in Control Platelet poor plasma by Coagulation assay --immediately after addition of normal plasma | 0.713 |  |
| 3004214 | Plasminogen activator tissue type [Units/volume] in Platelet poor plasma by Chromogenic method --10 minutes post venistasis | 0.713 |  |
| 3017236 | Plasminogen activator tissue type [Mass/volume] in Platelet poor plasma by Chromogenic method --10 minutes post venistasis | 0.711 |  |
| 3000275 | Trypsinogen I Free [Mass/volume] in Serum or Plasma | 0.711 |  |
| 40761564 | Tau protein/Protein.total in Cerebral spinal fluid | 0.708 |  |
| 40760873 | Activated partial thromboplastin time (aPTT).factor substitution in Platelet poor plasma by Coagulation assay --immediately after addition of normal plasma/pre addition of normal plasma | 0.707 |  |
| 21493902 | Pepsin A+Pepsinogen A [Mass/volume] in Lower respiratory specimen by Immunoassay | 0.704 |  |
| 3031303 | aPTT.factor substitution 2H post incubation with 1:4 normal plasma in Platelet poor plasma by Coagulation assay | 0.697 |  |
| 36032394 | aPTT.factor substitution 2H post incubation with 1:1 normal plasma in Platelet poor plasma by Coagulation assay | 0.694 |  |
| 1175700 | aPTT.factor substitution with 1:1 Pooled Normal Plasma in Platelet poor plasma by Coagulation assay | 0.694 |  |
| 3036078 | Lutropin [Moles/volume] in Serum or Plasma | 0.693 |  |
| 3037430 | Protein C/Coagulation factor IX [Mass Ratio] in Platelet poor plasma | 0.693 |  |
| 1616827 | Angiopoietin receptor 2 [Mass/volume] in Serum or Plasma | 0.692 |  |
| 46235717 | Delta dRVVT [Time] in Platelet poor plasma by Coagulation assay | 0.690 |  |
| 46235359 | Vascular endothelial growth factor A [Mass/volume] in Serum or Plasma | 0.690 |  |
| 3044002 | Follitropin and Lutropin panel [Units/volume] - Serum or Plasma | 0.690 |  |
| 3035670 | Protein C Ag/Coagulation factor VII Ag [Mass Ratio] in Platelet poor plasma by Immunoassay | 0.688 |  |
| 3004923 | Protein C [Mass/volume] in Plasma | 0.687 |  |
| 3966146 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Serum or Plasma | 0.685 |  |
| 1616395 | dRVVT/dRVVT.excess phospholipid [Ratio] normalized in Platelet poor plasma by Coagulation assay | 0.685 |  |
| 3965350 | Soluble urokinase plasminogen activator receptor [Mass/volume] in Plasma | 0.684 |  |
| 3031767 | Vascular endothelial growth factor [Mass/volume] in Serum or Plasma | 0.682 |  |
| 646647 | Antithrombin Ag [Measurement] in Platelet poor plasma | 0.681 |  |
| 1617671 | Fibroblast growth factor 2 [Mass/volume] in Serum or Plasma | 0.681 |  |
| 3016708 | Kallikrein [Enzymatic activity/volume] in Plasma | 0.679 |  |
| 3001998 | Lutropin.beta subunit [Moles/volume] in Serum or Plasma | 0.678 |  |
| 3003489 | Gonadotropin releasing hormone [Moles/volume] in Serum or Plasma | 0.678 |  |
| 40757350 | Thrombin time.factor substitution immediately after 1:4 addition of normal plasma in Platelet poor plasma by Coagulation assay | 0.675 |  |
| 3015962 | Follitropin.beta subunit [Moles/volume] in Serum or Plasma | 0.674 |  |
| 3018853 | Superoxide dismutase [Enzymatic activity/volume] in Plasma | 0.673 |  |
| 3032493 | dRVVT/dRVVT W excess phospholipid (screen to confirm ratio) | 0.672 | 3000 |
| 3052657 | Follitropin [Units/volume] in Serum or Plasma --pre 100 ug luteinizing releasing hormone IV | 0.671 |  |
| 3022519 | Antithrombin [Interpretation] in Platelet poor plasma | 0.669 | 1117 |
| 44816944 | Alpha-L-iduronidase [Enzymatic activity/volume] in Serum or Plasma | 0.669 |  |
| 3043315 | Progesterone/Estradiol (E2) [Mass Ratio] in Serum or Plasma | 0.669 |  |
| 40757499 | Catalase [Enzymatic activity/volume] in Plasma | 0.668 |  |
| 46235835 | Testosterone/Cortisol [Molar ratio] in Serum or Plasma | 0.667 |  |
| 3004671 | Alpha galactosidase A [Enzymatic activity/volume] in Serum or Plasma | 0.667 |  |
| 3039189 | Lupus anticoagulant neutralization dilute phospholipid [Time] in Platelet poor plasma | 0.659 |  |
| 42870500 | Reptilase time actual/Normal | 0.657 | 3000 |
| 36660198 | dRVVT/dRVVT.excess phospholipid [Ratio] in Platelet poor plasma by Coagulation assay --post DOAC neutralization | 0.646 |  |
| 1617654 | dRVVT/dRVVT.excess phospholipid [Ratio] normalized in Platelet poor plasma by Coagulation assay --post DOAC neutralization | 0.640 |  |
| 3027112 | dRVVT actual/normal [Presence] in Platelet poor plasma by Coagulation assay | 0.640 |  |
| 3030949 | Reptilase time.factor substitution immediately after addition of normal plasma in Platelet poor plasma by Coagulation assay | 0.638 |  |
| 3019174 | dRVVT in Platelet poor plasma by Coagulation assay | 0.634 | 759 |
| 3010528 | dRVVT actual/normal (normalized LA screen) | 0.634 | 1167 |
| 3039363 | dRVVT in Platelet poor plasma from Control by Coagulation assay | 0.632 |  |
| 46235126 | dRVVT with 1:1 PNP (LA mix) | 0.631 | 1929 |
| 3005308 | Reptilase time | 0.627 | 3000 |
| 1002253 | dRVVT factor substitution immediately after 1:1 addition of normal plasma and heparin neutralization in Platelet poor plasma by Coagulation assay | 0.625 |  |
| 46235125 | dRVVT with 1:1 PNP actual/normal (normalized LA mix) | 0.625 |  |
| 1002056 | dRVVT post heparin neutralization in Platelet poor plasma by Coagulation assay | 0.617 |  |
| 3047091 | Lupus anticoagulant neutralization buffer [Time] in Platelet poor plasma by Coagulation assay | 0.615 |  |
| 3011893 | Reptilase time in Platelet poor plasma from Control by Coagulation assay | 0.614 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1547 | p-adam13 | % | 95% | name+unit+values | 292 | 0 | [22.2, 37.98, 43.11, 48.45, 54.49, 61.91, 68.59, 80.67, 92.98] | P -ADAMTS13, aktiivisuus, plasmasta | Plasma |  | ADAMTS13 [Activity] in Plasma |
| 1548 | p-adam13 |  | 5% | name | 16 | 100 |  | P -ADAMTS13, aktiivisuus, plasmasta | Plasma |  | ADAMTS13 [Activity] in Plasma |
| 1549 | p-afxaapi | ug/l | 83% | name+unit+values | 885 | 0 | [28.54, 41.81, 56.02, 69.84, 87.39, 115.17, 139.04, 176.98, 252.81] | P -Apiksabaani, estovaikutus hyytymistekijä Xa:han | Plasma |  | Apixaban [Mass/volume] in Plasma |
| 1550 | p-afxaapi |  | 17% | name | 175 | 100 |  | P -Apiksabaani, estovaikutus hyytymistekijä Xa:han | Plasma |  | Apixaban [Mass/volume] in Plasma |
| 1551 | p-afxariv | ug/l | 60% | name+unit+values | 267 | 0 | [22.28, 30.54, 37.21, 46.02, 57.42, 75.62, 109.39, 173.07, 263.74] | P -Rivaroksabaani, estovaikutus hyytymistekijä Xa:han | Plasma |  | Rivaroxaban [Mass/volume] in Plasma |
| 1552 | p-afxariv |  | 40% | name | 177 | 100 |  | P -Rivaroksabaani, estovaikutus hyytymistekijä Xa:han | Plasma |  | Rivaroxaban [Mass/volume] in Plasma |
| 1553 | p-apcres | form | 5% | name+unit | 14 | 0 |  | P -APC-resistenssi | Plasma |  | Activated protein C resistance [Ratio] in Plasma |
| 1554 | p-apcres |  | 95% | name+values | 261 | 100 | [1.8, 2, 2.5, 2.74, 2.87, 2.98, 3.02, 3.18, 3.5] | P -APC-resistenssi | Plasma |  | Activated protein C resistance [Ratio] in Plasma |
| 1555 | p-apcres. | form | 99% | name+unit+values | 3154 | 0 | [2.46, 2.7, 2.8, 2.87, 2.9, 3, 3, 3.1, 3.2] |  | Plasma |  | Activated protein C resistance [Ratio] in Plasma |
| 1556 | p-apcres. |  | 1% | name | 38 | 100 |  |  | Plasma |  | Activated protein C resistance [Ratio] in Plasma |
| 1557 | p-apot |  | 100% | name | 113 | 100 |  |  | Plasma |  |  |
| 1558 | p-aptt | s | 98% | name+unit+values | 145452 | 0 | [24.74, 26.02, 27.07, 28.48, 29.86, 31.14, 33.13, 36.35, 45.81] | P -Tromboplastiiniaika, aktivoitu, partiaalinen | Plasma |  | Activated partial thromboplastin time [Time] in Plasma |
| 1559 | p-aptt |  | 2% | name | 3095 | 100 |  | P -Tromboplastiiniaika, aktivoitu, partiaalinen | Plasma |  | Activated partial thromboplastin time [Time] in Plasma |
| 1560 | p-aptt-l |  | 100% | name | 1896 | 100 |  |  | Plasma |  | Activated partial thromboplastin time [Time] in Plasma |
| 1561 | p-aptt. | s | 96% | name+unit+values | 829 | 0 | [24.98, 26.3, 27.53, 28.64, 29.69, 30.7, 32, 33.93, 38.41] |  | Plasma |  | Activated partial thromboplastin time [Time] in Plasma |
| 1562 | p-aptt. |  | 4% | name | 38 | 100 |  |  | Plasma |  | Activated partial thromboplastin time [Time] in Plasma |
| 1563 | p-apttm/m |  | 100% | name+values | 1897 | 100 | [0.9, 0.93, 0.95, 0.96, 0.98, 1, 1.04, 1.06, 1.11] |  | Plasma |  | Activated partial thromboplastin time.mixing study [Ratio] in Plasma |
| 1564 | p-apttspr | s | 78% | name+unit+values | 146 | 0 | [31.44, 32.4, 33.4, 34.93, 35.75, 36.34, 37.27, 38.68, 43.4] |  | Plasma |  | Activated partial thromboplastin time [Time] in Plasma |
| 1565 | p-apttspr |  | 22% | name | 41 | 100 |  |  | Plasma |  | Activated partial thromboplastin time [Time] in Plasma |
| 1566 | p-ca++hoi | mmol/l | 7% | name+unit | 11 | 0 |  |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1567 | p-ca++hoi |  | 93% | name+values | 157 | 100 | [1.1, 1.13, 1.15, 1.17, 1.19, 1.21, 1.22, 1.24, 1.26] |  | Plasma |  | Calcium.ionized [Moles/volume] in Plasma |
| 1568 | p-citratm |  | 100% | name | 1692 | 100 |  |  | Plasma |  | Citrate [Moles/volume] in Plasma |
| 1569 | p-clhoi | mmol/l | 100% | name+unit+values | 161 | 0 | [96.78, 99.15, 100.83, 102, 103, 104.79, 105.84, 106.7, 108.47] |  | Plasma |  | Chloride [Moles/volume] in Plasma |
| 1570 | p-f8paiv | % | 95% | name+unit+values | 216 | 0 | [39.62, 76.99, 102.21, 114.35, 129.3, 143.4, 157.7, 196.99, 246.74] |  | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1571 | p-f8paiv |  | 5% | name | 11 | 100 |  |  | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1572 | p-fii | % | 48% | name+unit+values | 879 | 0.23 | [61.57, 76.44, 83.11, 88.29, 93.18, 97.78, 102.21, 107.17, 113.51] | P -Protrombiini | Plasma |  | Coagulation factor II [Activity] in Plasma |
| 1573 | p-fii |  | 52% | name+values | 964 | 100 | [77.3, 84.03, 87.1, 90.88, 93.17, 96.37, 100.57, 105.9, 112.5] | P -Protrombiini | Plasma |  | Coagulation factor II [Activity] in Plasma |
| 1574 | p-fix | % | 95% | name+unit+values | 1416 | 0 | [47.55, 70.85, 82.85, 93.25, 101.17, 110, 119.02, 128.99, 143.26] | P -Hyytymistekijä IX | Plasma |  | Coagulation factor IX [Activity] in Plasma |
| 1575 | p-fix |  | 5% | name | 76 | 100 |  | P -Hyytymistekijä IX | Plasma |  | Coagulation factor IX [Activity] in Plasma |
| 1576 | p-fs-mix |  | 100% | name+values | 1895 | 100 | [28.6, 29.05, 29.55, 30, 30.68, 31, 31.77, 34.32, 37.6] |  | Plasma |  | Activated partial thromboplastin time.mixing study [Time] in Plasma |
| 1577 | p-fsl-mix |  | 100% | name+values | 1894 | 100 | [27.66, 28.22, 29, 29.5, 30, 30.17, 31, 31.97, 33.87] |  | Plasma |  | Dilute Russell viper venom time mix [Time] in Plasma |
| 1578 | p-fsl/fs |  | 100% | name+values | 1889 | 100 | [0.93, 0.98, 1.01, 1.03, 1.06, 1.1, 1.14, 1.19, 1.29] |  | Plasma |  | Dilute Russell viper venom time mix index [Ratio] in Plasma |
| 1579 | p-fvii | % | 90% | name+unit+values | 1818 | 0.11 | [48.8, 69.53, 86.15, 96.16, 104.36, 113.05, 122.83, 135.25, 151.88] | P -Hyytymistekijä VII | Plasma |  | Coagulation factor VII [Activity] in Plasma |
| 1580 | p-fvii |  | 10% | name+values | 196 | 100 | [67.45, 82.23, 90.82, 98.85, 107.17, 113, 125.69, 137.67, 161.9] | P -Hyytymistekijä VII | Plasma |  | Coagulation factor VII [Activity] in Plasma |
| 1581 | p-fviii | % | 87% | name+unit+values | 4777 | 0.04 | [77.4, 100.3, 119.2, 140.02, 160.19, 184.44, 211.4, 247.19, 311.94] | P -Hyytymistekijä VIII | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1582 | p-fviii | form | 0% | name+unit | 7 | 0 |  | P -Hyytymistekijä VIII | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1583 | p-fviii |  | 13% | name+values | 696 | 100 | [83.7, 100.38, 111.11, 124.39, 139.14, 161.05, 180.1, 202.21, 238.65] | P -Hyytymistekijä VIII | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1584 | p-fviii. | % | 93% | name+unit+values | 28767 | 0 | [100.3, 128.09, 149.07, 170.88, 193.18, 217.07, 245.88, 283.52, 344.17] |  | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1585 | p-fviii. |  | 7% | name+values | 2051 | 100 | [102.57, 121.76, 137.04, 153.56, 169.71, 188.24, 205.8, 229.29, 273.79] |  | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1586 | p-fviiikr | % | 71% | name+unit | 124 | 0 |  |  | Plasma |  | Coagulation factor VIII [Activity] in Plasma by Chromogenic |
| 1587 | p-fviiikr |  | 29% | name | 51 | 100 |  |  | Plasma |  | Coagulation factor VIII [Activity] in Plasma by Chromogenic |
| 1588 | p-fviiire | % | 75% | name+unit | 251 | 0.4 |  | P-Hyytymistekijä VIII, rekombinantti | Plasma |  | Coagulation factor VIII.recombinant [Activity] in Plasma |
| 1589 | p-fviiire | form | 7% | name+unit | 23 | 0 |  | P-Hyytymistekijä VIII, rekombinantti | Plasma |  | Coagulation factor VIII.recombinant [Activity] in Plasma |
| 1590 | p-fviiire |  | 18% | name | 62 | 100 |  | P-Hyytymistekijä VIII, rekombinantti | Plasma |  | Coagulation factor VIII.recombinant [Activity] in Plasma |
| 1591 | p-fviiit | % | 90% | name+unit+values | 361 | 0 | [16.3, 37.97, 59.33, 87.28, 110.35, 131.87, 148.05, 185.43, 226.83] |  | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1592 | p-fviiit |  | 10% | name | 38 | 100 |  |  | Plasma |  | Coagulation factor VIII [Activity] in Plasma |
| 1593 | p-fxi | % | 31% | name+unit+values | 395 | 0 | [50.08, 64.57, 75.25, 81.99, 89.24, 97.03, 104.84, 115.34, 141.06] | P -Hyytymistekijä XI | Plasma |  | Coagulation factor XI [Activity] in Plasma |
| 1594 | p-fxi |  | 69% | name | 874 | 100 |  | P -Hyytymistekijä XI | Plasma |  | Coagulation factor XI [Activity] in Plasma |
| 1595 | p-fxii | % | 29% | name+unit+values | 366 | 0 | [39.18, 49.17, 59.19, 66.57, 75.37, 84.82, 94.93, 104.19, 121.16] | P -Hyytymistekijä XII | Plasma |  | Coagulation factor XII [Activity] in Plasma |
| 1596 | p-fxii |  | 71% | name | 879 | 100 |  | P -Hyytymistekijä XII | Plasma |  | Coagulation factor XII [Activity] in Plasma |
| 1597 | p-fxiii | % | 92% | name+unit+values | 2087 | 0.1 | [46.67, 56.85, 67.27, 77.3, 88.74, 99.76, 113.43, 126.96, 141.89] | P -Hyytymistekijä XIII | Plasma |  | Coagulation factor XIII [Activity] in Plasma |
| 1598 | p-fxiii |  | 8% | name+values | 176 | 100 | [92, 99.83, 108.05, 114.95, 122.43, 128.18, 132.91, 138.11, 151.1] | P -Hyytymistekijä XIII | Plasma |  | Coagulation factor XIII [Activity] in Plasma |
| 1599 | p-fxiii. | % | 97% | name+unit+values | 814 | 0 | [69.07, 80.91, 90.57, 100.38, 110.55, 120.66, 130.07, 138.79, 146.65] |  | Plasma |  | Coagulation factor XIII [Activity] in Plasma |
| 1600 | p-fxiii. |  | 3% | name | 29 | 100 |  |  | Plasma |  | Coagulation factor XIII [Activity] in Plasma |
| 1601 | p-k-ses | mmol/l | 97% | name+unit+values | 571 | 0 | [3.47, 3.71, 3.9, 4.01, 4.2, 4.3, 4.5, 4.74, 5.26] |  | Plasma |  | Potassium [Moles/volume] in Plasma |
| 1602 | p-k-ses |  | 3% | name | 16 | 100 |  |  | Plasma |  | Potassium [Moles/volume] in Plasma |
| 1603 | p-khoi | mmol/l | 16% | name+unit | 47 | 0 |  |  | Plasma |  | Potassium [Moles/volume] in Plasma |
| 1604 | p-khoi |  | 84% | name+values | 242 | 100 | [3.37, 3.59, 3.75, 3.89, 4, 4.13, 4.3, 4.49, 4.7] |  | Plasma |  | Potassium [Moles/volume] in Plasma |
| 1605 | p-la1-mix |  | 100% | name+values | 1894 | 100 | [37, 38, 39, 39.98, 40.95, 41.63, 42.91, 44.68, 47.2] |  | Plasma |  | Dilute Russell viper venom time mix [Time] in Plasma |
| 1606 | p-la1/la2 |  | 100% | name+values | 1893 | 100 | [1.11, 1.17, 1.22, 1.27, 1.31, 1.35, 1.42, 1.52, 1.74] |  | Plasma |  | Dilute Russell viper venom time.confirm/screen [Ratio] in Plasma |
| 1607 | p-la2-mix |  | 100% | name+values | 1892 | 100 | [33.9, 34.6, 35.36, 36.63, 38, 39.7, 41.52, 43.7, 50] |  | Plasma |  | Dilute Russell viper venom time.confirm mix [Time] in Plasma |
| 1608 | p-lakthoi | mmol/l | 12% | name+unit | 31 | 0 |  |  | Plasma |  | Lactate [Moles/volume] in Plasma |
| 1609 | p-lakthoi |  | 88% | name+values | 228 | 100 | [0.76, 0.9, 1.02, 1.13, 1.23, 1.39, 1.6, 1.91, 2.55] |  | Plasma |  | Lactate [Moles/volume] in Plasma |
| 1610 | p-lh/fsh |  | 100% | name+values | 896 | 100 | [0.5, 0.7, 0.88, 1, 1.19, 1.4, 1.7, 2.14, 2.78] |  | Plasma |  | Luteinizing hormone/Follicle stimulating hormone [Molar ratio] in Plasma |
| 1611 | p-mitotan | mg/l | 94% | name+unit | 266 | 0 |  | P -Mitotaani (Lysodren) | Plasma |  | Mitotane [Mass/volume] in Plasma |
| 1612 | p-mitotan |  | 6% | name | 18 | 100 |  | P -Mitotaani (Lysodren) | Plasma |  | Mitotane [Mass/volume] in Plasma |
| 1613 | p-na-ses | mmol/l | 97% | name+unit+values | 454 | 0 | [133.95, 135.35, 136.94, 138, 139, 140, 141.09, 142.76, 144.44] |  | Plasma |  | Sodium [Moles/volume] in Plasma |
| 1614 | p-na-ses |  | 3% | name | 16 | 100 |  |  | Plasma |  | Sodium [Moles/volume] in Plasma |
| 1615 | p-nahoi | mmol/l | 100% | name+unit+values | 289 | 0 | [131.88, 133.99, 135.4, 137.05, 138.9, 140, 140.99, 141.97, 143.59] |  | Plasma |  | Sodium [Moles/volume] in Plasma |
| 1616 | p-pg1/pg2 |  | 100% | name+values | 214 | 100 | [5.76, 7.27, 7.89, 8.45, 9.09, 9.69, 10.19, 11.33, 12.48] |  | Plasma |  | Pepsinogen I/Pepsinogen II [Mass Ratio] in Plasma |
| 1617 | p-sit3.1 |  | 100% | name | 774 | 100 |  |  | Plasma |  |  |
| 1618 | p-sitr3.8 |  | 100% | name | 1062 | 100 |  |  | Plasma |  |  |
| 1619 | p-tau-217 | ng/l | 41% | name+unit+values | 132 | 0 | [0.1, 0.12, 0.16, 0.2, 0.29, 0.37, 0.49, 0.64, 0.88] | P -Tau-proteiini, 217-fosforyloitu | Plasma |  | Tau protein.phosphorylated 217 [Mass/volume] in Plasma |
| 1620 | p-tau-217 |  | 59% | name+values | 188 | 100 | [0.12, 0.16, 0.21, 0.28, 0.32, 0.38, 0.45, 0.59, 0.78] | P -Tau-proteiini, 217-fosforyloitu | Plasma |  | Tau protein.phosphorylated 217 [Mass/volume] in Plasma |
| 1621 | p-vwf-ag | % | 95% | name+unit+values | 3318 | 0 | [47.7, 69.31, 90.97, 109.28, 131.06, 156.66, 193.1, 221.66, 254.07] | P -von Willebrand-tekijä, antigeeni | Plasma | Antigen | von Willebrand factor Ag [Units/volume] in Plasma |
| 1622 | p-vwf-ag |  | 5% | name+values | 164 | 100 | [42, 61.65, 79.42, 93.3, 113, 130.6, 161.7, 185.75, 231] | P -von Willebrand-tekijä, antigeeni | Plasma | Antigen | von Willebrand factor Ag [Units/volume] in Plasma |
| 1623 | p-vwf-akt | % | 93% | name+unit+values | 4343 | 0.02 | [38.92, 62.29, 79.13, 94.16, 109.29, 126.62, 152.89, 186.7, 245.26] | P -von Willebrand -tekijä, aktiivisuus (GPIb sitoutuminen) | Plasma |  | von Willebrand factor.GPIb binding [Activity] in Plasma |
| 1624 | p-vwf-akt |  | 7% | name+values | 340 | 100 | [55.5, 72.5, 81.5, 94.5, 101.75, 107.67, 129.5, 152.83, 223.5] | P -von Willebrand -tekijä, aktiivisuus (GPIb sitoutuminen) | Plasma |  | von Willebrand factor.GPIb binding [Activity] in Plasma |
| 1625 | p-vwf-aktt | % | 88% | name+unit+values | 211 | 0 | [36.56, 51.18, 66.86, 84.71, 112.56, 127.89, 144.38, 168.66, 217.53] |  | Plasma |  | von Willebrand factor.GPIb binding [Activity] in Plasma |
| 1626 | p-vwf-aktt |  | 12% | name | 28 | 100 |  |  | Plasma |  | von Willebrand factor.GPIb binding [Activity] in Plasma |
| 1627 | p-vwfcb | % | 92% | name+unit+values | 98 | 0 | [20, 35, 41, 47.3, 52.25, 60.85, 71.65, 83.6, 92] | P -von Willebrand -tekijä, kollageenin sitomiskyky | Plasma |  | von Willebrand factor.collagen binding [Activity] in Plasma |
| 1628 | p-vwfcb |  | 8% | name | 8 | 100 |  | P -von Willebrand -tekijä, kollageenin sitomiskyky | Plasma |  | von Willebrand factor.collagen binding [Activity] in Plasma |
| 1629 | p-vwfpaiv | % | 89% | name+unit | 169 | 0 |  |  | Plasma |  | von Willebrand factor [Activity] in Plasma |
| 1630 | p-vwfpaiv |  | 11% | name | 20 | 100 |  |  | Plasma |  | von Willebrand factor [Activity] in Plasma |
| 1631 | p-vwfrco | % | 30% | name+unit | 35 | 0 |  | P -von Willebrand-tekijä, ristosetiinikofaktori | Plasma |  | von Willebrand factor.ristocetin cofactor [Activity] in Plasma |
| 1632 | p-vwfrco |  | 70% | name | 83 | 100 |  | P -von Willebrand-tekijä, ristosetiinikofaktori | Plasma |  | von Willebrand factor.ristocetin cofactor [Activity] in Plasma |
| 1633 | s-fit/pgf |  | 100% | name+values | 135 | 100 | [6.12, 10.5, 17.8, 26.98, 40.52, 58.17, 73.2, 107.03, 135.33] | S -Endoteelikasvutekijän liukoisen reseptorin (S -sFlt-1) ja plasentaalisen kasvutekijän (S -PlGF) suhde | Serum |  | Soluble fms-like tyrosine kinase 1/Placental growth factor [Mass Ratio] in Serum |
| 1634 | s-flt/pgf |  | 100% | name+values | 326 | 100 | [2.33, 4.43, 7.66, 13.78, 25.02, 41.69, 56.09, 83.81, 137.49] |  | Serum |  | Soluble fms-like tyrosine kinase 1/Placental growth factor [Mass Ratio] in Serum |

