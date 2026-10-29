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
Here is group 111.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3006588 | Cancer Ag 15-3 [Units/volume] in Serum or Plasma | 0.982 | 734 |
| 3037551 | Cancer Ag 125 [Units/volume] in Serum or Plasma | 0.978 | 430 |
| 3022914 | Cancer Ag 19-9 [Units/volume] in Serum or Plasma | 0.977 | 677 |
| 3033236 | Creatine kinase.MB [Mass/volume] in Blood | 0.975 |  |
| 3020460 | C reactive protein [Mass/volume] in Serum or Plasma | 0.973 | 154 |
| 3051387 | C reactive protein [Mass/volume] in Capillary blood | 0.972 |  |
| 3000965 | C reactive protein [Presence] in Serum or Plasma | 0.971 | 1281 |
| 3038136 | Choriogonadotropin.beta subunit [Units/volume] in Serum or Plasma | 0.965 | 364 |
| 3029790 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma | 0.962 | 374 |
| 3018954 | Choriogonadotropin [Presence] in Urine | 0.958 | 184 |
| 3005785 | Creatine kinase.MB [Mass/volume] in Serum or Plasma | 0.955 | 111 |
| 40759040 | C peptide [Moles/volume] in Serum or Plasma --post meal | 0.949 |  |
| 42529199 | Cancer Ag 125 [Units/volume] in Serum or Plasma by Immunoassay | 0.945 |  |
| 42529200 | Cancer Ag 15-3 [Units/volume] in Serum or Plasma by Immunoassay | 0.944 |  |
| 3027089 | Cancer Ag 15-3 [Units/volume] in Body fluid | 0.943 |  |
| 3003245 | Complement C1 esterase inhibitor [Mass/volume] in Serum or Plasma | 0.942 | 1762 |
| 3027923 | C peptide [Moles/volume] in Serum or Plasma | 0.940 | 701 |
| 3002384 | Cancer Ag 125 [Units/volume] in Body fluid | 0.940 |  |
| 1091617 | C reactive protein [Mass/volume] in Serum, Plasma or Blood | 0.939 |  |
| 3020472 | Cancer Ag 19-9 [Units/volume] in Body fluid | 0.938 |  |
| 3019145 | Choriogonadotropin.beta subunit free [Mass/volume] in Serum or Plasma | 0.938 |  |
| 3019497 | Choriogonadotropin.beta subunit free [Moles/volume] in Serum or Plasma | 0.936 | 1065 |
| 3018171 | Choriogonadotropin [Units/volume] in Serum or Plasma | 0.932 | 252 |
| 3002368 | Cancer Ag 125 [Units/volume] in Serum or Plasma by Dilution | 0.932 |  |
| 42529201 | Cancer Ag 19-9 [Units/volume] in Serum or Plasma by Immunoassay | 0.932 |  |
| 3011465 | Choriogonadotropin.beta subunit free [Units/volume] in Serum or Plasma | 0.927 |  |
| 3003191 | Choriogonadotropin [Presence] in Serum or Plasma | 0.922 | 615 |
| 645470 | Cancer Ag 125 [Measurement] in Serum or Plasma | 0.920 |  |
| 645908 | Cancer Ag 15-3 [Measurement] in Serum or Plasma | 0.916 |  |
| 40758990 | Choriogonadotropin.beta subunit [Mass/volume] in Serum or Plasma | 0.912 |  |
| 42529209 | Creatine kinase.MB [Mass/volume] in Serum or Plasma by Immunoassay | 0.911 |  |
| 3016070 | Creatine kinase.MB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.910 |  |
| 3028461 | Complement total hemolytic CH50 [Units/volume] in Serum or Plasma | 0.910 | 952 |
| 3046071 | Choriogonadotropin.intact+Beta subunit [Units/volume] in Serum or Plasma | 0.909 |  |
| 3000337 | Cancer Ag 15-3 [Units/volume] in Pleural fluid | 0.908 |  |
| 3027160 | Cancer Ag 125 [Units/volume] in Pleural fluid | 0.907 |  |
| 3011996 | Choriogonadotropin.beta subunit [Moles/volume] in Serum or Plasma | 0.906 | 311 |
| 3024258 | Complement total hemolytic CH50 [Mass/volume] in Serum or Plasma | 0.905 |  |
| 3006044 | Creatine kinase.total/Creatine kinase.MB [Enzymatic activity ratio] in Serum or Plasma | 0.904 |  |
| 3036758 | Complement C1 esterase inhibitor [Mass/volume] in Body fluid | 0.903 |  |
| 3031327 | Cancer Ag 15-3 [Units/volume] in Peritoneal fluid | 0.901 |  |
| 1616400 | Cancer Ag 15-3 [Units/volume] in Aspirate | 0.901 |  |
| 40758988 | Choriogonadotropin.beta subunit free [Mass/volume] in Body fluid | 0.901 |  |
| 645803 | Choriogonadotropin.beta subunit [Measurement] in Serum or Plasma | 0.899 |  |
| 40759039 | C peptide [Mass/volume] in Serum or Plasma --post meal | 0.899 |  |
| 3008994 | Creatine kinase.BB [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.899 |  |
| 3016913 | Creatine kinase.MM [Enzymatic activity/volume] in Serum or Plasma by Electrophoresis | 0.897 |  |
| 647002 | Cancer Ag 19-9 [Measurement] in Serum or Plasma | 0.896 |  |
| 1616793 | Cancer Ag 125 [Units/volume] in Aspirate | 0.896 |  |
| 3032836 | C peptide [Moles/volume] in Serum or Plasma --fasting | 0.896 |  |
| 3030170 | Creatine kinase [Mass/volume] in Blood | 0.896 |  |
| 3032226 | Cancer Ag 19-9 [Units/volume] in Peritoneal fluid | 0.896 |  |
| 46234770 | C reactive protein [Moles/volume] in Serum or Plasma | 0.894 |  |
| 42870365 | C reactive protein [Mass/volume] in Blood by High sensitivity method | 0.893 |  |
| 3007220 | Creatine kinase [Enzymatic activity/volume] in Serum or Plasma | 0.893 | 90 |
| 3046743 | Choriogonadotropin [Presence] in Control Serum | 0.890 |  |
| 3008558 | Creatine kinase.MM/Creatine kinase.total in Serum or Plasma | 0.890 |  |
| 3002923 | Cancer Ag 125 [Units/volume] in Body fluid by Dilution | 0.889 |  |
| 3025483 | Cancer Ag 19-9 [Units/volume] in Pleural fluid | 0.888 |  |
| 3039655 | Complement C1 esterase inhibitor bound Ab [Mass/volume] in Serum or Plasma | 0.888 |  |
| 3016311 | Creatine kinase.MB/Creatine kinase.total in Serum or Plasma | 0.887 | 297 |
| 3015040 | Creatine kinase.BB/Creatine kinase.total in Serum or Plasma | 0.887 |  |
| 42529203 | Choriogonadotropin [Units/volume] in Serum or Plasma by Immunoassay | 0.887 |  |
| 3049479 | C peptide [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 0.886 |  |
| 1989343 | Cancer Ag 242 [Units/volume] in Serum or Plasma | 0.885 |  |
| 3030282 | Creatine kinase.total/Creatine kinase.MB [Enzymatic activity ratio] in Blood | 0.885 |  |
| 649335 | Creatine kinase.MB [Measurement] in Serum or Plasma | 0.885 |  |
| 1617235 | Cancer Ag 19-9 [Units/volume] in Aspirate | 0.884 |  |
| 3007835 | Cancer Ag 125 [Presence] in Serum or Plasma | 0.884 | 800 |
| 3010156 | C reactive protein [Mass/volume] in Serum or Plasma by High sensitivity method | 0.884 | 348 |
| 3028232 | Choriogonadotropin.beta subunit [Units/volume] in Body fluid | 0.883 |  |
| 646381 | Complement total hemolytic CH50 [Measurement] in Serum or Plasma | 0.883 |  |
| 40761619 | C peptide [Moles/volume] in Serum or Plasma --5 hours post dose glucose | 0.883 |  |
| 3039786 | Cancer Ag 125 [Units/volume] in Peritoneal fluid | 0.883 |  |
| 3031930 | Cancer Ag 15-3 [Units/volume] in Pericardial fluid | 0.882 |  |
| 3048845 | C peptide [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 0.880 |  |
| 3050109 | C peptide [Moles/volume] in Serum or Plasma --5 minutes post dose glucose | 0.879 |  |
| 3052365 | C peptide [Moles/volume] in Serum or Plasma --3 hours post dose glucose | 0.879 |  |
| 3004339 | Complement C1 esterase inhibitor.functional [Mass/volume] in Serum or Plasma | 0.879 |  |
| 3053231 | C peptide [Moles/volume] in Serum or Plasma --30 minutes post dose glucose | 0.878 |  |
| 3053233 | C peptide [Moles/volume] in Serum or Plasma --10 minutes post dose glucose | 0.877 |  |
| 40761606 | C peptide [Moles/volume] in Serum or Plasma --2.5 hours post dose glucose | 0.877 |  |
| 3052897 | Complement total hemolytic CH50 [Titer] in Serum or Plasma | 0.875 |  |
| 647911 | Choriogonadotropin.beta subunit free [Measurement] in Serum or Plasma | 0.874 |  |
| 43055396 | Creatine kinase.MM/Creatine kinase.total [Pure catalytic fraction] in Serum or Plasma by Electrophoresis | 0.873 |  |
| 648940 | C reactive protein [Measurement] in Serum or Plasma | 0.872 |  |
| 21492990 | Choriogonadotropin [Presence] in Urine by Rapid immunoassay | 0.871 |  |
| 3044022 | C peptide [Moles/volume] in Urine | 0.870 |  |
| 21492991 | Choriogonadotropin [Presence] in Serum by Rapid immunoassay | 0.870 |  |
| 1002102 | Choriogonadotropin.intact+Beta subunit [Mass/volume] in Serum or Plasma | 0.870 |  |
| 3965683 | Creatine kinase.MB [Moles/volume] in Serum or Plasma by Immunoassay | 0.869 |  |
| 3005901 | Choriogonadotropin.beta subunit free [Moles/volume] in Amniotic fluid | 0.868 |  |
| 3002818 | Complement C1s [Mass/volume] in Serum or Plasma | 0.867 |  |
| 36659861 | C peptide [Mass/volume] in Serum or Plasma --1 hour post meal | 0.867 |  |
| 43055399 | Creatine kinase.BB/Creatine kinase.total [Pure catalytic fraction] in Serum or Plasma by Electrophoresis | 0.866 |  |
| 3052003 | Choriogonadotropin.beta subunit free [Units/volume] in Body fluid | 0.866 |  |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.866 |  |
| 3030808 | C peptide [Moles/volume] in Serum or Plasma --6th specimen | 0.866 |  |
| 3015531 | Creatine kinase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.865 |  |
| 3031166 | Choriogonadotropin [Mass/volume] in Serum or Plasma | 0.865 |  |
| 3006742 | Cancer Ag 15-3 [Presence] in Serum or Plasma | 0.865 |  |
| 3050769 | C peptide [Moles/volume] in Serum or Plasma --pre dose glucose | 0.864 |  |
| 648986 | Creatine kinase.MM [Enzymatic activity/volume] in DBS | 0.864 |  |
| 3029605 | C peptide [Moles/volume] in Serum or Plasma --5th specimen | 0.864 |  |
| 1469985 | C reactive protein [Mass/volume] in Serum, Plasma or Blood by Rapid immunoassay | 0.864 |  |
| 3009417 | Choriogonadotropin.beta subunit [Presence] in Urine | 0.864 | 1227 |
| 3036988 | Choriogonadotropin.intact [Units/volume] in Serum or Plasma | 0.863 | 834 |
| 36660342 | C peptide [Mass/volume] in Serum or Plasma --2 hours post meal | 0.863 |  |
| 3051691 | Complement total hemolytic CH50 actual/normal in Serum or Plasma | 0.863 |  |
| 3048863 | Creatine kinase.MB/Creatine kinase.total [Ratio] in Serum or Plasma | 0.862 | 211 |
| 3051746 | C peptide [Moles/volume] in Serum or Plasma --1.5 hours post dose glucose | 0.862 |  |
| 40769150 | CYP2C19 gene targeted mutation analysis in Blood by Molecular genetics method | 0.862 |  |
| 3029593 | C peptide [Moles/volume] in Serum or Plasma --3rd specimen | 0.861 |  |
| 43055397 | Creatine kinase.MB/Creatine kinase.total [Pure catalytic fraction] in Serum or Plasma by Electrophoresis | 0.861 |  |
| 3010084 | C peptide [Mass/volume] in Serum or Plasma | 0.861 |  |
| 3024552 | Cancer Ag 19-9 [Presence] in Serum or Plasma | 0.861 |  |
| 3019257 | Choriogonadotropin.beta subunit [Moles/volume] in Urine | 0.860 |  |
| 3037641 | Choriogonadotropin [Units/volume] in Body fluid | 0.859 |  |
| 3030208 | C peptide [Moles/volume] in Serum or Plasma --7th specimen | 0.858 |  |
| 3048150 | Creatine kinase.MB [Presence] in Serum or Plasma | 0.858 |  |
| 3008615 | Choriogonadotropin.beta subunit [Units/volume] in Serum or Plasma by Immunoassay (EIA) 3rd IS | 0.857 |  |
| 3023511 | Choriogonadotropin [Units/volume] in Urine | 0.856 |  |
| 3005628 | Complement C1r [Mass/volume] in Serum or Plasma | 0.855 |  |
| 3029848 | Cancer Ag 15-3 [Units/volume] in Cerebral spinal fluid | 0.854 |  |
| 43534057 | CYP2E1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.853 |  |
| 3023286 | Complement C1 esterase inhibitor bound IgM Ab [Mass/volume] in Serum or Plasma | 0.853 |  |
| 3018598 | Complement total hemolytic CH50 [Units/volume] in Body fluid | 0.853 |  |
| 3015760 | Choriogonadotropin [Presence] in Body fluid | 0.853 |  |
| 3027833 | Creatine kinase.MM/Creatine kinase.total in Serum or Plasma by Electrophoresis | 0.853 | 1392 |
| 3028766 | C reactive protein [Titer] in Serum or Plasma | 0.852 |  |
| 3004624 | Choriogonadotropin.intact [Presence] in Serum or Plasma | 0.851 |  |
| 3006448 | Complement C1 esterase inhibitor bound IgG Ab [Mass/volume] in Serum or Plasma | 0.851 |  |
| 3032748 | Cancer Ag 19-9 [Units/volume] in Pericardial fluid | 0.850 |  |
| 3027227 | Creatine kinase.BB/Creatine kinase.total in Serum or Plasma by Electrophoresis | 0.850 | 1390 |
| 3011149 | Choriogonadotropin.beta subunit [Presence] in Serum or Plasma | 0.846 | 477 |
| 3025552 | Complement C1 esterase inhibitor free IgG Ab [Mass/volume] in Serum or Plasma | 0.844 |  |
| 3002091 | Choriogonadotropin [Moles/volume] in Serum or Plasma | 0.842 |  |
| 648034 | Choriogonadotropin [Measurement] in Urine | 0.840 |  |
| 3018993 | Complement total hemolytic CH100 [Units/volume] in Serum or Plasma | 0.839 | 1865 |
| 3026984 | Complement C1 esterase inhibitor free IgM Ab [Mass/volume] in Serum or Plasma | 0.839 |  |
| 3007150 | Creatine kinase.MB/Creatine kinase.total in Serum or Plasma by Electrophoresis | 0.839 | 1391 |
| 3033186 | Complement C1 esterase inhibitor.functional [Mass/volume] in Body fluid | 0.838 |  |
| 3038624 | Choriogonadotropin.tumor marker [Units/volume] in Serum or Plasma | 0.836 |  |
| 3023980 | Creatine kinase [Enzymatic activity/volume] in Body fluid | 0.831 |  |
| 3048252 | Creatine kinase.MiMi/Creatine kinase.total in Serum or Plasma | 0.831 |  |
| 3030676 | VKORC1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.830 |  |
| 44817195 | Complement total hemolytic CH50 actual/normal in Serum by Immunoassay | 0.830 |  |
| 43534055 | UGT2B15 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.828 |  |
| 3046976 | DPYD gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.828 |  |
| 40758991 | Choriogonadotropin [Units/volume] in Cord blood | 0.827 |  |
| 44817196 | Complement lectin pathway actual/normal in Serum by Immunoassay | 0.826 |  |
| 3049852 | CYBB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.823 |  |
| 40760427 | CYP11B1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.822 |  |
| 3040873 | UGT1A1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.822 |  |
| 3028164 | Complement total hemolytic [Units/volume] in Blood | 0.821 |  |
| 3043871 | Choriogonadotropin.intact [Multiple of the median] in Serum or Plasma | 0.821 |  |
| 3004376 | Choriogonadotropin [Multiple of the median] in Serum or Plasma | 0.819 | 1178 |
| 44786662 | ABCB1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.816 |  |
| 3042360 | Creatine kinase.BB [Enzymatic activity/volume] in Cerebral spinal fluid by Electrophoresis | 0.816 |  |
| 3011836 | F2 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.816 | 1056 |
| 3008714 | Choriogonadotropin [Multiple of the median] adjusted in Serum or Plasma | 0.814 | 735 |
| 46234771 | C reactive protein [Moles/volume] in Serum or Plasma by High sensitivity method | 0.814 |  |
| 3023059 | Complement total hemolytic C50 [Units/volume] in Serum or Plasma by Immunoassay | 0.814 |  |
| 3045564 | Choriogonadotropin.intact [Multiple of the median] adjusted in Serum or Plasma | 0.812 |  |
| 3049410 | CYP2D6 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.811 |  |
| 3041031 | SLC22A18 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.809 |  |
| 3001099 | RB1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.809 |  |
| 46236293 | HBB gene mutations found [Identifier] in Blood or Tissue by Sequencing Nominal | 0.808 |  |
| 40758989 | Choriogonadotropin.beta subunit [Multiple of the median] in Serum or Plasma | 0.808 |  |
| 3021182 | F7 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.807 |  |
| 3043932 | GPC3 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.805 |  |
| 3024563 | HBA1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.805 |  |
| 40762081 | FGB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.805 |  |
| 3049801 | Complement C1 esterase inhibitor actual/normal in Serum or Plasma | 0.804 |  |
| 3005089 | MTHFR gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.804 | 1341 |
| 3026226 | HBB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.803 |  |
| 21493707 | TPMT gene mutations found [Identifier] in Blood or Tissue by Sequencing Nominal | 0.803 |  |
| 3000391 | Complement C1 esterase inhibitor.functional [Presence] in Serum or Plasma | 0.801 |  |
| 3003120 | CYP21A2 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.800 |  |
| 3042168 | TPMT gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.800 |  |
| 1988606 | C reactive protein [Units/volume] in Body fluid | 0.800 |  |
| 40762274 | C reactive protein [Mass/volume] in Cerebral spinal fluid by High sensitivity method | 0.797 |  |
| 3010578 | Choriomammotropin [Mass/volume] in Serum | 0.795 |  |
| 3010164 | Choriogonadotropin.beta subunit [Multiple of the median] adjusted in Serum or Plasma | 0.795 | 1298 |
| 3023659 | Complement C1 esterase inhibitor.functional/Complement C1 esterase inhibitor.total in Serum or Plasma | 0.793 |  |
| 40769401 | CYP2C19 gene c.681G>A(*2) [Presence] in Blood or Tissue by Molecular genetics method | 0.791 |  |
| 3044417 | C reactive protein [Mass/volume] in Cerebral spinal fluid | 0.790 |  |
| 3045086 | Choriogonadotropin [Multiple of the median] adjusted in Amniotic fluid | 0.785 |  |
| 3045854 | Choriogonadotropin [Multiple of the median] in Amniotic fluid | 0.779 |  |
| 43533386 | Complement C1.functional [Units/volume] in Serum | 0.779 |  |
| 43055138 | CYP2B6 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.776 |  |
| 44817194 | Complement alternate pathway AH50 actual/normal in Serum by Immunoassay | 0.775 |  |
| 3043962 | Cytokines [Presence] in Serum or Plasma | 0.774 |  |
| 1002272 | Complement C2.functional [Units/volume] in Serum or Plasma | 0.773 |  |
| 3964914 | Cr^a Ab [Presence] in Serum or Plasma | 0.772 |  |
| 43534060 | CYP2D6 gene and CYP2C19 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.771 |  |
| 3015615 | Complement alternate pathway AH50 [Units/volume] in Serum or Plasma | 0.769 |  |
| 3965026 | C^G Ab [Presence] in Serum or Plasma | 0.768 |  |
| 21493567 | CYP2C9 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.768 |  |
| 44786665 | CYP3A4 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.766 |  |
| 21493661 | CYP1A2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.764 |  |
| 3030970 | Complement C1s actual/normal in Serum or Plasma | 0.763 |  |
| 40761563 | Complement functional activity [Units/volume] in Serum or Plasma by Immunoassay | 0.759 |  |
| 3008143 | IgG [Presence] in Serum | 0.756 |  |
| 40769400 | CYP2C19 gene c.636G>A(*3) [Presence] in Blood or Tissue by Molecular genetics method | 0.753 |  |
| 40769403 | CYP2C19 gene c.IVS5+2T>A(*7) [Presence] in Blood or Tissue by Molecular genetics method | 0.751 |  |
| 36305011 | Complement C3.functional [Units/volume] in Serum or Plasma | 0.749 |  |
| 40763526 | Complement C5.functional [Units/volume] in Serum or Plasma | 0.749 |  |
| 21494702 | CYP3A4 and CYP3A5 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.748 |  |
| 40769402 | CYP2C19 gene c.806C>T(*17) [Presence] in Blood or Tissue by Molecular genetics method | 0.748 |  |
| 40769397 | CYP2C19 gene c.1A>G(*4) [Presence] in Blood or Tissue by Molecular genetics method | 0.748 |  |
| 3043745 | Rheumatoid factor [Presence] in Serum | 0.748 | 981 |
| 3015759 | IgM [Presence] in Serum | 0.747 |  |
| 37020147 | CYP3A7 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.742 |  |
| 21493868 | CYP3A4 and CYP3A5 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.742 |  |
| 3030493 | Complement C8.functional [Units/volume] in Serum or Plasma | 0.742 |  |
| 1002386 | Complement C4.functional [Units/volume] in Serum or Plasma | 0.741 |  |
| 3023504 | Cryofibrinogen [Presence] in Plasma | 0.731 | 2007 |
| 44817193 | Complement activity panel - Serum | 0.730 |  |
| 645411 | Complement C2 [Measurement] in Serum or Plasma | 0.708 |  |
| 3006550 | Complement factor Ba [Mass/volume] in Serum or Plasma | 0.706 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1823 | -crp-o |  | 100% | name+values | 285 | 100 | [1.78, 4.57, 8.47, 13.7, 22.69, 32.46, 46.6, 73.58, 109.4] |  |  | Qualitative test (also semi-quantitative) | C-reactive protein [Presence] in Serum or Plasma |
| 1824 | -cyp2b6 |  | 100% | name | 2593 | 100 |  |  |  |  | CYP2B6 gene mutations found [Identifier] in Blood or Tissue |
| 1825 | -cyp2c19 |  | 100% | name | 2601 | 100 |  |  |  |  | CYP2C19 gene mutations found [Identifier] in Blood or Tissue |
| 1826 | -cyp2c9 |  | 100% | name | 2594 | 100 |  |  |  |  | CYP2C9 gene mutations found [Identifier] in Blood or Tissue |
| 1827 | -cyp2d6 |  | 100% | name | 2585 | 100 |  |  |  |  | CYP2D6 gene mutations found [Identifier] in Blood or Tissue |
| 1828 | -cyp3a5 |  | 100% | name | 2594 | 100 |  |  |  |  | CYP3A5 gene mutations found [Identifier] in Blood or Tissue |
| 1829 | -cyp4f2 |  | 100% | name+values | 2594 | 100 | [11, 11, 11, 11, 11, 11.01, 13, 13, 13] |  |  |  | CYP4F2 gene mutations found [Identifier] in Blood or Tissue |
| 1830 | -hcgbsuh | % | 14% | name+unit+values | 349 | 0 | [2.04, 3.59, 5.05, 7.34, 10.09, 13.58, 18.22, 33.58, 53.88] |  |  |  | Chorionic gonadotropin.beta subunit/Chorionic gonadotropin.total [# Ratio] in Serum or Plasma |
| 1831 | -hcgbsuh |  | 86% | name | 2216 | 100 |  |  |  |  | Chorionic gonadotropin.beta subunit [Units/volume] in Serum or Plasma |
| 1832 | b-ckmbmv |  | 100% | name+values | 268 | 100 | [1.1, 1.2, 1.3, 1.49, 1.68, 1.87, 2.18, 3.02, 5.19] |  | Blood |  | Creatine kinase.MB isoenzyme [Mass/volume] in Blood |
| 1833 | b-crp-0 | mg/l | 64% | name+unit+values | 280 | 0 | [6.12, 8.21, 10.3, 13.62, 18.95, 26.74, 38.92, 56.79, 94.86] |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 1834 | b-crp-0 |  | 36% | name | 159 | 100 |  |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 1835 | b-crp-o | mg/l | 63% | name+unit+values | 4645 | 0 | [6.89, 9.54, 13.07, 17.91, 24.02, 32.68, 45.29, 63.98, 96.23] |  | Blood | Qualitative test (also semi-quantitative) | C-reactive protein [Mass/volume] in Blood |
| 1836 | b-crp-o |  | 37% | name | 2697 | 100 |  |  | Blood | Qualitative test (also semi-quantitative) | C-reactive protein [Presence] in Blood |
| 1837 | b-crp-os |  | 100% | name+values | 722 | 100 | [8.23, 12.34, 17.13, 22.2, 29.21, 39.16, 57.77, 71.42, 103.76] |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 1838 | b-crp-poc | mg/l | 66% | name+unit+values | 3324 | 0.15 | [6.18, 8.49, 11.75, 15.65, 21.27, 28.91, 40.33, 56.63, 84.68] |  | Blood |  | C-reactive protein [Mass/volume] in Blood by Point-of-care |
| 1839 | b-crp-poc |  | 34% | name | 1709 | 100 |  |  | Blood |  | C-reactive protein [Mass/volume] in Blood by Point-of-care |
| 1840 | b-crp-pt | mg/l | 35% | name+unit+values | 478 | 0 | [6.89, 9.09, 12.92, 17.68, 25.52, 36.09, 50.45, 69.71, 107.87] |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 1841 | b-crp-pt |  | 65% | name+values | 891 | 100 | [7, 9.67, 13.33, 18.07, 24.95, 38.04, 53.76, 86.77, 121.33] |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 1842 | b-crp-tth | mg/l | 54% | name+unit | 61 | 0 |  |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 1843 | b-crp-tth |  | 46% | name | 52 | 100 |  |  | Blood |  | C-reactive protein [Mass/volume] in Blood |
| 1844 | b-crp-v | mg/l | 66% | name+unit+values | 1837 | 0 | [4.76, 9.44, 12.48, 16.97, 23.43, 35.1, 48.82, 67.87, 108.81] |  | Blood | Free or unconjugated | C-reactive protein [Mass/volume] in Blood |
| 1845 | b-crp-v |  | 34% | name+values | 961 | 100 | [1.3, 1.6, 2.15, 2.74, 3.34, 4.12, 5.16, 6.16, 8] |  | Blood | Free or unconjugated | C-reactive protein.high sensitivity [Mass/volume] in Blood |
| 1846 | b-crp-vt | mg/l | 57% | name+unit+values | 20172 | 0 | [5.97, 7.8, 10.39, 14.13, 19.28, 26.74, 38.07, 54.9, 88.62] | B -C-reaktiivinen proteiini, vieritutkimus | Blood |  | C-reactive protein [Mass/volume] in Blood by Point-of-care |
| 1847 | b-crp-vt |  | 43% | name | 14973 | 100 |  | B -C-reaktiivinen proteiini, vieritutkimus | Blood |  | C-reactive protein [Mass/volume] in Blood by Point-of-care |
| 1848 | b-cyp2c19 |  | 100% | name | 617 | 100 |  | B -Sytokromi P450 2C19, CYP2C19-geenin alleelit *2 ja *17, DNA-tutkimus verestä | Blood |  | CYP2C19 gene targeted variant analysis in Blood |
| 1849 | b-cyp2d6 |  | 100% | name | 723 | 100 |  | B -Sytokromi P450 2D6, CYP2D6-geenin variaatiot, DNA-tutkimus verestä | Blood |  | CYP2D6 gene targeted variant analysis in Blood |
| 1850 | cb-crp(qr) | mg/l | 64% | name+unit+values | 3604 | 0.08 | [6, 8, 10.5, 14.3, 18.62, 24.99, 34.66, 50.48, 80.71] |  | Capillary blood |  | C-reactive protein [Mass/volume] in Capillary blood |
| 1851 | cb-crp(qr) |  | 36% | name | 2040 | 100 |  |  | Capillary blood |  | C-reactive protein [Mass/volume] in Capillary blood |
| 1852 | cp-crp-hy | mg/l | 76% | name+unit+values | 12184 | 0 | [3.48, 6.15, 8.73, 12.66, 17.92, 26.04, 38.58, 57.55, 91.94] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 1853 | cp-crp-hy |  | 24% | name | 3870 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 1854 | cp-crp-lb | mg/l | 66% | name+unit+values | 247 | 0 | [6, 8.5, 12.42, 17.71, 24.78, 34.13, 46.86, 67.12, 92.62] |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 1855 | cp-crp-lb |  | 34% | name | 128 | 100 |  |  |  |  | C-reactive protein [Mass/volume] in Serum or Plasma |
| 1856 | fp-c-pept | nmol/l | 82% | name+unit+values | 3086 | 0.13 | [0.3, 0.46, 0.58, 0.7, 0.83, 0.98, 1.14, 1.37, 1.79] | fP-C-peptidi, proinsuliinin | Fasting plasma |  | C-peptide [Moles/volume] in Plasma |
| 1857 | fp-c-pept |  | 18% | name+values | 690 | 100 | [0.24, 0.39, 0.51, 0.67, 0.82, 1.01, 1.26, 1.53, 1.95] | fP-C-peptidi, proinsuliinin | Fasting plasma |  | C-peptide [Moles/volume] in Plasma |
| 1858 | fs-c-pept | nmol/l | 95% | name+unit+values | 15089 | 0 | [0.23, 0.4, 0.54, 0.66, 0.79, 0.93, 1.12, 1.4, 1.93] | fS-C-peptidi, proinsuliinin | Fasting serum |  | C-peptide [Moles/volume] in Serum |
| 1859 | fs-c-pept |  | 5% | name | 864 | 100 |  | fS-C-peptidi, proinsuliinin | Fasting serum |  | C-peptide [Moles/volume] in Serum |
| 1860 | fs-jc-pept | nmol/l | 100% | name+unit+values | 167 | 0 | [0.38, 0.53, 0.65, 0.74, 0.85, 0.98, 1.14, 1.36, 1.79] |  | Fasting serum |  | C-peptide [Moles/volume] in Serum |
| 1861 | p-c-pept | nmol/l | 74% | name+unit+values | 1623 | 0 | [0.39, 0.63, 0.84, 1.09, 1.39, 1.75, 2.25, 2.85, 3.73] |  | Plasma |  | C-peptide [Moles/volume] in Plasma |
| 1862 | p-c-pept |  | 26% | name+values | 582 | 100 | [0.39, 0.59, 0.76, 0.95, 1.19, 1.45, 1.77, 2.16, 3] |  | Plasma |  | C-peptide [Moles/volume] in Plasma |
| 1863 | p-c-pepta | nmol/l | 92% | name+unit+values | 1962 | 0 | [0.57, 0.8, 1.02, 1.23, 1.44, 1.69, 1.97, 2.37, 3.06] | P -C-peptidi, proinsuliinin, aterianjälkeinen | Plasma |  | C-peptide [Moles/volume] in Plasma --post meal |
| 1864 | p-c-pepta |  | 8% | name+values | 166 | 100 | [0.38, 0.66, 0.99, 1.6, 1.72, 1.93, 2.24, 2.7, 3.74] | P -C-peptidi, proinsuliinin, aterianjälkeinen | Plasma |  | C-peptide [Moles/volume] in Plasma --post meal |
| 1865 | p-c-peptidi | nmol/l | 89% | name+unit+values | 171 | 0 | [0.45, 0.63, 0.81, 1, 1.24, 1.51, 1.8, 2.3, 3.2] |  | Plasma |  | C-peptide [Moles/volume] in Plasma |
| 1866 | p-c-peptidi |  | 11% | name | 21 | 100 |  |  | Plasma |  | C-peptide [Moles/volume] in Plasma |
| 1867 | p-c1inh | g/l | 84% | name+unit+values | 186 | 0 | [0.21, 0.23, 0.25, 0.26, 0.28, 0.3, 0.33, 0.34, 0.38] | P -C1-Esteraasin inhibiittori | Plasma |  | Complement C1 inhibitor [Mass/volume] in Plasma |
| 1868 | p-c1inh |  | 16% | name | 35 | 100 |  | P -C1-Esteraasin inhibiittori | Plasma |  | Complement C1 inhibitor [Mass/volume] in Plasma |
| 1869 | p-c1inhbk | % | 87% | name+unit+values | 1420 | 0.07 | [77.16, 90.39, 98.04, 104.77, 110.86, 117.47, 124.68, 131.53, 144.39] | P -C1-Esteraasin inhibiittori, aktiivisuus | Plasma |  | Complement C1 inhibitor functional [Ratio] in Plasma |
| 1870 | p-c1inhbk | form | 1% | name+unit | 11 | 0 |  | P -C1-Esteraasin inhibiittori, aktiivisuus | Plasma |  | Complement C1 inhibitor functional [Ratio] in Plasma |
| 1871 | p-c1inhbk |  | 13% | name+values | 207 | 100 | [73, 86.25, 94.53, 101.6, 110, 115, 118.7, 127.77, 139] | P -C1-Esteraasin inhibiittori, aktiivisuus | Plasma |  | Complement C1 inhibitor functional [Ratio] in Plasma |
| 1872 | p-ca12-5 | u/ml | 98% | name+unit+values | 29714 | 0 | [8.17, 10.61, 13.28, 16.55, 21.71, 31.29, 52.45, 110.42, 328.04] | P -CA 12-5 antigeeni | Plasma |  | Cancer Ag 125 [Units/volume] in Plasma |
| 1873 | p-ca12-5 |  | 2% | name+values | 589 | 100 | [7, 8.96, 10, 11.85, 13.35, 16.35, 20.64, 29.91, 53.21] | P -CA 12-5 antigeeni | Plasma |  | Cancer Ag 125 [Units/volume] in Plasma |
| 1874 | p-ca15-3 | u/ml | 99% | name+unit+values | 16517 | 0 | [9.61, 13.22, 16.67, 20.07, 24.27, 29.6, 39.05, 63.09, 168.72] | P -CA 15-3 antigeeni | Plasma |  | Cancer Ag 15-3 [Units/volume] in Plasma |
| 1875 | p-ca15-3 |  | 1% | name | 135 | 100 |  | P -CA 15-3 antigeeni | Plasma |  | Cancer Ag 15-3 [Units/volume] in Plasma |
| 1876 | p-ca19-9 | u/ml | 93% | name+unit+values | 27681 | 0 | [5.13, 7.04, 9.22, 12.37, 17.66, 26.92, 46.53, 113.02, 513.07] | P -CA 19-9 antigeeni | Plasma |  | Cancer Ag 19-9 [Units/volume] in Plasma |
| 1877 | p-ca19-9 |  | 7% | name+values | 2212 | 100 | [4.07, 6.72, 8.36, 10.75, 14.96, 20.27, 26.89, 40.06, 106.38] | P -CA 19-9 antigeeni | Plasma |  | Cancer Ag 19-9 [Units/volume] in Plasma |
| 1878 | p-ck-mb | u/l | 42% | name+unit+values | 109 | 0 | [8, 10, 10.92, 12, 13, 14.37, 16.08, 18.15, 28] | P -Kreatiinikinaasi, MB-alayksikkö | Plasma |  | Creatine kinase.MB isoenzyme [Enzymatic activity/volume] in Plasma |
| 1879 | p-ck-mb | ug/l | 10% | name+unit | 27 | 0 |  | P -Kreatiinikinaasi, MB-alayksikkö | Plasma |  | Creatine kinase.MB isoenzyme [Mass/volume] in Plasma |
| 1880 | p-ck-mb |  | 48% | name+values | 126 | 100 | [10, 11, 11, 12.32, 13.27, 15, 16.01, 18.1, 20.3] | P -Kreatiinikinaasi, MB-alayksikkö | Plasma |  | Creatine kinase.MB isoenzyme [Enzymatic activity/volume] in Plasma |
| 1881 | p-ck-mbm | ug/l | 97% | name+unit+values | 76990 | 0 | [1.09, 1.52, 1.93, 2.24, 2.77, 3.38, 4.47, 6.93, 16.86] | P -Kreatiinikinaasi, MB-alayksikkö, massa | Plasma |  | Creatine kinase.MB isoenzyme [Mass/volume] in Plasma |
| 1882 | p-ck-mbm |  | 3% | name | 2370 | 100 |  | P -Kreatiinikinaasi, MB-alayksikkö, massa | Plasma |  | Creatine kinase.MB isoenzyme [Mass/volume] in Plasma |
| 1883 | p-ckmbm | ug/l | 98% | name+unit+values | 372 | 0 | [1, 2, 2, 2.93, 3, 4, 4.92, 6, 8.88] |  | Plasma |  | Creatine kinase.MB isoenzyme [Mass/volume] in Plasma |
| 1884 | p-ckmbm |  | 2% | name | 9 | 100 |  |  | Plasma |  | Creatine kinase.MB isoenzyme [Mass/volume] in Plasma |
| 1885 | p-crp-hoi | mg/l | 75% | name+unit+values | 1173 | 0 | [5, 6.85, 9.48, 13.71, 20.27, 30.55, 44.2, 65.88, 104.84] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1886 | p-crp-hoi |  | 25% | name | 391 | 100 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1887 | p-crp-hy | mg/l | 57% | name+unit+values | 9239 | 0 | [6.51, 8.55, 11.56, 15.65, 21.5, 29.73, 42.27, 60.54, 94.03] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1888 | p-crp-hy |  | 43% | name | 6863 | 100 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1889 | p-crp-o | mg/l | 54% | name+unit+values | 38640 | 0 | [6.01, 8.14, 11.06, 15.11, 20.94, 29.28, 41.28, 59.55, 92.83] |  | Plasma | Qualitative test (also semi-quantitative) | C-reactive protein [Mass/volume] in Plasma |
| 1890 | p-crp-o |  | 46% | name | 32815 | 100 |  |  | Plasma | Qualitative test (also semi-quantitative) | C-reactive protein [Presence] in Plasma |
| 1891 | p-crp-oma | mg/l | 55% | name+unit+values | 1613 | 0 | [6, 8.17, 11.43, 15.37, 19.86, 26.59, 35.72, 52.43, 83.46] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1892 | p-crp-oma |  | 45% | name | 1306 | 100 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1893 | p-crp-p | mg/l | 16% | name+unit+values | 198 | 0 | [1.18, 2.54, 4.73, 8.89, 15.1, 20.7, 30.37, 44.73, 68.28] |  | Plasma | Upright (standing) | C-reactive protein [Mass/volume] in Plasma |
| 1894 | p-crp-p |  | 84% | name+values | 1065 | 100 | [4.46, 6.38, 8.76, 12.77, 17.8, 25.4, 36.67, 54.24, 91.62] |  | Plasma | Upright (standing) | C-reactive protein [Mass/volume] in Plasma |
| 1895 | p-crp-poc | mg/l | 52% | name+unit+values | 281 | 0 | [4.24, 7.55, 12.19, 16.73, 24.29, 35.37, 50.95, 69.91, 100.65] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma by Point-of-care |
| 1896 | p-crp-poc |  | 48% | name+values | 257 | 100 | [1.3, 2.38, 3.75, 5.95, 9.46, 14.85, 27.16, 41.26, 72.5] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma by Point-of-care |
| 1897 | p-crp-päi | mg/l | 95% | name+unit+values | 122 | 0 | [0, 0, 0.85, 1.24, 2.83, 6.05, 11.93, 23.6, 44.85] |  | Plasma |  | C-reactive protein.high sensitivity [Mass/volume] in Plasma |
| 1898 | p-crp-päi |  | 5% | name | 7 | 100 |  |  | Plasma |  | C-reactive protein.high sensitivity [Mass/volume] in Plasma |
| 1899 | p-crp-vt | mg/l | 67% | name+unit+values | 10010 | 0.01 | [5.1, 7.09, 9.85, 14.07, 19.99, 27.88, 40.22, 59.89, 93.51] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma by Point-of-care |
| 1900 | p-crp-vt |  | 33% | name | 5015 | 100 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma by Point-of-care |
| 1901 | p-crphoi | mg/l | 57% | name+unit+values | 6246 | 0 | [6.03, 8.33, 11.66, 16.09, 22.29, 31.43, 44.78, 63.9, 96.64] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1902 | p-crphoi |  | 43% | name+values | 4708 | 100 | [9, 11.95, 15.82, 20.23, 27.43, 32.4, 41, 60.3, 90.28] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1903 | p-crpos | mg/l | 60% | name+unit+values | 386 | 1.55 | [6.7, 9.04, 12.01, 15.42, 20.33, 28.84, 36.52, 56.1, 82.12] |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1904 | p-crpos |  | 40% | name | 260 | 100 |  |  | Plasma |  | C-reactive protein [Mass/volume] in Plasma |
| 1905 | p-hcg-tot | iu/l | 43% | name+unit+values | 9307 | 0 | [4.09, 10.68, 31.42, 84.47, 209.82, 494.82, 1192.71, 3554.16, 15110.09] | P -Koriongonadotropiini, totaali | Plasma |  | Chorionic gonadotropin [Units/volume] in Plasma |
| 1906 | p-hcg-tot |  | 57% | name | 12193 | 100 |  | P -Koriongonadotropiini, totaali | Plasma |  | Chorionic gonadotropin [Units/volume] in Plasma |
| 1907 | s-c-pep-a | nmol/l | 85% | name+unit+values | 2840 | 0.04 | [0.29, 0.5, 0.68, 0.86, 1.06, 1.29, 1.58, 1.97, 2.54] |  | Serum |  | C-peptide [Moles/volume] in Serum --post meal |
| 1908 | s-c-pep-a |  | 15% | name+values | 508 | 100 | [0.3, 0.52, 0.71, 0.89, 1.07, 1.31, 1.52, 1.9, 2.36] |  | Serum |  | C-peptide [Moles/volume] in Serum --post meal |
| 1909 | s-c-pept | nmol/l | 84% | name+unit+values | 1452 | 0 | [0.24, 0.44, 0.62, 0.79, 0.92, 1.12, 1.37, 1.72, 2.31] | S -C-peptidi | Serum |  | C-peptide [Moles/volume] in Serum |
| 1910 | s-c-pept |  | 16% | name+values | 271 | 100 | [0.28, 0.47, 0.63, 0.84, 0.97, 1.16, 1.44, 1.76, 2.45] | S -C-peptidi | Serum |  | C-peptide [Moles/volume] in Serum |
| 1911 | s-c1inh | g/l | 78% | name+unit+values | 1560 | 0.06 | [0.23, 0.25, 0.27, 0.28, 0.3, 0.31, 0.33, 0.35, 0.4] | S -C1-Esteraasin inhibiittori | Serum |  | Complement C1 inhibitor [Mass/volume] in Serum |
| 1912 | s-c1inh |  | 22% | name+values | 429 | 100 | [0.22, 0.25, 0.26, 0.28, 0.29, 0.31, 0.33, 0.35, 0.38] | S -C1-Esteraasin inhibiittori | Serum |  | Complement C1 inhibitor [Mass/volume] in Serum |
| 1913 | s-c1inhbk | % | 96% | name+unit+values | 425 | 0 | [87.27, 95.84, 100.07, 104.14, 106.54, 108.71, 112.59, 116.31, 122] | S -C1-Esteraasin inhibiittori, aktiivisuus | Serum |  | Complement C1 inhibitor functional [Ratio] in Serum |
| 1914 | s-c1inhbk | g/l | 2% | name+unit | 8 | 0 |  | S -C1-Esteraasin inhibiittori, aktiivisuus | Serum |  | Complement C1 inhibitor functional [Ratio] in Serum |
| 1915 | s-c1inhbk |  | 3% | name | 12 | 100 |  | S -C1-Esteraasin inhibiittori, aktiivisuus | Serum |  | Complement C1 inhibitor functional [Ratio] in Serum |
| 1916 | s-ca12-5 | u/ml | 95% | name+unit+values | 43238 | 0 | [7.23, 9.53, 11.79, 14.75, 18.98, 26.26, 41.05, 82.19, 239.23] | S -CA 12-5 antigeeni | Serum |  | Cancer Ag 125 [Units/volume] in Serum |
| 1917 | s-ca12-5 |  | 5% | name+values | 2169 | 100 | [8, 9.95, 11.74, 14.05, 16.6, 21.13, 30.4, 60.38, 103.15] | S -CA 12-5 antigeeni | Serum |  | Cancer Ag 125 [Units/volume] in Serum |
| 1918 | s-ca15-3 | u/ml | 97% | name+unit+values | 23073 | 0 | [8.05, 10.72, 13.36, 16, 19.22, 23.39, 30.69, 50.91, 133.08] | S -CA 15-3 antigeeni | Serum |  | Cancer Ag 15-3 [Units/volume] in Serum |
| 1919 | s-ca15-3 |  | 3% | name | 825 | 100 |  | S -CA 15-3 antigeeni | Serum |  | Cancer Ag 15-3 [Units/volume] in Serum |
| 1920 | s-ca19-9 | u/ml | 85% | name+unit+values | 44400 | 0 | [3.81, 5.5, 7.65, 10.34, 14.08, 19.73, 30.38, 62.29, 367.62] | S -CA 19-9 antigeeni | Serum |  | Cancer Ag 19-9 [Units/volume] in Serum |
| 1921 | s-ca19-9 |  | 15% | name+values | 7854 | 100 | [3, 4, 5, 6.85, 9.04, 12.81, 17.63, 26.61, 52.11] | S -CA 19-9 antigeeni | Serum |  | Cancer Ag 19-9 [Units/volume] in Serum |
| 1922 | s-ch100 |  | 100% | name | 343 | 100 |  | S -Komplementti, kokonaisaktiivisuus | Serum |  | Complement total hemolytic (CH50) [Enzymatic activity/volume] in Serum |
| 1923 | s-ch100al | % | 98% | name+unit+values | 1509 | 0 | [46.27, 69.22, 81.13, 88.95, 96.44, 102.87, 108.89, 116.07, 128.48] | S -Komplementti, kokonaishemolyyttinen, vaihtoehtonen tie | Serum |  | Complement alternative pathway functional [Ratio] in Serum |
| 1924 | s-ch100al |  | 2% | name | 35 | 100 |  | S -Komplementti, kokonaishemolyyttinen, vaihtoehtonen tie | Serum |  | Complement alternative pathway functional [Ratio] in Serum |
| 1925 | s-ch100cl | % | 98% | name+unit+values | 1524 | 0 | [78.34, 91.46, 99.05, 104, 108.74, 112.93, 117.94, 123.75, 133.35] | S -Komplementti, kokonaishemolyyttinen, klassinen tie | Serum |  | Complement classical pathway functional [Ratio] in Serum |
| 1926 | s-ch100cl |  | 2% | name | 36 | 100 |  | S -Komplementti, kokonaishemolyyttinen, klassinen tie | Serum |  | Complement classical pathway functional [Ratio] in Serum |
| 1927 | s-ch100l | % | 97% | name+unit+values | 1353 | 0 | [0.08, 5.28, 24.18, 50.65, 76.01, 94.59, 107.63, 119.25, 133.34] | S -Komplementti, aktiivisuus, lektiinitie | Serum |  | Complement lectin pathway functional [Ratio] in Serum |
| 1928 | s-ch100l |  | 3% | name | 37 | 100 |  | S -Komplementti, aktiivisuus, lektiinitie | Serum |  | Complement lectin pathway functional [Ratio] in Serum |
| 1929 | s-ch100mbl | % | 95% | name+unit+values | 143 | 0 | [1, 4.79, 27.31, 49.98, 83.33, 103.2, 117.04, 126.14, 145.7] |  | Serum |  | Complement lectin pathway functional [Ratio] in Serum |
| 1930 | s-ch100mbl |  | 5% | name | 8 | 100 |  |  | Serum |  | Complement lectin pathway functional [Ratio] in Serum |
| 1931 | s-ck-bb | % | 3% | name+unit | 11 | 0 |  |  | Serum |  | Creatine kinase.BB isoenzyme/Creatine kinase.total [Enzymatic activity Fraction] in Serum |
| 1932 | s-ck-bb | u/l | 18% | name+unit+values | 62 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 0] |  | Serum |  | Creatine kinase.BB isoenzyme [Enzymatic activity/volume] in Serum |
| 1933 | s-ck-bb |  | 78% | name | 263 | 100 |  |  | Serum |  | Creatine kinase.BB isoenzyme [Enzymatic activity/volume] in Serum |
| 1934 | s-ck-mb | % | 26% | name+unit+values | 100 | 0 | [1, 1, 1, 2, 2, 2.13, 3, 4, 6] | S -Kreatiinikinaasi, MB-alayksikkö | Serum |  | Creatine kinase.MB isoenzyme/Creatine kinase.total [Enzymatic activity Fraction] in Serum |
| 1935 | s-ck-mb | u/l | 57% | name+unit+values | 223 | 0 | [0, 0, 2, 3, 3.84, 4.25, 5.65, 7.45, 11.43] | S -Kreatiinikinaasi, MB-alayksikkö | Serum |  | Creatine kinase.MB isoenzyme [Enzymatic activity/volume] in Serum |
| 1936 | s-ck-mb |  | 17% | name | 68 | 100 |  | S -Kreatiinikinaasi, MB-alayksikkö | Serum |  | Creatine kinase.MB isoenzyme [Enzymatic activity/volume] in Serum |
| 1937 | s-ck-mm | % | 34% | name+unit+values | 113 | 0 | [91, 94.7, 96.25, 97, 98, 98, 99, 99, 99.85] |  | Serum |  | Creatine kinase.MM isoenzyme/Creatine kinase.total [Enzymatic activity Fraction] in Serum |
| 1938 | s-ck-mm | u/l | 51% | name+unit+values | 171 | 0 | [55.93, 76.67, 106.93, 142.02, 206.11, 274.4, 361.3, 449.47, 653.55] |  | Serum |  | Creatine kinase.MM isoenzyme [Enzymatic activity/volume] in Serum |
| 1939 | s-ck-mm |  | 15% | name | 50 | 100 |  |  | Serum |  | Creatine kinase.MM isoenzyme [Enzymatic activity/volume] in Serum |
| 1940 | s-crp-o | form | 4% | name+unit+values | 303 | 0 | [5, 7.58, 11.67, 16.13, 20.49, 28.31, 39.19, 56.35, 80.5] | S -C-reaktiivinen proteiini (kval) | Serum | Qualitative test (also semi-quantitative) | C-reactive protein [Mass/volume] in Serum |
| 1941 | s-crp-o | mg/l | 54% | name+unit+values | 4270 | 0 | [5, 5.03, 7.05, 9.78, 13.63, 19.21, 29.09, 45.02, 77.03] | S -C-reaktiivinen proteiini (kval) | Serum | Qualitative test (also semi-quantitative) | C-reactive protein [Mass/volume] in Serum |
| 1942 | s-crp-o | u/ml | 0% | name+unit | 10 | 0 |  | S -C-reaktiivinen proteiini (kval) | Serum | Qualitative test (also semi-quantitative) | C-reactive protein [Mass/volume] in Serum |
| 1943 | s-crp-o |  | 42% | name | 3270 | 100 |  | S -C-reaktiivinen proteiini (kval) | Serum | Qualitative test (also semi-quantitative) | C-reactive protein [Presence] in Serum |
| 1944 | s-hcg-b | u/l | 30% | name+unit | 58 | 0 |  | S -Koriongonadotropiini-B-alayksikkö | Serum |  | Chorionic gonadotropin.beta subunit [Units/volume] in Serum |
| 1945 | s-hcg-b |  | 70% | name | 134 | 100 |  | S -Koriongonadotropiini-B-alayksikkö | Serum |  | Chorionic gonadotropin.beta subunit [Units/volume] in Serum |
| 1946 | s-hcg-b-v | pmol/l | 5% | name+unit+values | 1133 | 0.26 | [1.11, 1.38, 2.02, 3.24, 6.39, 20.3, 53.95, 143.27, 1665.94] | S -Koriongonadotropiini-B-alayksikkö, vapaa | Serum | Free or unconjugated | Chorionic gonadotropin.beta subunit.free [Moles/volume] in Serum |
| 1947 | s-hcg-b-v | ug/l | 84% | name+unit+values | 18166 | 0 | [22.37, 30.52, 37.9, 45.37, 53.7, 63.59, 75.86, 93.4, 123.74] | S -Koriongonadotropiini-B-alayksikkö, vapaa | Serum | Free or unconjugated | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1948 | s-hcg-b-v |  | 10% | name | 2245 | 100 |  | S -Koriongonadotropiini-B-alayksikkö, vapaa | Serum | Free or unconjugated | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1949 | s-hcg-b/d | ug/l | 81% | name+unit+values | 203 | 0 | [6.98, 9.79, 12.24, 14.11, 16.55, 20.08, 23.61, 27.98, 38.24] |  | Serum |  | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1950 | s-hcg-b/d |  | 19% | name | 47 | 100 |  |  | Serum |  | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1951 | s-hcg-o |  | 100% | name | 11062 | 100 |  | S -Koriongonadotropiini (kval) | Serum | Qualitative test (also semi-quantitative) | Chorionic gonadotropin [Presence] in Serum |
| 1952 | s-hcg-tot | iu/l | 12% | name+unit | 49 | 0 |  | S -Koriongonadotropiini, totaali | Serum |  | Chorionic gonadotropin [Units/volume] in Serum |
| 1953 | s-hcg-tot | u/l | 33% | name+unit+values | 131 | 0 | [2.3, 3.14, 4.69, 14.27, 48.54, 313.48, 844.4, 3876, 8300] | S -Koriongonadotropiini, totaali | Serum |  | Chorionic gonadotropin [Units/volume] in Serum |
| 1954 | s-hcg-tot |  | 55% | name | 220 | 100 |  | S -Koriongonadotropiini, totaali | Serum |  | Chorionic gonadotropin [Units/volume] in Serum |
| 1955 | s-hcgbsuh | % | 9% | name+unit | 9 | 0 |  |  | Serum |  | Chorionic gonadotropin.beta subunit/Chorionic gonadotropin.total [# Ratio] in Serum |
| 1956 | s-hcgbsuh |  | 91% | name | 93 | 100 |  |  | Serum |  | Chorionic gonadotropin.beta subunit [Units/volume] in Serum |
| 1957 | s-hcgbv | ug/l | 82% | name+unit+values | 3403 | 0.06 | [23.28, 33.06, 41.4, 49.13, 57.97, 68.15, 80.14, 98.96, 129.15] |  | Serum |  | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1958 | s-hcgbv |  | 18% | name+values | 762 | 100 | [26.54, 34.48, 42.52, 49.78, 58, 66.21, 79.65, 95.49, 123.63] |  | Serum |  | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1959 | s-hcgbv/d | ug/l | 99% | name+unit+values | 19561 | 0 | [22.41, 30.99, 38.46, 45.94, 54.48, 64.42, 77.11, 93.56, 124.02] |  | Serum |  | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1960 | s-hcgbv/d |  | 1% | name | 116 | 100 |  |  | Serum |  | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1961 | s-hcgbvtr | ug/l | 100% | name+unit+values | 1332 | 0 | [21.35, 30.24, 38.52, 46.74, 57.22, 69.04, 82.94, 101.43, 133.78] |  | Serum |  | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1962 | s-hcgbvtr |  | 0% | name | 6 | 100 |  |  | Serum |  | Chorionic gonadotropin.beta subunit.free [Mass/volume] in Serum |
| 1963 | s-hcgxmom | mom | 100% | name+unit+values | 478 | 0 | [0.45, 0.59, 0.71, 0.83, 1, 1.2, 1.38, 1.72, 2.16] |  | Serum |  | Chorionic gonadotropin [MoM] in Serum |
| 1964 | u-hcg-o |  | 100% | name | 15029 | 100 |  | U -Koriongonadotropiini (kval) | Urine | Qualitative test (also semi-quantitative) | Chorionic gonadotropin [Presence] in Urine |
| 1965 | u-hcgo-lb |  | 100% | name | 123 | 100 |  |  | Urine |  | Chorionic gonadotropin [Presence] in Urine |

