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
Here is group 126.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3000963 | Hemoglobin [Mass/volume] in Blood | 1.000 | 2 |
| 3002173 | Hemoglobin [Mass/volume] in Arterial blood | 1.000 | 188 |
| 3002719 | Hemoglobin [Mass/volume] in Urine | 1.000 |  |
| 3003344 | Hemoglobin [Presence] in Urine | 1.000 |  |
| 3004119 | Hemoglobin [Mass/volume] in Venous blood | 1.000 | 1986 |
| 3004410 | Hemoglobin A1c/Hemoglobin.total in Blood | 1.000 | 81 |
| 3005872 | Hemoglobin [Presence] in Blood | 1.000 |  |
| 3006184 | Hemoglobin [Mass/volume] in Capillary blood | 1.000 |  |
| 3007930 | Methemoglobin/Hemoglobin.total in Blood | 1.000 | 820 |
| 3011397 | Hemoglobin [Presence] in Urine by Test strip | 1.000 | 72 |
| 3018738 | Hemoglobin F/Hemoglobin.total in Blood | 1.000 | 508 |
| 3023081 | Carboxyhemoglobin/Hemoglobin.total in Blood | 1.000 | 875 |
| 3034976 | Hematocrit [Volume Fraction] of Venous blood | 0.986 |  |
| 3023230 | Hematocrit [Volume Fraction] of Arterial blood | 0.983 |  |
| 3009542 | Hematocrit [Volume Fraction] of Blood | 0.979 | 28 |
| 3020277 | Hemoglobin F1/Hemoglobin.total in Blood | 0.969 |  |
| 40760861 | Hemoglobin [Presence] in Urine by Automated test strip | 0.949 |  |
| 3005446 | Hemoglobin A1/Hemoglobin.total in Blood | 0.948 | 836 |
| 3028653 | Carboxyhemoglobin/Hemoglobin.total in Arterial blood | 0.946 | 1815 |
| 3025412 | Methemoglobin/Hemoglobin.total in Red Blood Cells | 0.945 |  |
| 42869584 | Hematocrit [Pure volume fraction] of Venous blood | 0.944 |  |
| 3019108 | Free Hemoglobin [Mass/volume] in Urine | 0.940 |  |
| 3029490 | Free Hemoglobin [Presence] in Urine | 0.939 |  |
| 3006217 | Methemoglobin/Hemoglobin.total in Arterial blood | 0.936 | 1173 |
| 42869587 | Hematocrit [Pure volume fraction] of Arterial blood | 0.935 |  |
| 3016251 | Hemoglobin [Presence] in Stool from gastrointestinal | 0.930 | 351 |
| 42869637 | Methemoglobin/Hemoglobin.total [Pure mass fraction] in Arterial blood | 0.930 |  |
| 42869639 | Carboxyhemoglobin/Hemoglobin.total [Pure mass fraction] in Venous blood | 0.929 |  |
| 3024317 | Carboxyhemoglobin/Hemoglobin.total in Capillary blood | 0.929 |  |
| 3024889 | Methemoglobin/Hemoglobin.total in Venous blood | 0.928 |  |
| 42869644 | Carboxyhemoglobin/Hemoglobin.total [Pure mass fraction] in Arterial blood | 0.927 |  |
| 42869634 | Methemoglobin/Hemoglobin.total [Pure mass fraction] in Venous blood | 0.926 |  |
| 3029071 | Hemoglobin F/Hemoglobin.total in Blood by HPLC | 0.923 |  |
| 42869638 | Methemoglobin/Hemoglobin.total [Pure mass fraction] in Blood | 0.919 |  |
| 3024867 | Hemoglobin F/Hemoglobin.total in Blood from Newborn | 0.919 |  |
| 3010517 | Carboxyhemoglobin/Hemoglobin.total in Venous blood | 0.918 | 1677 |
| 3025543 | Methemoglobin/Hemoglobin.total in Capillary blood | 0.916 |  |
| 3005673 | Hemoglobin A1c/Hemoglobin.total in Blood by HPLC | 0.912 | 215 |
| 42869645 | Carboxyhemoglobin/Hemoglobin.total [Pure mass fraction] in Blood | 0.912 |  |
| 3020428 | Hemoglobin A/Hemoglobin.total in Blood | 0.904 | 506 |
| 1616317 | Hemoglobin [Mass/volume] in Capillary blood by Oximetry | 0.903 |  |
| 1091321 | Hemoglobin [Mass/volume] in Venous blood by calculation | 0.903 |  |
| 3045405 | Hemoglobin F/Hemoglobin.total in Blood by Electrophoresis | 0.902 |  |
| 40758859 | Fetal blood [Volume] in Blood | 0.901 |  |
| 1092073 | Hemoglobin [Presence] in Stool from gastrointestinal lower | 0.900 |  |
| 1002216 | Hemoglobin [Moles/volume] in Venous blood | 0.899 |  |
| 3008108 | Hematocrit [Volume Fraction] of Body fluid | 0.896 | 733 |
| 21490721 | Hemoglobin [Moles/volume] in Arterial blood | 0.896 |  |
| 3007263 | Hemoglobin A1c/Hemoglobin.total in Blood by calculation | 0.896 |  |
| 3049185 | Hemoglobin [Mass/volume] in Urine by Test strip | 0.894 |  |
| 3005147 | Methemoglobin [Mass/volume] in Blood | 0.893 |  |
| 3011550 | Carboxyhemoglobin [Mass/volume] in Blood | 0.893 |  |
| 3028874 | Hemoglobin [Presence] in Body fluid | 0.891 |  |
| 3006239 | Hemoglobin [Mass/volume] in Arterial blood by Oximetry | 0.890 |  |
| 42869619 | Hemoglobin F/Hemoglobin.total [Pure mass fraction] in Blood by HPLC | 0.890 |  |
| 46235392 | Hemoglobin [Mass/volume] in Venous blood by Oximetry | 0.889 |  |
| 3043688 | Hemoglobin [Mass/volume] in Body fluid | 0.888 |  |
| 42869635 | Methemoglobin/Hemoglobin.total [Pure mass fraction] in Mixed venous blood | 0.887 |  |
| 3027484 | Hemoglobin [Mass/volume] in Blood by calculation | 0.887 |  |
| 42869640 | Carboxyhemoglobin/Hemoglobin.total [Pure mass fraction] in Mixed venous blood | 0.886 |  |
| 36305056 | Carboxyhemoglobin/Hemoglobin.total in Arterial blood by Pulse oximetry | 0.885 |  |
| 3018663 | Hemoglobin F/Hemoglobin.total in Amniotic fluid | 0.884 |  |
| 3007339 | Hemoglobin H/Hemoglobin.total in Blood | 0.883 |  |
| 3034037 | Hematocrit [Volume Fraction] of Mixed venous blood | 0.882 |  |
| 42869636 | Methemoglobin/Hemoglobin.total [Pure mass fraction] in Capillary blood | 0.882 |  |
| 3007302 | Hemoglobin [Mass/volume] in Mixed venous blood | 0.881 |  |
| 3033173 | Hemoglobin [Presence] in Specimen | 0.881 |  |
| 3041888 | Hemoglobin H [Presence] in Blood | 0.878 |  |
| 42869643 | Carboxyhemoglobin/Hemoglobin.total [Pure mass fraction] in Capillary blood | 0.876 |  |
| 42869642 | Carboxyhemoglobin/Hemoglobin.total [Pure mass fraction] in Arterial cord blood | 0.875 |  |
| 3024098 | Hemoglobin [Presence] in Stool from gastrointestinal --1st specimen | 0.874 | 625 |
| 42869620 | Hemoglobin F/Hemoglobin.total [Pure mass fraction] in Blood by Electrophoresis | 0.874 |  |
| 3030267 | Hemoglobin [Mass/volume] in Urine by Automated test strip | 0.871 |  |
| 40759063 | Methemoglobin/Hemoglobin.total in Cord blood | 0.871 |  |
| 1616670 | Carboxyhemoglobin/Hemoglobin.total in Central venous blood | 0.871 |  |
| 3039784 | Hemoglobin F [Mass/volume] in Blood | 0.871 |  |
| 645703 | Hemoglobin [Measurement] in Arterial blood | 0.871 |  |
| 40766250 | Carboxyhemoglobin/Hemoglobin.total in Arterial cord blood | 0.869 |  |
| 649284 | Hemoglobin [Measurement] in Venous blood | 0.868 |  |
| 3012471 | Hemoglobin [Presence] in Stool from gastrointestinal lower by Immunoassay | 0.868 | 779 |
| 3040832 | Hemoglobin G/Hemoglobin.total in Blood | 0.867 |  |
| 3018975 | Free Hemoglobin [Presence] in Plasma | 0.864 |  |
| 3034030 | Carboxyhemoglobin/Hemoglobin.total in Mixed venous blood | 0.863 |  |
| 3031282 | Methemoglobin/Hemoglobin.total in Mixed venous blood | 0.863 |  |
| 42869630 | Hemoglobin A1c/Hemoglobin.total [Pure mass fraction] in Blood | 0.861 |  |
| 40758903 | Hemoglobin [Mass/volume] in Blood by Oximetry | 0.861 |  |
| 1616557 | Methemoglobin/Hemoglobin.total in Central venous blood | 0.861 |  |
| 3019909 | Hematocrit [Volume Fraction] of Blood by Centrifugation | 0.861 | 545 |
| 3030153 | Occult blood panel - Stool | 0.861 |  |
| 42869585 | Hematocrit [Pure volume fraction] of Mixed venous blood | 0.859 |  |
| 3022493 | Free Hemoglobin [Mass/volume] in Plasma | 0.859 | 1917 |
| 3038248 | Deoxyhemoglobin [Mass/volume] in Blood | 0.858 |  |
| 42869641 | Carboxyhemoglobin/Hemoglobin.total [Pure mass fraction] in Venous cord blood | 0.858 |  |
| 3028813 | Hematocrit [Volume Fraction] of Capillary blood | 0.857 |  |
| 3020784 | Hemoglobin A2/Hemoglobin.total in Blood | 0.857 | 1545 |
| 42869583 | Hematocrit [Pure volume fraction] of Body fluid | 0.853 |  |
| 3027901 | Hemoglobin [Mass/volume] in Arterial cord blood | 0.852 |  |
| 3026820 | Hemoglobin [Mass/volume] in Venous cord blood | 0.852 |  |
| 3031973 | Hemoglobin A/Hemoglobin.total in Blood by HPLC | 0.851 |  |
| 3011473 | Hemoglobin [Presence] in Stool from gastrointestinal --3rd specimen | 0.848 | 600 |
| 3002957 | Hemoglobin A3/Hemoglobin.total in Blood | 0.848 |  |
| 3050746 | Hematocrit [Volume Fraction] of Blood by Estimated | 0.846 |  |
| 40762351 | Hemoglobin [Moles/volume] in Blood | 0.846 |  |
| 3028134 | Hemoglobin [Presence] in Stool from gastrointestinal --5th specimen | 0.845 |  |
| 3024622 | Hemoglobin [Presence] in Stool from gastrointestinal --2nd specimen | 0.845 | 585 |
| 42869618 | Hemoglobin F/Hemoglobin.total [Pure mass fraction] in Blood by Kleihauer-Betke method | 0.844 |  |
| 3003515 | Hemoglobin F/Hemoglobin.total in Blood by Kleihauer-Betke method | 0.842 | 1616 |
| 3005720 | Hemoglobin [Presence] in Stool from gastrointestinal --6th specimen | 0.842 |  |
| 3027299 | Hemoglobin [Presence] in Stool from gastrointestinal --4th specimen | 0.841 |  |
| 3041251 | HLA-B [Interpretation] by NAA with probe detection | 0.840 |  |
| 3024731 | MCV [Entitic mean volume] in Red Blood Cells | 0.839 | 34 |
| 3040522 | Hemoglobin M [Presence] in Blood | 0.833 |  |
| 40759161 | Methemoglobin [Moles/volume] in Blood | 0.833 |  |
| 3966697 | HLA-DQA1 SSO panel - Blood or Tissue by NAA with probe detection | 0.832 |  |
| 3051832 | Hemoglobin F/Hemoglobin.total in Blood by Electrophoresis alkaline (pH 8.9) | 0.832 |  |
| 3035970 | Hemoglobin Denver [Presence] in Blood | 0.831 |  |
| 3017572 | Hemoglobin A2 [Presence] in Blood | 0.831 |  |
| 36032094 | Hemoglobin A1c/Hemoglobin.total in DBS | 0.827 |  |
| 40758858 | Erythrocytes.fetal/Erythrocytes [Ratio] in Blood by Flow cytometry (FC) | 0.823 |  |
| 646927 | Hemoglobin [Measurement] in Stool from gastrointestinal | 0.823 |  |
| 3051554 | Hemoglobin F/Hemoglobin.total in DBS | 0.821 |  |
| 648666 | Hemoglobin F [Measurement] in Blood | 0.821 |  |
| 21491431 | HLA-B*58:01 [Presence] in Blood or Tissue | 0.820 |  |
| 3036779 | HLA-B27 [Presence] by NAA with probe detection | 0.819 | 1136 |
| 3029461 | Hemoglobin [Mass/volume] in Arterial cord blood by calculation | 0.818 |  |
| 3049858 | Reticulocyte mean volume [Entitic volume] in Reticulocytes | 0.817 |  |
| 36032168 | HLA-A and B and C (class I) typing panel - Blood or Tissue by High resolution | 0.816 |  |
| 46236302 | HLA-C [Type] by High resolution typing | 0.815 |  |
| 36032421 | HLA-DP and DQ and DR (class II) typing panel - Blood or Tissue by High resolution | 0.814 |  |
| 3024004 | Hemopexin [Mass/volume] in Urine | 0.814 |  |
| 3014051 | Protein [Presence] in Urine by Test strip | 0.813 | 99 |
| 3011066 | Myoglobin [Mass/volume] in Urine | 0.813 |  |
| 1259917 | HLA-DPB1+DPA1 Typing panel - Blood or Tissue | 0.810 |  |
| 36659666 | Hemoglobin panel - Blood by HPLC | 0.807 |  |
| 21491432 | HLA-A*31:01 [Presence] in Blood or Tissue | 0.807 |  |
| 40760912 | Occult blood panel - Stool by Immunoassay | 0.806 |  |
| 3011470 | Myoglobin [Presence] in Urine | 0.806 | 1264 |
| 3029937 | Albumin [Presence] in Urine by Test strip | 0.806 |  |
| 3031463 | HLA Ab [Identifier] in Serum or Plasma | 0.805 |  |
| 3041041 | Hemoglobin [Mass/volume] in Cord blood | 0.802 |  |
| 3009261 | Glucose [Presence] in Urine by Test strip | 0.799 | 309 |
| 36031422 | HLA-DP and DQ and DR (class II) typing panel - Blood or Tissue from Donor by High resolution | 0.799 |  |
| 36031258 | HLA-A and B and C (class I) typing panel - Blood or Tissue from Donor by High resolution | 0.798 |  |
| 3003309 | Hemoglobin A1c/Hemoglobin.total in Blood by Electrophoresis | 0.795 |  |
| 3007998 | Deoxyhemoglobin/Hemoglobin.total in Capillary blood | 0.794 |  |
| 42869631 | Hemoglobin A/Hemoglobin.total [Pure mass fraction] in Blood | 0.794 |  |
| 40762110 | HLA-DPB1 [Type] by High resolution | 0.794 |  |
| 3031806 | HLA-B*57:01 [Presence] in Specimen | 0.793 |  |
| 3016536 | HLA Ag present [Identifier] | 0.792 |  |
| 36031573 | HLA-A and B and C (class I) typing panel - Blood or Tissue by Low resolution | 0.789 |  |
| 36659964 | Hemoglobin HPLC and electrophoresis panel - Blood | 0.789 |  |
| 3034639 | Hemoglobin A1c [Mass/volume] in Blood | 0.787 |  |
| 36032264 | HLA-Bw [Type] | 0.787 |  |
| 3015789 | Blood group antigens present [Identifier] in Blood | 0.787 |  |
| 40760418 | HLA-DQB1 [Type] by High resolution | 0.783 |  |
| 36660223 | HLA-DQA1 and HLA-DQB1 typing panel - Blood or Tissue by Molecular genetics method | 0.782 |  |
| 36032108 | HLA-DP and DQ and DR (class II) typing panel - Blood or Tissue by Low resolution | 0.782 |  |
| 3032868 | Hemoglobin electrophoresis panel in Blood | 0.780 |  |
| 42869632 | Hemoglobin A/Hemoglobin.total [Pure mass fraction] in Blood by HPLC | 0.779 |  |
| 36031724 | HLA-A and B and C (class I) typing panel - Blood or Tissue from Donor by Low resolution | 0.777 |  |
| 36031353 | HLA-DP and DQ and DR (class II) typing panel - Blood or Tissue from Donor by Low resolution | 0.775 |  |
| 3040316 | HLA-DRB1 SBT [Type] in Specimen by High resolution | 0.775 |  |
| 3043317 | HLA-DQB1 SBT [Type] by High resolution | 0.775 |  |
| 1259656 | HLA-DPB1+DPA1 Typing panel - Blood or Tissue from Donor | 0.774 |  |
| 3001643 | Hemoglobin and Hematocrit panel - Blood | 0.770 |  |
| 42869627 | Hemoglobin A2/Hemoglobin.total [Pure mass fraction] in Blood | 0.767 |  |
| 3047015 | HLA-C SBT [Type] by High resolution | 0.767 |  |
| 40762352 | Hemoglobin A1c/Hemoglobin.total standardized per IFCC-RMP for CDT in Blood | 0.767 |  |
| 46236981 | HLA-A and B and DRB and DQB1 panel [Type] - Blood or Tissue by Low resolution | 0.764 |  |
| 3043232 | HLA-B SBT [Type] by High resolution | 0.764 |  |
| 40760409 | HLA-A [Type] by High resolution | 0.763 |  |
| 46236309 | HLA-C IgG Ab [Identifier] in Serum or Plasma by Immunoassay | 0.763 |  |
| 3039385 | Mean sphered cell volume [Entitic volume] in Red Blood Cells | 0.763 |  |
| 46234693 | Fetal blood [Volume] in Blood by Flow cytometry (FC) | 0.763 |  |
| 3002888 | Erythrocyte distribution width [Entitic volume] | 0.761 |  |
| 3029589 | HLA-B*57:01 [Presence] | 0.759 |  |
| 3001289 | Erythrocyte mean corpuscular diameter [Length] | 0.758 |  |
| 3026777 | HLA-C [Type] | 0.756 |  |
| 3001123 | Platelet [Entitic mean volume] in Blood | 0.753 |  |
| 1259758 | HLA-B gene.g.31431780T>G [Presence] in Blood or Tissue by Molecular genetics method | 0.753 |  |
| 3023599 | MCV [Entitic mean volume] in Red Blood Cells by Automated count | 0.752 | 17 |
| 3010808 | HLA Ag absent [Identifier] | 0.749 |  |
| 3037653 | Hemoglobin A2/Hemoglobin.total in Blood by HPLC | 0.748 |  |
| 40760416 | HLA-Cw [Type] by High resolution | 0.748 |  |
| 44816651 | Blood group antigens present [Identifier] in Blood by IAT | 0.748 |  |
| 3031927 | Hepatitis C virus genotype [Identifier] in Tissue by NAA with probe detection | 0.746 |  |
| 3015745 | Hemoglobin F [Presence] in Blood | 0.745 |  |
| 3040466 | Hemoglobin F [Presence] in Specimen by Apt-Downey method | 0.744 |  |
| 36032157 | HLA-Bw [Type] in Donor | 0.742 |  |
| 646164 | Blasts/Cells in Blood by Flow cytometry (FC) | 0.741 |  |
| 3008778 | Blood group antigens present [Identifier] in Blood product unit | 0.739 |  |
| 3033065 | Occult blood panel - Gastric fluid | 0.739 |  |
| 46236307 | HLA-A IgG Ab [Identifier] in Serum or Plasma by Immunoassay | 0.737 |  |
| 36660016 | HLA-C IgG Ab [Identifier] in Serum or Plasma by Flow cytometry (FC) | 0.735 |  |
| 3000061 | Hemoglobin F [Presence] in Blood by Kleihauer-Betke method | 0.735 | 984 |
| 46236308 | HLA-B IgG Ab [Identifier] in Serum or Plasma by Immunoassay | 0.733 |  |
| 649102 | HLA-B27 [Measurement] in Blood or Tissue | 0.732 |  |
| 3021329 | Hemoglobin F [Presence] in Specimen | 0.731 |  |
| 46236312 | HLA-DR IgG Ab [Identifier] in Serum or Plasma by Immunoassay | 0.730 |  |
| 3004018 | Blood group antigens present [Identifier] on Red Blood Cells from Donor | 0.730 |  |
| 40761014 | Hemoglobin [Presence] in Stool from gastrointestinal lower by Immunoassay --1st specimen | 0.729 |  |
| 3053003 | Hepatitis C virus genotype [Identifier] in Blood by NAA with probe detection | 0.729 |  |
| 3026811 | Hemoglobin F [Presence] in Meconium by Apt-Downey method | 0.728 |  |
| 3043111 | Platelet mean volume [Entitic volume] in Blood by Automated count | 0.728 | 149 |
| 1617137 | HLA-A and B and C (class I) and HLA-DP and DQ and DR (class II) Ab [Identifier] in Serum or Plasma | 0.728 |  |
| 36660605 | HLA-DRB1 IgG Ab [Identifier] in Serum or Plasma by Flow cytometry (FC) | 0.727 |  |
| 3007514 | Hepatitis B virus DNA [Presence] in Tissue by NAA with probe detection | 0.727 |  |
| 36659826 | HLA-DPB1 IgG Ab [Identifier] in Serum or Plasma by Flow cytometry (FC) | 0.727 |  |
| 3012323 | Lymphocytes/Leukocytes in Blood by Flow cytometry (FC) | 0.726 |  |
| 3006115 | Hemoglobin F [Presence] in Gastric fluid by Apt-Downey method | 0.726 |  |
| 36659707 | HLA-A IgG Ab [Identifier] in Serum or Plasma by Flow cytometry (FC) | 0.725 |  |
| 36204236 | Herpes virus 8 DNA [Presence] in Tissue by NAA with probe detection | 0.725 |  |
| 3046057 | HTLV II DNA [Presence] in Blood by NAA with probe detection | 0.723 |  |
| 3006143 | HLA-A+B+Bw [Type] | 0.723 |  |
| 3032435 | Parvovirus B19 DNA [Presence] in Blood by NAA with probe detection | 0.721 |  |
| 3025311 | HLA-B [Type] | 0.721 |  |
| 3029466 | Herpes virus 6 DNA [Presence] in Tissue by NAA with probe detection | 0.720 |  |
| 36031803 | HLA-C [Type] in Donor | 0.720 |  |
| 40759611 | Hemoglobin [Presence] in Stool from gastrointestinal lower by Immunoassay --2nd specimen | 0.719 | 882 |
| 1092441 | Hematocrit [Pure volume fraction] of Blood by calculation | 0.719 |  |
| 40767142 | KIR3DP1 gene full variant [Presence] in Blood or Tissue by Molecular genetics method | 0.718 |  |
| 3034043 | HLA-Cw [Type] | 0.716 |  |
| 42869586 | Hematocrit [Pure volume fraction] of Capillary blood | 0.716 |  |
| 3049862 | Hemoglobin pattern [Interpretation] in Blood by HPLC | 0.716 |  |
| 3050723 | Fetal blood [Volume] by Kleihauer-Betke method | 0.716 |  |
| 40764962 | XXX microorganism DNA [Identifier] in Serum or Plasma by NAA with probe detection | 0.715 |  |
| 3030834 | Platelet genotype [Identifier] in Blood | 0.714 |  |
| 42869588 | Hematocrit [Pure volume fraction] of Blood by Automated count | 0.714 |  |
| 645786 | HLA-A and B and C (class I) Ab.IgG present [Identifier] in Serum or Plasma by Immunoassay | 0.714 |  |
| 40759612 | Hemoglobin [Presence] in Stool from gastrointestinal lower by Immunoassay --3rd specimen | 0.713 | 883 |
| 40767141 | KIR gene allele 2DP1 [Presence] in Blood or Tissue by Molecular genetics method | 0.711 |  |
| 3024563 | HBA1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.710 |  |
| 40767137 | KIR gene allele 3DL1 [Presence] in Blood or Tissue by Molecular genetics method | 0.710 |  |
| 44816652 | Blood group antigens present [Identifier] in Blood by Immediate spin | 0.708 |  |
| 1989112 | Hemoglobinopathy panel | 0.708 |  |
| 40763941 | Hemoglobin [Mass/volume] in Blood from Fetus | 0.707 |  |
| 36305192 | Free hemoglobin and oxyhemoglobin panel - Plasma | 0.706 |  |
| 3031412 | Hemoglobin.other/Hemoglobin.total in Blood by HPLC | 0.704 |  |
| 1260092 | Basic metabolic with hemoglobin and hematocrit panel - Blood | 0.703 |  |
| 3048591 | Protein fractions 3 panel - Serum or Plasma | 0.700 |  |
| 647542 | Bacteria and yeast DNA [Identifier] in Peripheral blood by NAA with probe detection | 0.700 |  |
| 40767138 | KIR gene allele 3DL2 [Presence] in Blood or Tissue by Molecular genetics method | 0.699 |  |
| 3017154 | Hemoglobin A [Units/volume] in Blood by Electrophoresis | 0.692 |  |
| 3004673 | Hemoglobin I [Presence] in Blood by Electrophoresis acid (pH 6.3) | 0.691 |  |
| 3046708 | Hemoglobin E/Hemoglobin.total in Blood by HPLC | 0.691 |  |
| 3046405 | Hemoglobin D/Hemoglobin.total in Blood by HPLC | 0.690 |  |
| 3029285 | HLA Ab [Type] in Serum | 0.690 |  |
| 3045566 | Hemoglobin C/Hemoglobin.total in Blood by HPLC | 0.689 |  |
| 3032260 | Hemoglobin pattern [Interpretation] in Blood by HPLC Narrative | 0.688 | 732 |
| 3006988 | Hemoglobin I [Presence] in Blood by Electrophoresis alkaline (pH 8.9) | 0.686 |  |
| 3045807 | Hemoglobin S/Hemoglobin.total in Blood by HPLC | 0.682 |  |
| 3000429 | Cryoglobulin type [Identifier] in Serum by Electrophoresis | 0.680 |  |
| 3044997 | Hemoglobin A [Presence] in Blood by Electrophoresis | 0.680 |  |
| 3023314 | Hematocrit [Volume Fraction] of Blood by Automated count | 0.677 | 14 |
| 40758900 | Erythrocytes [#/volume] in Amniotic fluid | 0.677 |  |
| 44786642 | Hemoglobin.other [Type] in Blood | 0.677 |  |
| 3038533 | Hemoglobin H [Mass/volume] in Blood by Electrophoresis | 0.675 |  |
| 36031489 | HLA-A [Type] in Donor | 0.674 |  |
| 3008430 | Hemoglobin A region [Presence] in Blood by Electrophoresis alkaline (pH 8.9) | 0.672 |  |
| 3012892 | Hematocrit [Volume Fraction] of Cord blood | 0.670 |  |
| 3013752 | Hematocrit [Volume Fraction] of Blood by Impedance | 0.668 | 164 |
| 40770429 | Erythrocytes [#/volume] in Pleural fluid from Fetus | 0.668 |  |
| 44787097 | Normoblasts [#/volume] in Blood from Fetus | 0.666 |  |
| 3041908 | Hemoglobin E [Presence] in Blood by Electrophoresis | 0.666 |  |
| 40765002 | Hematocrit [Volume Fraction] of Blood from Fetus by Automated count | 0.664 |  |
| 3053000 | Hemoglobin pattern [Interpretation] in Blood by Electrophoresis | 0.664 |  |
| 3017300 | Hemoglobin Hope [Presence] in Blood by Electrophoresis acid (pH 6.3) | 0.659 |  |
| 21491353 | Hemoglobin pattern [Interpretation] in Blood by Capillary electrophoresis (CE) | 0.643 |  |
| 42869436 | Hemoglobinopathies conditions suspected [Identifier] in DBS | 0.635 |  |
| 3024409 | Hemoglobin Lepore [Presence] in Blood by Electrophoresis alkaline (pH 8.9) | 0.634 |  |
| 3023862 | Hemoglobin Lepore [Presence] in Blood by Electrophoresis acid (pH 6.3) | 0.633 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 2100 | ab-hb-co | % | 100% | name+unit+values | 287747 | 0 | [0.4, 0.69, 0.86, 1, 1.15, 1.3, 1.48, 1.72, 2.12] |  | Arterial blood |  | Carboxyhemoglobin/Hemoglobin.total [Mass Ratio] in Arterial blood |
| 2101 | ab-hb-co |  | 0% | name | 601 | 100 |  |  | Arterial blood |  | Carboxyhemoglobin/Hemoglobin.total [Mass Ratio] in Arterial blood |
| 2102 | ab-hb-met | % | 100% | name+unit+values | 290833 | 0 | [0.16, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.96, 1.18] |  | Arterial blood |  | Methemoglobin/Hemoglobin.total [Mass Ratio] in Arterial blood |
| 2103 | ab-hb-met |  | 0% | name+values | 523 | 100 | [-1, -0.6, -0.27, -0.06, 0.1, 0.2, 0.3, 0.4, 0.9] |  | Arterial blood |  | Methemoglobin/Hemoglobin.total [Mass Ratio] in Arterial blood |
| 2104 | ab-hb-vt | g/l | 100% | name+unit+values | 225 | 0 | [111.19, 121, 130.27, 136.29, 140, 145.22, 150.6, 157.19, 167.12] |  | Arterial blood |  | Hemoglobin [Mass/volume] in Arterial blood |
| 2105 | ab-hkr | osuus | 77% | name+unit+values | 864 | 0 | [0.3, 0.32, 0.35, 0.37, 0.39, 0.41, 0.42, 0.45, 0.47] |  | Arterial blood |  | Hematocrit [Volume Fraction] in Arterial blood |
| 2106 | ab-hkr |  | 23% | name+values | 263 | 100 | [0.31, 0.34, 0.36, 0.38, 0.4, 0.41, 0.42, 0.45, 0.47] |  | Arterial blood |  | Hematocrit [Volume Fraction] in Arterial blood |
| 2107 | b-ghb-a1c | % | 87% | name+unit+values | 87878 | 0 | [5.2, 5.42, 5.59, 5.73, 5.91, 6.13, 6.47, 7.08, 8.13] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2108 | b-ghb-a1c | mmol | 0% | name+unit | 50 | 0 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2109 | b-ghb-a1c | mmol/mol | 2% | name+unit+values | 2333 | 0 | [37.33, 39.77, 41.82, 43.61, 45.59, 48.88, 52.44, 59, 68.33] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2110 | b-ghb-a1c |  | 11% | name | 11089 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2111 | b-ghb-a1c,tk | % | 100% | name+unit+values | 5304 | 0 | [5.43, 5.76, 6.16, 6.59, 7.03, 7.45, 7.9, 8.45, 9.34] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2112 | b-ghb-a1cv | mmol/mol | 98% | name+unit+values | 346 | 0 | [41.33, 44.54, 47.42, 50.55, 53.09, 56.35, 59.4, 64.46, 73.63] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2113 | b-ghb-a1cv |  | 2% | name | 6 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2114 | b-ghba1c | % | 99% | name+unit+values | 3607 | 0 | [5.39, 5.56, 5.73, 5.9, 6.1, 6.4, 6.8, 7.38, 8.29] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2115 | b-ghba1c |  | 1% | name | 36 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2116 | b-ghba1c- | % | 100% | name+unit | 123 | 0 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2117 | b-ghba1c-oma | % | 97% | name+unit+values | 360 | 0 | [5.7, 5.9, 6, 6.2, 6.4, 6.67, 6.91, 7.42, 8.16] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2118 | b-ghba1c-oma |  | 3% | name | 13 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2119 | b-ghba1c/ | % | 98% | name+unit+values | 566 | 0.35 | [5.6, 5.83, 6, 6.19, 6.39, 6.63, 6.84, 7.16, 7.71] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2120 | b-ghba1c/ |  | 2% | name | 11 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2121 | b-ghba1c/p | % | 71% | name+unit+values | 506 | 0 | [5.93, 6.26, 6.57, 6.86, 7.1, 7.44, 7.84, 8.32, 9.4] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2122 | b-ghba1c/p |  | 29% | name+values | 206 | 100 | [5.97, 6.26, 6.51, 6.72, 7.01, 7.3, 7.7, 8.34, 8.93] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2123 | b-ghba1cp | % | 100% | name+unit+values | 4868 | 0 | [5.97, 6.3, 6.58, 6.88, 7.16, 7.46, 7.8, 8.23, 8.9] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2124 | b-ghba1cp |  | 0% | name | 13 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2125 | b-ghba1cv |  | 100% | name | 423 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2126 | b-ghba1cvt |  | 100% | name | 135 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2127 | b-hb-a1c | % | 88% | name+unit+values | 62531 | 0 | [5.29, 5.44, 5.6, 5.77, 5.95, 6.17, 6.48, 6.96, 7.84] | B -Hemoglobiini-A1C, glykoitunut | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2128 | b-hb-a1c | %/mmol | 0% | name+unit | 29 | 0 |  | B -Hemoglobiini-A1C, glykoitunut | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2129 | b-hb-a1c | mmol/l | 0% | name+unit | 13 | 7.69 |  | B -Hemoglobiini-A1C, glykoitunut | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2130 | b-hb-a1c | mmol/mol | 11% | name+unit+values | 7621 | 0 | [34.01, 36.12, 37.89, 39.5, 41.2, 43.55, 46.81, 52.53, 62.2] | B -Hemoglobiini-A1C, glykoitunut | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2131 | b-hb-a1c |  | 2% | name | 1216 | 100 |  | B -Hemoglobiini-A1C, glykoitunut | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2132 | b-hb-co | % | 90% | name+unit+values | 82164 | 0 | [0.89, 1.18, 1.38, 1.56, 1.71, 1.88, 2.05, 2.26, 2.63] | B -Hemoglobiini, hiilimonoksidi | Blood |  | Carboxyhemoglobin/Hemoglobin.total [Mass Ratio] in Blood |
| 2133 | b-hb-co |  | 10% | name+values | 9154 | 100 | [-0.38, -0.21, -0.17, -0.1, 0.02, 1, 1, 1, 1.99] | B -Hemoglobiini, hiilimonoksidi | Blood |  | Carboxyhemoglobin/Hemoglobin.total [Mass Ratio] in Blood |
| 2134 | b-hb-co. | % | 99% | name+unit+values | 1009 | 0 | [1.01, 1.42, 1.61, 1.79, 1.94, 2.14, 2.31, 2.51, 2.86] |  | Blood |  | Carboxyhemoglobin/Hemoglobin.total [Mass Ratio] in Blood |
| 2135 | b-hb-co. |  | 1% | name | 9 | 100 |  |  | Blood |  | Carboxyhemoglobin/Hemoglobin.total in Blood |
| 2136 | b-hb-ef |  | 100% | name | 124 | 100 |  | B -Hemoglobiini, elektroforeesi, verestä | Blood |  | Hemoglobin.variants [Identifier] in Blood by Electrophoresis |
| 2137 | b-hb-f | % | 52% | name+unit+values | 609 | 0.49 | [0, 0.92, 2.09, 5.89, 14.57, 22.26, 24.76, 27.04, 30.81] | B -Hemoglobiini, fetaali | Blood |  | Hemoglobin F/Hemoglobin.total [Mass Ratio] in Blood |
| 2138 | b-hb-f |  | 48% | name | 572 | 100 |  | B -Hemoglobiini, fetaali | Blood |  | Hemoglobin F/Hemoglobin.total in Blood |
| 2139 | b-hb-f-vr | % | 22% | name+unit | 24 | 0 |  | B -Hemoglobiini, fetaali, värjäys | Blood | Staining | Hemoglobin F/Hemoglobin.total [Mass Ratio] in Blood by Stain |
| 2140 | b-hb-f-vr |  | 78% | name | 84 | 100 |  | B -Hemoglobiini, fetaali, värjäys | Blood | Staining | Hemoglobin F/Hemoglobin.total in Blood by Stain |
| 2141 | b-hb-fr |  | 100% | name | 398 | 100 |  | B -Hemoglobiini, fraktiot | Blood | Fractions | Hemoglobin fractions panel - Blood |
| 2142 | b-hb-hoi |  | 100% | name+values | 230 | 100 | [103.94, 111.88, 117.74, 122.95, 126.96, 132.1, 135.84, 143.2, 148.99] |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2143 | b-hb-ief | form | 3% | name+unit | 10 | 0 |  | B -Hemoglobiini, isoelektrinen fokusointi | Blood | Isoelectric focusing | Hemoglobin.variants [Identifier] in Blood by Isoelectric focusing |
| 2144 | b-hb-ief |  | 97% | name | 298 | 100 |  | B -Hemoglobiini, isoelektrinen fokusointi | Blood | Isoelectric focusing | Hemoglobin.variants [Identifier] in Blood by Isoelectric focusing |
| 2145 | b-hb-met | % | 90% | name+unit+values | 81133 | 0 | [0.45, 0.62, 0.79, 0.9, 1, 1.1, 1.2, 1.3, 1.47] | B -Methemoglobiini | Blood |  | Methemoglobin/Hemoglobin.total [Mass Ratio] in Blood |
| 2146 | b-hb-met |  | 10% | name+values | 8996 | 100 | [-0.9, -0.36, -0.3, -0.2, -0.1, -0.1, -0.1, 0.48, 0.8] | B -Methemoglobiini | Blood |  | Methemoglobin/Hemoglobin.total [Mass Ratio] in Blood |
| 2147 | b-hb-met. | % | 99% | name+unit+values | 1016 | 0 | [0.63, 0.83, 0.94, 1.06, 1.11, 1.2, 1.3, 1.4, 1.6] |  | Blood |  | Methemoglobin/Hemoglobin.total [Mass Ratio] in Blood |
| 2148 | b-hb-met. |  | 1% | name | 10 | 100 |  |  | Blood |  | Methemoglobin/Hemoglobin.total in Blood |
| 2149 | b-hb-o | g/l | 14% | name+unit | 36 | 13.89 |  |  | Blood | Qualitative test (also semi-quantitative) | Hemoglobin [Presence] in Blood |
| 2150 | b-hb-o |  | 86% | name+values | 229 | 100 | [95.33, 106.5, 114.78, 121.31, 126.79, 131.45, 137.03, 142.44, 148.67] |  | Blood | Qualitative test (also semi-quantitative) | Hemoglobin [Presence] in Blood |
| 2151 | b-hb-poc | g/l | 20% | name+unit | 26 | 3.85 |  |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2152 | b-hb-poc |  | 80% | name+values | 106 | 100 | [109, 115.5, 120.67, 126.17, 128.33, 131.5, 135, 137.75, 145] |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2153 | b-hb-pt | g/l | 80% | name+unit+values | 649 | 0 | [100.43, 115.06, 121.84, 129.26, 133.9, 138.93, 143.78, 148.8, 154.91] |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2154 | b-hb-pt |  | 20% | name+values | 166 | 100 | [101.8, 109.84, 119.26, 127.38, 133.79, 137.87, 143.9, 152.16, 160.2] |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2155 | b-hb-vt | g/l | 100% | name+unit+values | 4224 | 0 | [103.86, 114.44, 120.79, 126.22, 130.62, 135.07, 140.03, 145.79, 153.81] | B -Hemoglobiini, vieritutkimus | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2156 | b-hb-vt |  | 0% | name | 6 | 100 |  | B -Hemoglobiini, vieritutkimus | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2157 | b-hba1c | % | 0% | name+unit+values | 847 | 0 | [5.33, 5.59, 5.76, 5.92, 6.09, 6.4, 6.81, 7.45, 8.49] | B -Hemoglobiini-A1c | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2158 | b-hba1c | form | 0% | name+unit | 16 | 0 |  | B -Hemoglobiini-A1c | Blood |  | Hemoglobin A1c/Hemoglobin.total [Identifier] in Blood |
| 2159 | b-hba1c | mmol | 0% | name+unit+values | 1356 | 0 | [34.05, 36, 37.63, 39.08, 40.8, 42.57, 45.91, 51.48, 61.02] | B -Hemoglobiini-A1c | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2160 | b-hba1c | mmol/l | 0% | name+unit+values | 135 | 0.74 | [31.02, 33, 34, 35, 36, 37, 38, 39, 42] | B -Hemoglobiini-A1c | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2161 | b-hba1c | mmol/m | 0% | name+unit+values | 2831 | 0 | [32.52, 34.15, 35.7, 37.07, 38.51, 40.34, 43, 48.76, 59.85] | B -Hemoglobiini-A1c | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2162 | b-hba1c | mmol/ml | 0% | name+unit+values | 138 | 0 | [32, 33.68, 34.75, 35.94, 37.85, 38, 39.68, 41.38, 43] | B -Hemoglobiini-A1c | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2163 | b-hba1c | mmol/mol | 93% | name+unit+values | 1976825 | 0 | [33.05, 35.18, 36.97, 38.1, 39.99, 42.16, 45.07, 50.32, 60.31] | B -Hemoglobiini-A1c | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2164 | b-hba1c |  | 6% | name | 133002 | 100 |  | B -Hemoglobiini-A1c | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2165 | b-hba1c,t |  | 100% | name+values | 10329 | 100 | [28.69, 39.63, 43.09, 47.24, 51.82, 56.59, 61.9, 68.13, 77.56] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2166 | b-hba1c,tk | mmol/mol | 100% | name+unit+values | 7907 | 0.01 | [35.82, 39.36, 43.46, 47.75, 52.16, 56.55, 61.35, 67.21, 76.08] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2167 | b-hba1c-o |  | 100% | name+values | 337 | 100 | [6.05, 6.44, 6.78, 7.33, 7.97, 10.13, 38.6, 48.91, 61.53] |  | Blood | Qualitative test (also semi-quantitative) | Hemoglobin A1c/Hemoglobin.total [Presence] in Blood |
| 2168 | b-hba1c-om |  | 100% | name | 127 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2169 | b-hba1c-oma |  | 100% | name+values | 440 | 100 | [39, 41, 42, 43.9, 46, 49.06, 51.84, 56.91, 65.06] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2170 | b-hba1c-p | % | 14% | name+unit+values | 153 | 3.27 | [6.4, 6.72, 7.1, 7.6, 7.94, 8.2, 8.55, 9, 9.88] |  | Blood | Upright (standing) | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2171 | b-hba1c-p | mmol/mol | 81% | name+unit+values | 867 | 0.35 | [44.02, 49.67, 54.3, 58.25, 62.24, 65.89, 70.4, 74.81, 84.61] |  | Blood | Upright (standing) | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2172 | b-hba1c-p |  | 5% | name | 55 | 100 |  |  | Blood | Upright (standing) | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2173 | b-hba1c/p | mmol/mol | 35% | name+unit+values | 568 | 0 | [37.94, 40, 42, 43.91, 45.94, 49.31, 51.37, 54.5, 60.85] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2174 | b-hba1c/p |  | 65% | name | 1078 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2175 | b-hba1c/pi |  | 100% | name+values | 1172 | 100 | [40.12, 43.68, 47.04, 50.61, 53.4, 56.88, 61.12, 66.65, 76.14] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2176 | b-hba1chy | mmol/mol | 100% | name+unit+values | 261 | 0 | [41.44, 47.08, 50.41, 54.19, 57.44, 60.77, 65.08, 71.6, 82.33] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2177 | b-hba1cp | % | 10% | name+unit+values | 1574 | 0.19 | [5.77, 6.01, 6.21, 6.46, 6.69, 6.98, 7.32, 7.75, 8.45] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood |
| 2178 | b-hba1cp | mmol/mol | 89% | name+unit+values | 13769 | 0.02 | [40.97, 44.13, 47.25, 50.28, 53.07, 56.14, 59.73, 64.36, 71.61] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2179 | b-hba1cp |  | 0% | name | 60 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2180 | b-hba1cpi | mmol/mol | 100% | name+unit+values | 1299 | 0 | [37.79, 40.52, 42.7, 45.2, 48.39, 51.41, 55.01, 61.08, 69.91] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2181 | b-hba1cvt | % | 35% | name+unit+values | 7630 | 0 | [5.82, 6.13, 6.39, 6.65, 6.92, 7.24, 7.57, 8.02, 8.75] | B -Hemoglobiini-A1c, vieritutkimus | Blood |  | Hemoglobin A1c/Hemoglobin.total [Ratio] in Blood by Point-of-care |
| 2182 | b-hba1cvt | mmol | 0% | name+unit | 7 | 0 |  | B -Hemoglobiini-A1c, vieritutkimus | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood by Point-of-care |
| 2183 | b-hba1cvt | mmol/mol | 63% | name+unit+values | 13876 | 0.01 | [41.8, 45.73, 49.05, 52.33, 55.71, 59.15, 63.13, 68.18, 76.86] | B -Hemoglobiini-A1c, vieritutkimus | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood by Point-of-care |
| 2184 | b-hba1cvt |  | 3% | name | 591 | 100 |  | B -Hemoglobiini-A1c, vieritutkimus | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood by Point-of-care |
| 2185 | b-hbf-fc | % | 6% | name+unit | 16 | 0 |  | B -Immunofenotyypitys, fetaalihemoglobiini | Blood | Flow cytometry | Hemoglobin F/Hemoglobin.total [Mass Ratio] in Blood by Flow cytometry (FC) |
| 2186 | b-hbf-fc | form | 9% | name+unit | 24 | 0 |  | B -Immunofenotyypitys, fetaalihemoglobiini | Blood | Flow cytometry | Hemoglobin F identified in Blood by Flow cytometry (FC) |
| 2187 | b-hbf-fc |  | 84% | name | 215 | 100 |  | B -Immunofenotyypitys, fetaalihemoglobiini | Blood | Flow cytometry | Hemoglobin F/Hemoglobin.total in Blood by Flow cytometry (FC) |
| 2188 | b-hbfvol | ml | 9% | name+unit | 14 | 0 |  |  | Blood |  | Fetal blood [Volume] in Maternal blood |
| 2189 | b-hbfvol |  | 91% | name | 139 | 100 |  |  | Blood |  | Fetal blood [Volume] in Maternal blood |
| 2190 | b-hbhoi | g/l | 88% | name+unit+values | 496 | 0 | [97.88, 110.36, 119.68, 125.02, 129.72, 135.92, 143.92, 151.3, 159.16] |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2191 | b-hbhoi |  | 12% | name | 66 | 100 |  |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2192 | b-hbhplc |  | 100% | name | 308 | 100 |  |  | Blood |  | Hemoglobin.variants [Identifier] in Blood by HPLC |
| 2193 | b-hbpoc | g/l | 100% | name+unit+values | 639 | 0 | [97.85, 107.26, 112.9, 117.7, 122.88, 126.88, 132.06, 138.55, 147.12] |  | Blood |  | Hemoglobin [Mass/volume] in Blood |
| 2194 | b-hkr | % | 46% | name+unit+values | 5020904 | 0 | [29.67, 33.32, 36, 37.79, 39.16, 40.79, 42, 43.3, 45.13] | B -Erytrosyytit, tilavuusosuus | Blood |  | Hematocrit [Volume Fraction] in Blood |
| 2195 | b-hkr | fl | 0% | name+unit+values | 7243 | 0 | [84.54, 86.11, 87.23, 88.3, 89.15, 90.24, 91.28, 92.73, 94.69] | B -Erytrosyytit, tilavuusosuus | Blood |  | Erythrocyte mean corpuscular volume [Entitic volume] in Blood |
| 2196 | b-hkr | form | 0% | name+unit | 33 | 0 |  | B -Erytrosyytit, tilavuusosuus | Blood |  | Hematocrit [Identifier] in Blood |
| 2197 | b-hkr | l/l | 0% | name+unit+values | 3192 | 0 | [0.36, 0.38, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45, 0.46] | B -Erytrosyytit, tilavuusosuus | Blood |  | Hematocrit [Volume Fraction] in Blood |
| 2198 | b-hkr | ratio | 53% | name+unit+values | 5806054 | 0 | [0.31, 0.34, 0.36, 0.38, 0.4, 0.41, 0.42, 0.44, 0.46] | B -Erytrosyytit, tilavuusosuus | Blood |  | Hematocrit [Volume Fraction] in Blood |
| 2199 | b-hkr |  | 1% | name | 119384 | 100 |  | B -Erytrosyytit, tilavuusosuus | Blood |  | Hematocrit in Blood |
| 2200 | b-hkr.fol | % | 15% | name+unit | 28 | 0 |  |  | Blood |  | Hematocrit [Volume Fraction] in Blood |
| 2201 | b-hkr.fol |  | 85% | name+values | 153 | 100 | [0.36, 0.37, 0.39, 0.4, 0.41, 0.42, 0.43, 0.45, 0.46] |  | Blood |  | Hematocrit [Volume Fraction] in Blood |
| 2202 | b-hkrhoi | osuus | 10% | name+unit | 18 | 0 |  |  | Blood |  | Hematocrit [Volume Fraction] in Blood |
| 2203 | b-hkrhoi |  | 90% | name+values | 155 | 100 | [0.3, 0.32, 0.36, 0.38, 0.4, 0.42, 0.44, 0.46, 0.49] |  | Blood |  | Hematocrit [Volume Fraction] in Blood |
| 2204 | b-hkrp | % | 100% | name+unit+values | 1281 | 0 | [35.35, 37.88, 39.35, 40.46, 41.52, 42.63, 43.67, 45, 46.74] |  | Blood |  | Hematocrit [Volume Fraction] in Blood |
| 2205 | b-hkrp |  | 0% | name | 6 | 100 |  |  | Blood |  | Hematocrit in Blood |
| 2206 | b-hla-bw | form | 7% | name+unit | 44 | 0 |  |  | Blood |  | HLA-Bw antigen [Identifier] in Blood |
| 2207 | b-hla-bw |  | 93% | name | 611 | 100 |  |  | Blood |  | HLA-Bw antigen [Identifier] in Blood |
| 2208 | b-hla1mun |  | 100% | name | 828 | 100 |  |  | Blood |  | HLA typing [Identifier] in Blood |
| 2209 | b-hla1pk |  | 100% | name | 316 | 100 |  |  | Blood |  | HLA typing [Identifier] in Blood |
| 2210 | b-hla2frk |  | 100% | name | 124 | 100 |  |  | Blood |  | HLA typing [Identifier] in Blood |
| 2211 | b-hla2prk |  | 100% | name | 155 | 100 |  |  | Blood |  | HLA typing [Identifier] in Blood |
| 2212 | b-hlaabac |  | 100% | name | 120 | 100 |  | B -Abacavir-yliherkkyys, HLA-assosiaatio, DNA-tutkimus | Blood |  | HLA-B*57:01 allele [Presence] in Blood or Tissue by NAA with probe detection |
| 2213 | b-hlaad | form | 4% | name+unit | 65 | 0 |  | B -HLA-A, DNA-tutkimus | Blood |  | HLA-A [Identifier] in Blood or Tissue by NAA with probe detection |
| 2214 | b-hlaad |  | 96% | name | 1525 | 100 |  | B -HLA-A, DNA-tutkimus | Blood |  | HLA-A [Identifier] in Blood or Tissue by NAA with probe detection |
| 2215 | b-hlaadt | form | 6% | name+unit | 11 | 0 |  | B -HLA-A, DNA-tutkimus, tarkennettu | Blood |  | HLA-A high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2216 | b-hlaadt |  | 94% | name | 186 | 100 |  | B -HLA-A, DNA-tutkimus, tarkennettu | Blood |  | HLA-A high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2217 | b-hlaag |  | 100% | name | 126 | 100 |  |  | Blood |  | HLA antigen [Identifier] in Blood |
| 2218 | b-hlabd | form | 4% | name+unit | 66 | 0 |  | B -HLA-B, DNA-tutkimus | Blood |  | HLA-B [Identifier] in Blood or Tissue by NAA with probe detection |
| 2219 | b-hlabd |  | 96% | name | 1637 | 100 |  | B -HLA-B, DNA-tutkimus | Blood |  | HLA-B [Identifier] in Blood or Tissue by NAA with probe detection |
| 2220 | b-hlabdt | form | 5% | name+unit | 10 | 0 |  | B -HLA-B, DNA-tutkimus, tarkennettu | Blood |  | HLA-B high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2221 | b-hlabdt |  | 95% | name | 185 | 100 |  | B -HLA-B, DNA-tutkimus, tarkennettu | Blood |  | HLA-B high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2222 | b-hlabg |  | 100% | name | 126 | 100 |  |  | Blood |  | HLA-B antigen [Identifier] in Blood |
| 2223 | b-hlacdt | form | 5% | name+unit | 10 | 0 |  | B -HLA-C, DNA-tutkimus, tarkennettu | Blood |  | HLA-C high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2224 | b-hlacdt |  | 95% | name | 187 | 100 |  | B -HLA-C, DNA-tutkimus, tarkennettu | Blood |  | HLA-C high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2225 | b-hlacg |  | 100% | name | 117 | 100 |  |  | Blood |  | HLA-C antigen [Identifier] in Blood |
| 2226 | b-hladpb1g |  | 100% | name | 117 | 100 |  |  | Blood |  | HLA-DPB1 gene [Identifier] in Blood or Tissue by NAA with probe detection |
| 2227 | b-hladpbd | form | 5% | name+unit | 10 | 0 |  | B -HLA-DPB, DNA-tutkimus, tarkennettu | Blood |  | HLA-DPB1 high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2228 | b-hladpbd |  | 95% | name | 186 | 100 |  | B -HLA-DPB, DNA-tutkimus, tarkennettu | Blood |  | HLA-DPB1 high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2229 | b-hladqb1g |  | 100% | name | 117 | 100 |  |  | Blood |  | HLA-DQB1 gene [Identifier] in Blood or Tissue by NAA with probe detection |
| 2230 | b-hladqbd | form | 5% | name+unit | 10 | 0 |  | B -HLA-DQB, DNA-tutkimus, tarkennettu | Blood |  | HLA-DQB1 high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2231 | b-hladqbd |  | 95% | name | 184 | 100 |  | B -HLA-DQB, DNA-tutkimus, tarkennettu | Blood |  | HLA-DQB1 high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2232 | b-hladrb1g |  | 100% | name | 125 | 100 |  |  | Blood |  | HLA-DRB1 gene [Identifier] in Blood or Tissue by NAA with probe detection |
| 2233 | b-hladrbd | form | 4% | name+unit | 62 | 0 |  | B -HLA-DRB, DNA-tutkimus | Blood |  | HLA-DRB1 [Identifier] in Blood or Tissue by NAA with probe detection |
| 2234 | b-hladrbd |  | 96% | name | 1486 | 100 |  | B -HLA-DRB, DNA-tutkimus | Blood |  | HLA-DRB1 [Identifier] in Blood or Tissue by NAA with probe detection |
| 2235 | b-hladrld | form | 6% | name+unit | 10 | 0 |  | B -HLA-DRB, DNA-tutkimus, tarkennettu | Blood |  | HLA-DRB1 high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2236 | b-hladrld |  | 94% | name | 158 | 100 |  | B -HLA-DRB, DNA-tutkimus, tarkennettu | Blood |  | HLA-DRB1 high resolution typing [Identifier] in Blood or Tissue by NAA with probe detection |
| 2237 | b-hlamaks |  | 100% | name | 277 | 100 |  |  | Blood |  | HLA typing [Identifier] in Blood |
| 2238 | b-hlasyke |  | 100% | name | 348 | 100 |  |  | Blood |  | HLA typing [Identifier] in Blood |
| 2239 | b-hlatrb |  | 100% | name | 133 | 100 |  |  | Blood |  | HLA typing [Identifier] in Blood |
| 2240 | b-vthba1c | mmol/mol | 99% | name+unit+values | 1184 | 0.08 | [45.54, 50.5, 53.58, 56.3, 58.39, 61.04, 63.92, 68.87, 77.06] |  | Blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood by Point-of-care |
| 2241 | b-vthba1c |  | 1% | name | 8 | 100 |  |  | Blood |  | Hemoglobin A1c/Hemoglobin.total in Blood by Point-of-care |
| 2242 | cb-hb-hy | g/l | 100% | name+unit+values | 1578 | 0.19 | [98.91, 111.68, 118.7, 123.76, 129.35, 133.47, 138.3, 144.32, 152.78] |  | Capillary blood |  | Hemoglobin [Mass/volume] in Capillary blood |
| 2243 | cb-hb-v |  | 100% | name+values | 312 | 100 | [95.63, 107.52, 115.55, 122.44, 129.89, 134.53, 139.44, 145.94, 153.46] |  | Capillary blood | Free or unconjugated | Hemoglobin [Mass/volume] in Capillary blood |
| 2244 | cb-hba1cnla | mmol/mol | 68% | name+unit | 212 | 0 |  |  | Capillary blood |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Capillary blood |
| 2245 | cb-hba1cnla |  | 32% | name | 102 | 100 |  |  | Capillary blood |  | Hemoglobin A1c/Hemoglobin.total in Capillary blood |
| 2246 | f-hb-hum |  | 100% | name | 457 | 100 |  |  | Feces |  | Hemoglobin.human [Presence] in Stool |
| 2247 | f-hb-o |  | 100% | name | 2079 | 100 |  | F -Hemoglobiini (kval) | Feces | Qualitative test (also semi-quantitative) | Hemoglobin [Presence] in Stool |
| 2248 | f-hb-o2 |  | 100% | name | 146 | 100 |  |  | Feces |  | Hemoglobin [Presence] in Stool |
| 2249 | f-hb-o3 |  | 100% | name | 125 | 100 |  |  | Feces |  | Hemoglobin [Presence] in Stool |
| 2250 | f-hhb-1 |  | 100% | name | 400 | 100 |  |  | Feces |  | Hemoglobin.human [Presence] in Stool |
| 2251 | f-hhb-2 |  | 100% | name | 400 | 100 |  |  | Feces |  | Hemoglobin.human [Presence] in Stool |
| 2252 | f-hhb-o | estimate | 0% | name+unit | 106 | 0 |  | F -Hemoglobiini, ihmisen (kval) | Feces | Qualitative test (also semi-quantitative) | Hemoglobin.human [Presence] in Stool |
| 2253 | f-hhb-o | form | 0% | name+unit | 18 | 0 |  | F -Hemoglobiini, ihmisen (kval) | Feces | Qualitative test (also semi-quantitative) | Hemoglobin.human [Presence] in Stool |
| 2254 | f-hhb-o |  | 100% | name | 52037 | 100 |  | F -Hemoglobiini, ihmisen (kval) | Feces | Qualitative test (also semi-quantitative) | Hemoglobin.human [Presence] in Stool |
| 2255 | f-hhb-ox3 |  | 100% | name | 141 | 100 |  |  | Feces |  | Hemoglobin.human Occult Blood panel - Stool |
| 2256 | hba1c |  | 100% | name | 2374 | 100 |  |  |  |  | Hemoglobin A1c/Hemoglobin.total in Blood |
| 2257 | hoighb-a1c |  | 100% | name+values | 387 | 100 | [40.25, 44.21, 48.92, 53.87, 58.77, 64.48, 69.2, 76.02, 85.37] |  |  |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2258 | hoihba1c |  | 100% | name+values | 652 | 100 | [45.35, 49.99, 53.1, 56.13, 59.42, 63, 67.63, 72.67, 79.74] |  |  |  | Hemoglobin A1c/Hemoglobin.total [Molar ratio] in Blood |
| 2259 | mb-hb-co | % | 100% | name+unit+values | 574 | 0 | [0.79, 0.91, 1.08, 1.11, 1.2, 1.3, 1.43, 1.59, 1.82] |  |  |  | Carboxyhemoglobin/Hemoglobin.total [Mass Ratio] in Blood |
| 2260 | mb-hb-met | % | 100% | name+unit+values | 574 | 0 | [0.5, 0.6, 0.7, 0.71, 0.8, 0.9, 0.98, 1.08, 1.33] |  |  |  | Methemoglobin/Hemoglobin.total [Mass Ratio] in Blood |
| 2261 | u-hb-dec |  | 100% | name+values | 152 | 100 | [1034.47, 1050, 1065.3, 1082.98, 1121.64, 1184.46, 1367.25, 1689.47, 1915.55] |  | Urine |  | Hemoglobin [Mass/volume] in Urine |
| 2262 | u-hb-o | A | 0% | name+unit | 19 | 0 |  | U -Hemoglobiini (kval) | Urine | Qualitative test (also semi-quantitative) | Hemoglobin [Presence] in Urine |
| 2263 | u-hb-o | estimate | 0% | name+unit | 65 | 0 |  | U -Hemoglobiini (kval) | Urine | Qualitative test (also semi-quantitative) | Hemoglobin [Presence] in Urine |
| 2264 | u-hb-o |  | 100% | name+values | 350964 | 100 | [0, 0, 0, 0.02, 1, 1, 1.23, 2.66, 3.01] | U -Hemoglobiini (kval) | Urine | Qualitative test (also semi-quantitative) | Hemoglobin [Presence] in Urine by Test strip |
| 2265 | u-hb-o. |  | 100% | name | 23128 | 100 |  |  | Urine |  | Hemoglobin [Presence] in Urine |
| 2266 | vb-hb-co | % | 99% | name+unit+values | 63056 | 0 | [0.3, 0.59, 0.79, 0.94, 1.09, 1.26, 1.44, 1.7, 2.22] |  | Venous blood |  | Carboxyhemoglobin/Hemoglobin.total [Mass Ratio] in Venous blood |
| 2267 | vb-hb-co |  | 1% | name+values | 421 | 100 | [-0.6, -0.35, -0.2, -0.1, 0.25, 0.91, 1.19, 1.53, 2.3] |  | Venous blood |  | Carboxyhemoglobin/Hemoglobin.total [Mass Ratio] in Venous blood |
| 2268 | vb-hb-met | % | 99% | name+unit+values | 62766 | 0 | [0.2, 0.3, 0.4, 0.5, 0.6, 0.68, 0.78, 0.9, 1.09] |  | Venous blood |  | Methemoglobin/Hemoglobin.total [Mass Ratio] in Venous blood |
| 2269 | vb-hb-met |  | 1% | name | 329 | 100 |  |  | Venous blood |  | Methemoglobin/Hemoglobin.total [Mass Ratio] in Venous blood |
| 2270 | vb-hb-vt | 1 | 4% | name+unit | 40 | 0 |  |  | Venous blood |  | Hemoglobin [Mass/volume] in Venous blood |
| 2271 | vb-hb-vt | g/l | 72% | name+unit+values | 790 | 0 | [111.74, 124.93, 132.25, 138.24, 143.08, 147.41, 152.55, 158.57, 167] |  | Venous blood |  | Hemoglobin [Mass/volume] in Venous blood |
| 2272 | vb-hb-vt |  | 25% | name+values | 273 | 100 | [103.37, 120.62, 125.98, 130.71, 135.91, 139.96, 144.6, 150.76, 156.45] |  | Venous blood |  | Hemoglobin [Mass/volume] in Venous blood |
| 2273 | vb-hkr-vt | 1 | 27% | name+unit | 40 | 0 |  |  | Venous blood |  | Hematocrit [Volume Fraction] in Venous blood |
| 2274 | vb-hkr-vt |  | 73% | name | 110 | 100 |  |  | Venous blood |  | Hematocrit [Volume Fraction] in Venous blood |

