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
Here is group 85.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 42529473 | Bone density quantitative measurement by DXA panel | 0.911 |  |
| 36305393 | Pure tone air conduction threshold audiometry panel | 0.909 |  |
| 1761861 | Pure tone bone conduction threshold audiometry panel | 0.874 |  |
| 40762373 | Cardiac stress echo study | 0.866 |  |
| 1259791 | Lupus anticoagulant aPTT screening panel - Platelet poor plasma by Coagulation assay | 0.850 |  |
| 1617160 | Diagnostic audiology results panel | 0.806 |  |
| 3033319 | Streptococcus pyogenes Ag [Presence] in Throat | 0.801 | 337 |
| 3027184 | Lupus anticoagulant [Interpretation] in Platelet poor plasma | 0.794 |  |
| 3014536 | Streptococcus agalactiae Ag [Presence] in Throat | 0.786 |  |
| 46235689 | Lupus anticoagulant aPTT, dRVVT and PT screening panel W Reflex | 0.776 |  |
| 3003551 | Influenza virus A Ag [Presence] in Throat | 0.776 |  |
| 3005534 | Adenovirus Ag [Presence] in Throat | 0.772 |  |
| 46235128 | Lupus anticoagulant aPTT and dRVVT screening panel W Reflex | 0.769 |  |
| 3046644 | Herpes simplex virus 1 Ag [Presence] in Throat | 0.768 |  |
| 3039189 | Lupus anticoagulant neutralization dilute phospholipid [Time] in Platelet poor plasma | 0.767 |  |
| 3022193 | Influenza virus A+B Ag [Presence] in Throat | 0.764 |  |
| 3009299 | Lupus anticoagulant neutralization platelet [Time] in Platelet poor plasma by Coagulation assay | 0.763 | 811 |
| 3014424 | Cardiac echo study Procedure stress method | 0.763 |  |
| 3017427 | Lupus anticoagulant neutralization dilute phospholipid [Presence] in Platelet poor plasma | 0.761 | 1189 |
| 3038697 | Lupus anticoagulant neutralization platelet [Presence] in Platelet poor plasma by Coagulation assay | 0.759 |  |
| 3007496 | Mumps virus Ag [Presence] in Throat | 0.757 |  |
| 3012751 | Measles virus Ag [Presence] in Throat | 0.756 |  |
| 3004641 | Pneumocystis jiroveci Ag [Presence] in Throat | 0.754 |  |
| 3050489 | Study report Skeletal system DXA | 0.752 |  |
| 1616467 | Auditory brainstem response panel | 0.750 |  |
| 3033295 | Lupus anticoagulant neutralization dilute phospholipid actual/normal in Platelet poor plasma by Coagulation assay | 0.740 |  |
| 3027627 | Lupus anticoagulant neutralization high phospholipid [Time] in Platelet poor plasma by Coagulation assay | 0.739 |  |
| 46235184 | Cardiac stress test EKG study Type | 0.733 |  |
| 3051343 | DXA Bone [Mass/Area] Bone density | 0.730 |  |
| 3050943 | Newborn hearing screening panel | 0.724 |  |
| 3019512 | Cardiac stress study Procedure | 0.723 |  |
| 1091363 | DXA Spine [T-score] Bone density | 0.715 |  |
| 3043090 | Cervical AndOr vaginal cytology study | 0.714 |  |
| 36204417 | DXA Lumbar spine [Z-score] Bone density | 0.708 |  |
| 3049581 | DXA Calcaneus [T-score] Bone density | 0.705 |  |
| 3965513 | Bone DXA Calcaneus [Z-score] Bone density | 0.703 |  |
| 36203242 | DXA Humerus [Mass/Area] Bone density | 0.703 |  |
| 3021722 | DXA Femur [Mass/Area] Bone density | 0.702 |  |
| 3002101 | DXA Radius and Ulna [Mass/Area] Bone density | 0.701 |  |
| 43533765 | Newborn hearing screen panel of Ear - left | 0.694 |  |
| 36031573 | HLA-A and B and C (class I) typing panel - Blood or Tissue by Low resolution | 0.685 |  |
| 43533768 | Newborn hearing screen panel of Ear - right | 0.683 |  |
| 36032168 | HLA-A and B and C (class I) typing panel - Blood or Tissue by High resolution | 0.683 |  |
| 3013512 | EKG study | 0.682 |  |
| 36031258 | HLA-A and B and C (class I) typing panel - Blood or Tissue from Donor by High resolution | 0.681 |  |
| 3965290 | Total score (0 to 7) | 0.680 |  |
| 36031724 | HLA-A and B and C (class I) typing panel - Blood or Tissue from Donor by Low resolution | 0.678 |  |
| 1989068 | Visual acuity panel | 0.666 |  |
| 3010908 | Cytology study comment Cervical or vaginal smear or scraping Cyto stain | 0.664 | 945 |
| 3002256 | Pathology report gross observation | 0.662 |  |
| 1002224 | Polysomnography panel | 0.660 |  |
| 42528675 | Summed stress score Myocardium SPECT | 0.660 |  |
| 36660223 | HLA-DQA1 and HLA-DQB1 typing panel - Blood or Tissue by Molecular genetics method | 0.659 |  |
| 3047222 | HLA typing for narcolepsy panel - Blood | 0.659 |  |
| 46236302 | HLA-C [Type] by High resolution typing | 0.657 |  |
| 36032421 | HLA-DP and DQ and DR (class II) typing panel - Blood or Tissue by High resolution | 0.656 |  |
| 36031422 | HLA-DP and DQ and DR (class II) typing panel - Blood or Tissue from Donor by High resolution | 0.648 |  |
| 3964745 | Pathology report microscopic observation in Specimen | 0.648 |  |
| 36032108 | HLA-DP and DQ and DR (class II) typing panel - Blood or Tissue by Low resolution | 0.645 |  |
| 40765709 | PhenX - audiogram hearing test protocol 200101 | 0.641 |  |
| 1988459 | Total score NRS_2002 | 0.639 |  |
| 42529483 | Pathology report intraoperative observation in Specimen Document | 0.637 |  |
| 3045178 | Pathology report final diagnosis | 0.637 | 775 |
| 3010322 | Cardiac catheterization study | 0.635 |  |
| 36305975 | PERC Total score | 0.634 |  |
| 3028879 | Pathologic findings | 0.628 |  |
| 3007597 | Pathology report gross observation Narrative | 0.626 | 248 |
| 1175343 | PESI Total score | 0.621 |  |
| 42528672 | Summed stress score for 20 segment model Myocardium SPECT | 0.619 |  |
| 42528817 | Summed stress score for 17 segment model Myocardium SPECT | 0.618 |  |
| 3042212 | Oral assessment panel | 0.615 |  |
| 1002345 | Substance use disorder score | 0.610 |  |
| 40768930 | Total balance tests score [PhenX] | 0.610 |  |
| 1616600 | Auditory brainstem response threshold Ear - left --click | 0.608 |  |
| 42869893 | Pathology report.section heading | 0.607 |  |
| 3009544 | EKG Study overall | 0.606 |  |
| 1617478 | Auditory brainstem response threshold Ear - right --click | 0.605 |  |
| 40758359 | Immunophenotyping study | 0.605 |  |
| 3028736 | Colposcopy study | 0.604 |  |
| 40768804 | Tissue Pathology biopsy report | 0.601 |  |
| 3049361 | Cytology report of Specimen Cyto stain | 0.597 |  |
| 649445 | Total score Reported.MNA-SF | 0.592 |  |
| 3022227 | Pathologist review of Blood tests | 0.591 | 1595 |
| 1988902 | Total score age adjusted | 0.591 |  |
| 40762347 | Cytologist who read Cyto stain of Specimen | 0.591 |  |
| 40768443 | Skin Pathology biopsy report | 0.587 | 1793 |
| 42527982 | Bone age method | 0.586 |  |
| 40762529 | Hematologist review of results | 0.585 |  |
| 3046857 | Flow cytometry study | 0.585 | 1054 |
| 3050380 | Cytology report of Cervical or vaginal smear or scraping Cyto stain | 0.584 | 798 |
| 3020692 | Microscopic exam [Interpretation] of Urine by Cytology | 0.580 | 163 |
| 3026593 | Cytologist who read Cyto stain of Cervical or vaginal smear or scraping | 0.577 | 109 |
| 3049717 | Cytology report of Urine Cyto stain | 0.574 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1354 | p-lupusak | form | 0% | name+unit | 9 | 0 |  | P -Lupusantikoagulantti | Plasma |  | Lupus anticoagulant panel - Plasma |
| 1355 | p-lupusak |  | 100% | name | 2978 | 100 |  | P -Lupusantikoagulantti | Plasma |  | Lupus anticoagulant panel - Plasma |
| 1356 | p-lupusak. |  | 100% | name | 6143 | 100 |  |  | Plasma |  | Lupus anticoagulant panel - Plasma |
| 1357 | p-pbmcbio |  | 100% | name | 440 | 100 |  |  | Plasma |  |  |
| 1358 | patlislaus |  | 100% | name | 454 | 100 |  |  |  |  |  |
| 1359 | ps-nieluag |  | 100% | name | 2331 | 100 |  |  | Pharyngeal secretion |  | Antigen [Presence] in Throat |
| 1360 | pt-aud-koj |  | 100% | name | 121 | 100 |  |  | Patient |  | Audiometry panel |
| 1361 | pt-audio |  | 100% | name | 661 | 100 |  |  | Patient |  | Audiometry panel |
| 1362 | pt-audio, |  | 100% | name | 249 | 100 |  |  | Patient |  | Audiometry panel |
| 1363 | pt-audio,tk |  | 100% | name | 446 | 100 |  |  | Patient |  | Audiometry panel |
| 1364 | pt-audio-1 | form | 2% | name+unit | 27 | 0 |  |  | Patient |  | Audiometry panel |
| 1365 | pt-audio-1 |  | 98% | name | 1274 | 100 |  |  | Patient |  | Audiometry panel |
| 1366 | pt-audio/i |  | 100% | name+values | 442 | 100 | [1, 1, 1, 1, 1, 1, 1, 1, 1] |  | Patient |  | Audiometry panel |
| 1367 | pt-audit |  | 100% | name+values | 113 | 100 | [0, 1, 1, 2, 3, 3.56, 4.44, 5, 8] |  | Patient |  | AUDIT total score [Score] |
| 1368 | pt-hembio |  | 100% | name | 128 | 100 |  |  | Patient |  | Hematopathology study |
| 1369 | pt-imutieg |  | 100% | name | 198 | 100 |  |  | Patient |  | Surgical pathology study |
| 1370 | pt-kudsop |  | 100% | name | 579 | 100 |  |  | Patient |  | Histocompatibility antigen typing |
| 1371 | pt-lausklf |  | 100% | name | 685 | 100 |  |  | Patient |  |  |
| 1372 | pt-lisäla2 |  | 100% | name | 886 | 100 |  |  | Patient |  |  |
| 1373 | pt-lisäla3 |  | 100% | name | 131 | 100 |  |  | Patient |  |  |
| 1374 | pt-lisälau |  | 100% | name | 11756 | 100 |  |  | Patient |  |  |
| 1375 | pt-lisäsyt |  | 100% | name | 2727 | 100 |  |  | Patient |  | Cytology study |
| 1376 | pt-luuspeg |  | 100% | name | 113 | 100 |  |  | Patient |  | Bone SPECT study |
| 1377 | pt-luustog |  | 100% | name | 1368 | 100 |  |  | Patient |  | Bone scan |
| 1378 | pt-luutih2 |  | 100% | name | 1595 | 100 |  |  | Patient |  | Bone density by DXA panel |
| 1379 | pt-luutih3 |  | 100% | name | 136 | 100 |  |  | Patient |  | Bone density by DXA panel |
| 1380 | pt-luutil2 |  | 100% | name | 1743 | 100 |  |  | Patient |  | Bone density by DXA panel |
| 1381 | pt-luutil3 |  | 100% | name | 267 | 100 |  |  | Patient |  | Bone density by DXA panel |
| 1382 | pt-rasukg |  | 100% | name | 109 | 100 |  |  | Patient |  | Stress echocardiogram study |
| 1383 | puheaudio |  | 100% | name | 156 | 100 |  |  |  |  | Speech audiometry panel |
| 1384 | äänesaudio |  | 100% | name | 2795 | 100 |  |  |  |  | Pure tone audiometry panel |

