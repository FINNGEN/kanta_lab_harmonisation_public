[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

**Those guesses exist only to fetch the candidate list. They have already done their job, and they carry no authority over your decision.** The earlier pass was told to write a name whenever the code gave it anything at all to work with, because a near-miss still retrieves the right neighbourhood of concepts while silence retrieves nothing. So a guess may be a careful reading or a shot in the dark, and nothing marks which. Use it as a pointer to where in the vocabulary to look, never as an answer to confirm. **Decide from the row's own `TEST_NAME`, `LongName`, `UNIT` and `deciles`.** When the row's evidence and the guess disagree, the row wins.

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
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess, which is what the search was run on. A search query, not a hypothesis you owe any deference to: it was written under instructions to guess rather than stay silent, so its confidence is not calibrated and a fluent name may rest on very little. When it is a panel name, the earlier pass judged the code to order a bundle rather than report one result — check that against the code yourself.

# How to read the evidence

A row is one **`TEST_NAME` + `UNIT`** combination, and that pair is what you are naming. Two rows of the same code with different units are two different observations and may well belong to two different LOINC concepts. Decide each row on its own.

**The name is the source of truth.** `prefix_meaning` and `suffix_meaning` were derived from the `TEST_NAME` string by an earlier step, so when a name is misspelled, truncated or locally invented, the decoded prefix and suffix are wrong in exactly the same way. Treat them as extra information that can confirm what the name says — never as something that outranks it. The specimen in particular is often spelled out as a Finnish word rather than carried by a prefix: `veri` = blood, `seerumi` = serum, `plasma` = plasma, `virtsa` = urine, `likvori` = cerebrospinal fluid, `uloste` = feces, `sylki` = saliva. `c-reaktiivinenproteiini,pikatesti,veri` names blood and has no decoded prefix at all — and its leading `c-` is the start of "C-reactive", not a specimen code.

**Missing values are not evidence.** `p_missing` describes this extract, not the laboratory test: a row with no values is a row where the numbers were not recorded or not carried through. Never conclude "no numbers, therefore qualitative". A test is qualitative when the CODE says so — the `-O` suffix, a `LongName` naming a qualitative or screening test, a component only ever reported as detected/not-detected.

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

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
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
Here is group 70.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3004446 | Plasmodium sp identified in Blood by Light microscopy | 1.000 |  |
| 3006120 | Parvovirus B19 IgG Ab [Units/volume] in Serum | 1.000 | 1457 |
| 3006451 | Walnut IgE Ab [Units/volume] in Serum | 1.000 | 922 |
| 3006923 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 16 |
| 3007015 | Cashew nut IgE Ab [Units/volume] in Serum | 1.000 | 1084 |
| 3007315 | Brazil Nut IgE Ab [Units/volume] in Serum | 1.000 | 1401 |
| 3008321 | Parvovirus B19 IgM Ab [Presence] in Serum | 1.000 | 1746 |
| 3009466 | Valproate [Moles/volume] in Serum or Plasma | 1.000 | 408 |
| 3009550 | Parvovirus B19 IgG Ab [Titer] in Serum | 1.000 | 1729 |
| 3011268 | Mumps virus IgM Ab [Presence] in Serum | 1.000 |  |
| 3012932 | Hazelnut IgE Ab [Units/volume] in Serum | 1.000 | 1241 |
| 3013721 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma | 1.000 | 19 |
| 3014435 | Carbamazepine 10,11-Epoxide [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3015883 | Cotinine [Presence] in Urine | 1.000 |  |
| 3018867 | Mumps virus IgG Ab [Units/volume] in Serum | 1.000 | 754 |
| 3018980 | carBAMazepine [Moles/volume] in Serum or Plasma | 1.000 | 671 |
| 3020485 | Acetaminophen [Moles/volume] in Serum or Plasma | 1.000 | 402 |
| 3024981 | Mumps virus IgG Ab [Titer] in Serum | 1.000 |  |
| 3027159 | OXcarbazepine [Moles/volume] in Serum or Plasma | 1.000 | 1659 |
| 3033882 | Carnitine [Moles/volume] in Serum or Plasma | 1.000 | 1409 |
| 3035544 | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma | 1.000 |  |
| 3035903 | Mumps virus Ab [Presence] in Serum | 1.000 |  |
| 3037492 | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma | 1.000 |  |
| 3044866 | Ovary Ab [Titer] in Serum | 1.000 |  |
| 3048689 | Calprotectin [Mass/mass] in Stool | 1.000 |  |
| 3021584 | Pregnancy associated plasma protein A [Units/volume] in Serum or Plasma | 0.983 | 767 |
| 3028027 | Mumps virus IgM Ab [Titer] in Serum | 0.977 |  |
| 46236949 | Alanine aminotransferase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.975 |  |
| 3002715 | Mumps virus IgG+IgM Ab [Units/volume] in Serum | 0.973 |  |
| 3014183 | Mumps virus IgM Ab [Units/volume] in Serum | 0.972 |  |
| 3028498 | Mumps virus IgG Ab [Presence] in Serum | 0.970 | 1007 |
| 3035400 | Alkaline phosphatase.liver [Enzymatic activity/volume] in Serum or Plasma | 0.970 | 1919 |
| 3022915 | Valproate Free [Moles/volume] in Serum or Plasma | 0.968 |  |
| 3011841 | English Walnut IgE Ab [Units/volume] in Serum | 0.966 |  |
| 3024338 | Parvovirus B19 IgG+IgM Ab [Units/volume] in Serum | 0.966 |  |
| 3048406 | Carbamazepine 10,11-epoxide free [Moles/volume] in Serum or Plasma | 0.963 |  |
| 647241 | Brazil Nut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.963 |  |
| 3016754 | Carbamazepine 10,11-Epoxide [Mass/volume] in Serum or Plasma | 0.962 |  |
| 3025709 | Mumps virus IgG Ab [Units/volume] in Serum by Immunoassay | 0.961 | 1789 |
| 3020457 | Parvovirus B19 IgG Ab [Units/volume] in Serum by Immunoassay | 0.960 | 1014 |
| 3008560 | Mumps virus IgM Ab [Presence] in Serum by Immunoassay | 0.958 |  |
| 3035995 | Alkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.958 | 23 |
| 3027119 | Mumps virus Ab [Titer] in Serum | 0.958 |  |
| 3024774 | Black Walnut IgE Ab [Units/volume] in Serum | 0.955 |  |
| 3000978 | Cashew nut IgG Ab [Units/volume] in Serum | 0.954 |  |
| 3010054 | Hazelnut Pollen IgE Ab [Units/volume] in Serum | 0.954 | 1650 |
| 647643 | Cashew nut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.954 |  |
| 3015064 | Parvovirus B19 IgM Ab [Titer] in Serum | 0.953 | 1462 |
| 3003196 | Cardiolipin IgA Ab [Units/volume] in Serum or Plasma | 0.953 |  |
| 3001139 | carBAMazepine free [Moles/volume] in Serum or Plasma | 0.953 |  |
| 3028639 | carBAMazepine [Mass/volume] in Serum or Plasma | 0.952 |  |
| 3025355 | Hazelnut IgG Ab [Units/volume] in Serum | 0.952 |  |
| 3001365 | Mumps virus Ab [Presence] in Serum by Immunoassay | 0.951 |  |
| 3006410 | Parvovirus B19 IgG Ab [Presence] in Serum | 0.951 | 1744 |
| 3012494 | Peanut IgE Ab [Units/volume] in Serum | 0.950 | 611 |
| 645361 | Hazelnut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.950 |  |
| 42529010 | Calprotectin [Mass/volume] in Stool | 0.949 |  |
| 645763 | Pecan nut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.949 |  |
| 3018027 | Mumps virus Ab [Units/volume] in Serum | 0.947 |  |
| 3043961 | Parvovirus B19 IgM Ab [Presence] in Serum by Immunoassay | 0.946 | 1747 |
| 3023289 | California Walnut IgE Ab [Units/volume] in Serum | 0.945 |  |
| 3015813 | Cardiolipin IgM Ab [Units/volume] in Serum by Immunoassay | 0.945 | 505 |
| 3007221 | Parvovirus B19 Ab [Units/volume] in Serum | 0.943 |  |
| 3013226 | Pecan or Hickory Nut IgE Ab [Units/volume] in Serum | 0.943 | 1096 |
| 3026515 | Parvovirus B19 IgM Ab [Units/volume] in Serum | 0.943 | 1280 |
| 1617628 | carBAMazepine [Moles/volume] in Serum or Plasma --trough | 0.942 |  |
| 3012647 | Walnut IgG Ab [Units/volume] in Serum | 0.942 |  |
| 3009273 | Parvovirus B19 IgG Ab [Titer] in Serum by Immunofluorescence | 0.940 |  |
| 3038866 | Parvovirus B19 IgM Ab [Presence] in Serum by Immunofluorescence | 0.939 |  |
| 3009041 | Cardiolipin IgG Ab [Units/volume] in Serum by Immunoassay | 0.939 | 504 |
| 3011580 | Brazil Nut IgG Ab [Units/volume] in Serum | 0.938 |  |
| 3016201 | Valproate [Mass/volume] in Serum or Plasma | 0.938 |  |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.937 |  |
| 3011781 | Mumps virus IgG Ab [Presence] in Serum by Immunoassay | 0.937 | 1008 |
| 3015036 | Mumps virus IgG Ab [Titer] in Serum by Immunofluorescence | 0.936 |  |
| 3051741 | Pregnancy associated plasma protein A [Mass/volume] in Serum or Plasma | 0.935 |  |
| 3018589 | Mumps virus Ag [Presence] in Serum | 0.935 |  |
| 3005398 | Coconut IgE Ab [Units/volume] in Serum | 0.934 | 1916 |
| 3003461 | Cardiolipin Ab [Units/volume] in Serum | 0.933 |  |
| 3028089 | Alkaline phosphatase isoenzyme [Units/volume] in Serum or Plasma | 0.933 |  |
| 46235106 | Alanine aminotransferase [Enzymatic activity/volume] in Blood | 0.933 |  |
| 36303754 | OXcarbazepine [Moles/volume] in Serum or Plasma --trough | 0.933 |  |
| 1617081 | carBAMazepine [Moles/volume] in Serum or Plasma --peak | 0.931 |  |
| 3026190 | Carbamazepine 10,11-Epoxide.bound [Mass/volume] in Serum or Plasma | 0.930 |  |
| 3028110 | Bile acid [Moles/volume] in Serum or Plasma | 0.930 |  |
| 3042333 | Brazil Nut IgE Ab/IgE total in Serum | 0.930 |  |
| 3012794 | Mumps virus IgG Ab [Units/volume] in Body fluid | 0.929 |  |
| 3026253 | Mumps virus IgM Ab [Units/volume] in Serum by Immunoassay | 0.929 |  |
| 3025612 | Black Western Walnut IgE Ab [Units/volume] in Serum | 0.926 |  |
| 3017215 | Carnitine esters [Moles/volume] in Serum or Plasma | 0.926 | 1632 |
| 3036148 | OXcarbazepine [Mass/volume] in Serum or Plasma | 0.926 |  |
| 648388 | Mumps virus IgG Ab [Measurement] in Serum | 0.926 |  |
| 3051272 | Parvovirus B19 IgG Ab [Units/volume] in Body fluid | 0.926 |  |
| 3002617 | Acetaminophen [Mass/volume] in Serum or Plasma | 0.926 |  |
| 3001936 | Carbamazepine 10,11-epoxide free [Mass/volume] in Serum or Plasma | 0.925 |  |
| 46235077 | Alkaline phosphatase [Enzymatic activity/volume] in Serum, Plasma or Blood | 0.925 |  |
| 3036185 | Alkaline phosphatase.liver 2 [Enzymatic activity/volume] in Serum or Plasma | 0.925 |  |
| 40758717 | OXcarbazepine + 10-Hydroxycarbazepine [Moles/volume] in Serum or Plasma | 0.924 |  |
| 3052099 | Cashew nut IgE Ab/IgE total in Serum | 0.923 |  |
| 3035062 | Alkaline phosphatase.liver 1 [Enzymatic activity/volume] in Serum or Plasma | 0.923 |  |
| 3021600 | Valproate Free [Mass/volume] in Serum or Plasma | 0.923 |  |
| 3000722 | Carnitine free (C0) [Moles/volume] in Serum or Plasma | 0.922 | 1418 |
| 3020259 | Cardiolipin IgG Ab [Titer] in Serum | 0.920 |  |
| 3014661 | Parvovirus B19 IgM Ab [Presence] in Serum by Immunoblot | 0.920 |  |
| 3035891 | Mumps virus soluble Ab [Titer] in Serum | 0.919 |  |
| 40765841 | Cashew nut IgG Ab [Mass/volume] in Serum | 0.918 |  |
| 3026325 | Ovary Ab [Titer] in Serum by Immunofluorescence | 0.918 |  |
| 649057 | Parvovirus B19 IgG Ab [Measurement] in Serum | 0.918 |  |
| 3013478 | Mumps virus soluble Ab [Units/volume] in Serum | 0.918 |  |
| 647626 | Cashew nut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.917 |  |
| 3022758 | Parvovirus B19 IgG Ab [Presence] in Serum by Immunoassay | 0.917 | 1745 |
| 3041778 | Walnut IgE Ab/IgE total in Serum | 0.916 |  |
| 647057 | Hazelnut Pollen IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.916 |  |
| 40767663 | Brazil Nut recombinant (rBer e) 1 IgE Ab [Units/volume] in Serum | 0.915 |  |
| 646486 | English Walnut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.915 |  |
| 3026744 | English Walnut Pollen IgE Ab [Units/volume] in Serum | 0.914 |  |
| 645719 | Mumps virus Ab [Measurement] in Serum | 0.913 |  |
| 3040735 | Parvovirus B19 IgG Ab [Presence] in Serum by Immunofluorescence | 0.913 |  |
| 3052577 | Aspartate aminotransferase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.912 |  |
| 3041451 | Hazelnut IgE Ab/IgE total in Serum | 0.912 |  |
| 40759329 | Cashew nut IgG4 Ab [Mass/volume] in Serum | 0.912 |  |
| 3026187 | Black Walnut Pollen IgE Ab [Units/volume] in Serum | 0.912 |  |
| 40763381 | OXcarbazepine [Moles/volume] in Specimen | 0.912 |  |
| 3016120 | Mumps virus IgM Ab [Titer] in Serum by Immunofluorescence | 0.912 |  |
| 3038458 | Plasmodium sp [Presence] in Blood by Light microscopy | 0.912 |  |
| 3020147 | Parvovirus B19 IgM Ab [Units/volume] in Serum by Immunoassay | 0.912 | 1013 |
| 40759319 | Brazil Nut IgG4 Ab [Mass/volume] in Serum | 0.911 |  |
| 645515 | Pecan nut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.911 |  |
| 40765812 | Hazelnut IgG Ab [Mass/volume] in Serum | 0.910 |  |
| 3027569 | carBAMazepine.bound [Mass/volume] in Serum or Plasma | 0.909 |  |
| 646349 | Brazil Nut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.909 |  |
| 40765813 | Brazil Nut IgG Ab [Mass/volume] in Serum | 0.909 |  |
| 3010630 | Parvovirus B19 Ab [Units/volume] in Serum by Immunoassay | 0.908 |  |
| 3052018 | Alanine aminotransferase.macromolecular [Enzymatic activity/volume] in Serum or Plasma | 0.908 |  |
| 645926 | Mumps virus IgM Ab [Measurement] in Serum | 0.907 |  |
| 3005755 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma by With P-5'-P | 0.907 |  |
| 646897 | carBAMazepine [Measurement] in Serum or Plasma | 0.905 |  |
| 648629 | Hazelnut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.905 |  |
| 3033536 | Pecan or Hickory Nut IgG Ab [Units/volume] in Serum | 0.905 |  |
| 3025911 | Cotinine [Mass/volume] in Urine | 0.904 | 674 |
| 3009118 | Cardiolipin IgA Ab [Units/volume] in Serum by Immunoassay | 0.904 | 887 |
| 3010354 | Pecan or Hickory Tree IgE Ab [Units/volume] in Serum | 0.904 | 1615 |
| 3025587 | Parvovirus B19 IgM Ab [Titer] in Serum by Immunofluorescence | 0.903 |  |
| 3044690 | Nicotine+Cotinine [Presence] in Urine | 0.903 |  |
| 3036955 | Alkaline phosphatase.liver/Alkaline phosphatase.total in Serum or Plasma | 0.901 | 1664 |
| 3027716 | Peanut IgG Ab [Units/volume] in Serum | 0.901 |  |
| 40762708 | Cotinine [Presence] in Urine by Screen method | 0.901 |  |
| 3020013 | Alkaline phosphatase.intestinal [Enzymatic activity/volume] in Serum or Plasma | 0.900 |  |
| 40768453 | Hazelnut native (nCor a) 9 IgE Ab [Units/volume] in Serum | 0.900 |  |
| 3035798 | Bile acid.dihydroxy [Moles/volume] in Serum or Plasma | 0.899 |  |
| 3014431 | Cardiolipin Ab [Units/volume] in Serum by Immunoassay | 0.898 |  |
| 3042891 | Cardiolipin IgM Ab [Mass/volume] in Serum | 0.898 |  |
| 3043821 | Protein and Glucose panel - Urine by Test strip | 0.898 |  |
| 3034898 | Cotinine [Presence] in Urine by Confirmatory method | 0.897 |  |
| 44816864 | carBAMazepine [Mass/volume] in Serum or Plasma --trough | 0.897 |  |
| 3023985 | carBAMazepine free [Mass/volume] in Serum or Plasma | 0.897 |  |
| 3014002 | Cardiolipin IgM Ab [Titer] in Serum | 0.896 |  |
| 40759404 | Hazelnut IgG4 Ab [Mass/volume] in Serum | 0.896 |  |
| 3037081 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma by With P-5'-P | 0.896 |  |
| 40763889 | Cotinine [Presence] in Serum or Plasma | 0.896 |  |
| 3028415 | carBAMazepine [Presence] in Serum or Plasma | 0.896 |  |
| 42868672 | Acetaminophen [Moles/volume] in Serum or Plasma by Screen method | 0.896 | 1819 |
| 3965143 | Calprotectin [Mass/volume] in Serum or Plasma | 0.895 |  |
| 648099 | Peanut IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.894 |  |
| 3011592 | Carotene [Moles/volume] in Serum or Plasma | 0.893 |  |
| 3019631 | Plasmodium sp identified in Blood by Thick film | 0.892 |  |
| 40763007 | OXcarbazepine [Moles/volume] in Urine | 0.891 |  |
| 3019056 | Alanine aminotransferase/Aspartate aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.890 |  |
| 3046159 | Cardiolipin IgG Ab [Mass/volume] in Serum | 0.890 |  |
| 3020233 | Acid phosphatase [Enzymatic activity/volume] in Serum or Plasma | 0.889 |  |
| 3007970 | Alkaline phosphatase.bile [Enzymatic activity/volume] in Serum or Plasma | 0.889 |  |
| 649561 | Cotinine [Measurement] in Urine | 0.889 |  |
| 3001110 | Alkaline phosphatase [Enzymatic activity/volume] in Blood | 0.888 |  |
| 3003792 | Aspartate aminotransferase [Enzymatic activity/volume] in Body fluid | 0.888 |  |
| 3036648 | Ovary Ab [Units/volume] in Serum | 0.888 |  |
| 3034882 | Bile acid.trihydroxy [Moles/volume] in Serum or Plasma | 0.887 |  |
| 3026942 | Alkaline phosphatase.liver 2/Alkaline phosphatase.total in Serum or Plasma | 0.887 |  |
| 40767662 | Cashew nut recombinant (rAna o) 2 IgE Ab [Units/volume] in Serum | 0.886 |  |
| 649315 | Aspartate aminotransferase [Measurement] in Serum or Plasma | 0.886 |  |
| 3020846 | Acetaminophen [Moles/volume] in Specimen | 0.886 |  |
| 3001467 | Alkaline phosphatase.bone [Enzymatic activity/volume] in Serum or Plasma | 0.885 | 1850 |
| 1001530 | Calprotectin [Mass/volume] in Synovial fluid | 0.885 |  |
| 3042781 | Aspartate aminotransferase [Enzymatic activity/volume] (Maximum value during study) in Serum or Plasma | 0.885 |  |
| 1176003 | Microscopic observation [Identifier] in Skin by Gram stain | 0.884 |  |
| 3000784 | Alanine aminotransferase [Enzymatic activity/volume] in Body fluid | 0.884 |  |
| 42528717 | Cashew nut recombinant (rAna o) 3 IgE Ab [Units/volume] in Serum | 0.884 |  |
| 3028622 | Alkaline phosphatase.lung [Enzymatic activity/volume] in Serum or Plasma | 0.883 |  |
| 40768458 | Peanut native (nAra h) 2 IgE Ab [Units/volume] in Serum | 0.883 |  |
| 3022620 | Valproate [Mass/volume] in Serum or Plasma --trough | 0.883 |  |
| 645672 | Alanine aminotransferase [Measurement] in Serum or Plasma | 0.883 |  |
| 3041601 | Coconut IgE Ab/IgE total in Serum | 0.883 |  |
| 3018359 | Ovary Ab [Presence] in Serum | 0.882 |  |
| 3002978 | Plasmodium sp identified in Blood by Thin film | 0.882 |  |
| 3025939 | Karyotype [Identifier] in Blood or Tissue Nominal | 0.882 | 790 |
| 40768459 | Peanut native (nAra h) 3 IgE Ab [Units/volume] in Serum | 0.881 |  |
| 3021434 | Alkaline phosphatase.liver 1/Alkaline phosphatase.total in Serum or Plasma | 0.881 |  |
| 3029427 | Karyotype [Identifier] in Blood or Tissue Narrative | 0.881 |  |
| 646711 | Parvovirus B19 IgM Ab [Measurement] in Serum | 0.880 |  |
| 1259873 | Carbamazepine 10,11-Epoxide [Mass/volume] in Urine | 0.879 |  |
| 3023456 | Valproate Free/Valproate.total in Serum or Plasma | 0.878 |  |
| 3027388 | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma by No addition of P-5'-P | 0.878 |  |
| 3027165 | Pistachio IgE Ab [Units/volume] in Serum | 0.878 | 1583 |
| 3013573 | Cardiolipin IgA Ab [Titer] in Serum | 0.877 |  |
| 3027148 | Coconut IgG Ab [Units/volume] in Serum | 0.877 |  |
| 3005050 | Acylcarnitine [Moles/volume] in Serum or Plasma | 0.876 |  |
| 646891 | Cardiolipin Ab [Measurement] in Serum | 0.876 |  |
| 3048469 | 10-Hydroxycarbazepine [Moles/volume] in Serum or Plasma | 0.876 | 1473 |
| 3028136 | Grey Alder IgE Ab [Units/volume] in Serum | 0.876 |  |
| 3039563 | Pecan or Hickory Nut IgE Ab/IgE total in Serum | 0.876 |  |
| 43055493 | OXcarbazepine [Mass/volume] in Serum or Plasma --trough | 0.876 |  |
| 40768457 | Peanut native (nAra h) 1 IgE Ab [Units/volume] in Serum | 0.876 |  |
| 36660327 | Microscopic observation [Identifier] in Skin by Acid fast stain | 0.875 |  |
| 3047202 | Parvovirus B19 IgG Ab [Ratio] in Serum --1st specimen/2nd specimen | 0.874 |  |
| 645568 | Cardiolipin IgG Ab [Measurement] in Serum | 0.874 |  |
| 3015103 | White Alder IgE Ab [Units/volume] in Serum | 0.874 |  |
| 40758329 | Carnitine [Moles/volume] in Body fluid | 0.873 |  |
| 3018553 | Bordetella parapertussis Ab [Presence] in Serum | 0.873 |  |
| 3002214 | Alkaline phosphatase.renal [Enzymatic activity/volume] in Serum or Plasma | 0.873 |  |
| 40765840 | Pecan or Hickory Nut IgG Ab [Mass/volume] in Serum | 0.872 |  |
| 646492 | Carnitine [Measurement] in Serum or Plasma | 0.870 |  |
| 3038191 | Carnitine [Moles/volume] in Urine | 0.869 |  |
| 36305398 | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma by No addition of P-5'-P | 0.869 |  |
| 3025365 | Pea IgE Ab [Units/volume] in Serum | 0.868 |  |
| 3022893 | Aspartate aminotransferase/Alanine aminotransferase [Enzymatic activity ratio] in Serum or Plasma | 0.868 |  |
| 3046126 | Bordetella parapertussis Ab [Presence] in Body fluid | 0.868 |  |
| 3008509 | Bordetella parapertussis Ag [Presence] in Specimen | 0.868 |  |
| 3046302 | Parvovirus B19 IgG Ab [Ratio] in Serum by Immunoassay --1st specimen/2nd specimen | 0.867 |  |
| 21494261 | Hazelnut recombinant (rCor a) 14 IgE Ab [Units/volume] in Serum | 0.866 |  |
| 3013094 | Hepatic function 2000 panel - Serum or Plasma | 0.866 |  |
| 648931 | Acetaminophen [Measurement] in Serum or Plasma | 0.866 |  |
| 40763980 | Peanut IgE Ab/IgE total in Serum | 0.865 |  |
| 3041289 | Cotinine [Presence] in Meconium | 0.865 |  |
| 3003860 | Alkaline phosphatase.regan [Enzymatic activity/volume] in Serum or Plasma | 0.865 |  |
| 1988395 | Hazelnut Pollen IgG Ab [Mass/volume] in Serum | 0.865 |  |
| 645154 | Ovary Ab [Measurement] in Serum | 0.864 |  |
| 3014064 | Pregnancy associated plasma protein A [Multiple of the median] in Serum or Plasma | 0.864 |  |
| 3045820 | Cotinine/Creatinine [Mass Ratio] in Urine | 0.863 |  |
| 3008543 | Brazilian Rubber Tree IgE Ab [Units/volume] in Serum | 0.863 |  |
| 40758694 | Phenacetin [Moles/volume] in Serum or Plasma | 0.862 |  |
| 3043792 | Cardiolipin Ab [Presence] in Serum by Immunoassay | 0.862 |  |
| 40767665 | Peanut recombinant (rAra h) 9 IgE Ab [Units/volume] in Serum | 0.862 |  |
| 3034274 | Bile acid [Moles/volume] in Serum --fasting | 0.861 |  |
| 3003388 | Carnitine [Presence] in Serum or Plasma | 0.861 |  |
| 3018524 | Acetylcarnitine (C2) [Moles/volume] in Serum or Plasma | 0.858 |  |
| 3006165 | Parasite identified in Blood by Light microscopy | 0.858 |  |
| 3040624 | Acetaminophen [Moles/volume] in Urine | 0.857 |  |
| 1091810 | Bordetella parapertussis DNA [Presence] in Specimen | 0.857 |  |
| 3016664 | Ovary IgG Ab [Titer] in Serum by Immunofluorescence | 0.854 |  |
| 645685 | Peanut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.854 |  |
| 3022001 | Microscopic observation [Identifier] in Skin by KOH preparation | 0.853 |  |
| 46235831 | Pregnancy associated plasma protein A [Multiple of the median] adjusted in Serum or Plasma | 0.853 |  |
| 3021583 | Cardiolipin Ab [Presence] in Serum | 0.853 |  |
| 3031879 | Bile acid fractions panel [Moles/volume] - Serum or Plasma | 0.853 |  |
| 3038974 | Carnitine esters/Carnitine.free (C0) [Molar ratio] in Serum or Plasma | 0.853 |  |
| 43533702 | Valproate [Mass/volume] in Serum or Plasma --peak | 0.853 |  |
| 3014591 | Smooth Alder IgE Ab [Units/volume] in Serum | 0.851 |  |
| 40759348 | Coconut IgG4 Ab [Mass/volume] in Serum | 0.851 |  |
| 40763008 | OXcarbazepine [Moles/volume] in Gastric fluid | 0.850 |  |
| 3053010 | Karyotype [Identifier] in Cord blood Nominal | 0.850 |  |
| 40765816 | Coconut IgG Ab [Mass/volume] in Serum | 0.849 |  |
| 3030363 | Parvovirus B19 IgM Ab [Ratio] in Serum --1st specimen/2nd specimen | 0.847 |  |
| 46235718 | Delta aPTT [Time] in Platelet poor plasma by Coagulation assay | 0.847 |  |
| 3008849 | Trypanosoma sp identified in Blood by Light microscopy | 0.845 |  |
| 3039361 | Rubella virus IgG Ab avidity [Ratio] in Serum by Immunoassay | 0.845 |  |
| 3045730 | Cotinine [Moles/volume] in Urine | 0.844 |  |
| 3019027 | Nicotine [Presence] in Urine | 0.843 |  |
| 3032298 | Plasmodium stage [Identifier] in Blood by Light microscopy | 0.843 |  |
| 3012731 | Oxazepam [Moles/volume] in Serum or Plasma | 0.843 |  |
| 3028890 | Parvovirus B19 IgM Ab [Ratio] in Serum by Immunoassay --1st specimen/2nd specimen | 0.842 |  |
| 3008517 | Red Alder IgE Ab [Units/volume] in Serum | 0.841 |  |
| 3038126 | Propionylcarnitine (C3) [Moles/volume] in Serum or Plasma | 0.841 |  |
| 647838 | Coconut IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.841 |  |
| 3026863 | Hepatic function 1996 panel - Serum or Plasma | 0.841 |  |
| 21494219 | Acetaminophen free [Mass/volume] in Serum or Plasma | 0.841 |  |
| 3049559 | Karyotype [Identifier] in Blood or Tissue by High resolution Nominal | 0.840 |  |
| 3021905 | Carnitine free (C0)/Carnitine.total in Serum or Plasma | 0.840 |  |
| 3028297 | Cotinine [Mass/volume] in Specimen | 0.840 |  |
| 3011173 | Microscopic observation [Identifier] in Tissue by Hematoxylin and eosin stain | 0.840 |  |
| 3011766 | Ovary Ab [Presence] in Serum by Immunofluorescence | 0.839 |  |
| 40760885 | Valproate.free and Valproate panel - Serum or Plasma | 0.839 |  |
| 3015266 | Ovary IgG Ab [Units/volume] in Serum | 0.838 |  |
| 3003709 | Acetaminophen [Presence] in Serum or Plasma | 0.838 | 829 |
| 649058 | Ovary IgG Ab [Measurement] in Serum | 0.835 |  |
| 3023593 | Bordetella pertussis Ab [Presence] in Serum | 0.835 |  |
| 1259794 | Measles virus IgG Ab avidity [Ratio] in Serum by Immunoassay | 0.834 |  |
| 42528941 | Spontaneous clot formation [Time] in Platelet poor plasma | 0.834 |  |
| 3026217 | Bile acid [Mass/volume] in Serum | 0.833 |  |
| 43055646 | Cotinine [Mass/volume] in Urine by Screen method | 0.833 |  |
| 40758651 | Acetazolamide [Moles/volume] in Serum or Plasma | 0.832 |  |
| 3020155 | Valproate Free [Mass/volume] in Saliva (oral fluid) | 0.832 |  |
| 3966408 | Brazil Nut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.832 |  |
| 3042545 | Alkaline phosphatase.bile/Alkaline phosphatase.total in Serum or Plasma | 0.832 |  |
| 3026719 | Microscopic observation [Identifier] in Skin by Tzanck smear | 0.832 |  |
| 3005080 | Thrombin time in Platelet poor plasma from Control by Coagulation assay | 0.832 |  |
| 3026658 | IgG.monoclonal [Presence] in Serum | 0.830 |  |
| 3008257 | IgM.monoclonal [Presence] in Serum | 0.829 |  |
| 3043425 | Karyotype [Identifier] in Bone marrow Nominal | 0.829 | 1777 |
| 3001690 | Carnitine free (C0) [Moles/volume] in Urine | 0.828 |  |
| 3014714 | Pregnancy specific protein 1 [Mass/volume] in Serum | 0.826 |  |
| 3001599 | Carotene [Mass/volume] in Serum or Plasma | 0.826 |  |
| 3037012 | CV2 IgG Ab [Titer] in Cerebral spinal fluid | 0.826 |  |
| 3008815 | Elder IgE Ab [Units/volume] in Serum | 0.825 |  |
| 3041117 | Carnitine free (C0) [Moles/volume] in Amniotic fluid | 0.825 |  |
| 3044114 | Bordetella parapertussis [Presence] in Specimen by Organism specific culture | 0.825 |  |
| 3028852 | Carbamazepine 10,11-Epoxide [Mass/volume] in DBS | 0.825 |  |
| 42528945 | Clot formation lag time in Platelet poor plasma | 0.824 |  |
| 3002069 | Alkaline phosphatase.bone/Alkaline phosphatase.total in Serum or Plasma | 0.824 | 1666 |
| 3024473 | Bile acid.dihydroxy [Mass/volume] in Serum or Plasma | 0.823 |  |
| 43533747 | Bile acid [Moles/volume] in Urine | 0.823 |  |
| 42868437 | Bordetella parapertussis IgG Ab [Presence] in Serum by Immunoassay | 0.822 |  |
| 648128 | Coconut milk IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.822 |  |
| 3037998 | Microscopic observation [Identifier] in Specimen by Hematoxylin and eosin stain | 0.821 |  |
| 3026138 | Bile acid.trihydroxy [Mass/volume] in Serum or Plasma | 0.821 |  |
| 3027963 | IgG [Presence] in 24 hour Urine by Immunoelectrophoresis | 0.821 |  |
| 3023055 | Clot Lysis [Time] in Platelet poor plasma by Coagulation assay | 0.820 |  |
| 3013860 | IgM [Presence] in 24 hour Urine by Immunoelectrophoresis | 0.819 |  |
| 36659620 | Liver diseases autoimmune Ab panel - Serum or Plasma | 0.819 |  |
| 3026025 | Cotinine cutoff [Mass/volume] in Urine | 0.819 |  |
| 3029954 | Bile acid [Moles/volume] in Body fluid | 0.819 |  |
| 40761535 | Cells panel - Urine sediment | 0.818 |  |
| 3028701 | Sulfatide IgG Ab [Titer] in Cerebral spinal fluid | 0.818 |  |
| 3001977 | Microscopic observation [Identifier] in Tissue by Hematoxylin-eosin-Mayers progressive stain | 0.818 |  |
| 3046486 | Bordetella pertussis Yamaguchi Ab [Presence] in Serum | 0.817 |  |
| 3018279 | Valproate.protein bound [Mass/volume] in Serum or Plasma | 0.817 |  |
| 3022024 | Gamma globulin [Presence] in 24 hour Urine | 0.817 |  |
| 3035969 | Recalcification time in Platelet poor plasma by Coagulation assay | 0.816 |  |
| 3010153 | Plasmodium sp identified in Tissue by Thick film | 0.816 |  |
| 3005839 | 10-Hydroxycarbazepine [Mass/volume] in Serum or Plasma | 0.816 |  |
| 37020287 | Cotinine [Mass/volume] in Urine by Confirmatory method | 0.816 |  |
| 3006028 | Cotinine [Mass/volume] in Serum or Plasma | 0.816 |  |
| 3019923 | Valproate [Mass/volume] in Urine | 0.816 |  |
| 3023901 | Trivittatus virus Ab [Titer] in Cerebral spinal fluid | 0.815 |  |
| 40761533 | Casts panel - Urine sediment | 0.815 |  |
| 3019249 | Bordetella pertussis Ab [Presence] in Specimen | 0.815 |  |
| 40763973 | Grey Alder IgE Ab/IgE total in Serum | 0.814 |  |
| 3044503 | IgG [Presence] in 24 hour Urine by Immunofixation | 0.814 |  |
| 3043524 | Pregnancy associated plasma protein A multiple of the median [Percentile] | 0.814 |  |
| 3021959 | Cocoa IgE Ab [Units/volume] in Serum | 0.813 |  |
| 1761868 | Lipid panel - Serum or Plasma | 0.812 |  |
| 3037666 | Prothrombin time (PT) in Platelet poor plasma by Coagulation assay | 0.812 |  |
| 3964953 | Coconut IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.812 |  |
| 3008860 | Bordetella pertussis IgM Ab [Presence] in Serum | 0.811 |  |
| 3023949 | Allscale IgE Ab [Units/volume] in Serum | 0.811 |  |
| 3033762 | Parietal cell Ab [Titer] in Cerebral spinal fluid | 0.811 |  |
| 3011531 | Valproate [Mass/volume] in Body fluid | 0.811 |  |
| 40761534 | Crystals panel - Urine sediment | 0.810 |  |
| 3001133 | Recalcification time in Platelet poor plasma from Control by Coagulation assay | 0.810 |  |
| 36660625 | Protein.monoclonal [Presence] in Serum or Plasma | 0.810 |  |
| 3045239 | IgM [Presence] in 24 hour Urine by Immunofixation | 0.809 |  |
| 3024030 | Sulfatide IgM Ab [Titer] in Cerebral spinal fluid | 0.807 |  |
| 40767667 | Black Alder recombinant (rAln g) 1 IgE Ab [Units/volume] in Serum | 0.806 |  |
| 3024218 | Fig IgE Ab [Units/volume] in Serum | 0.806 |  |
| 3044788 | Reagin Ab [Titer] in Cerebral spinal fluid | 0.806 |  |
| 3025889 | Chlamydia sp Ab [Titer] in Cerebral spinal fluid | 0.804 |  |
| 40760109 | Toxoplasma gondii IgG Ab avidity [Ratio] in Serum by Immunoassay | 0.804 |  |
| 3012288 | Lymphocytic choriomeningitis virus Ab [Titer] in Cerebral spinal fluid | 0.803 |  |
| 3025251 | Thyroperoxidase Ab [Titer] in Cerebral spinal fluid by Latex agglutination | 0.802 |  |
| 3036910 | Microscopic observation [Identifier] in Tissue by Trichrome stain | 0.801 | 894 |
| 3009264 | Phenytoin Free [Moles/volume] in Serum or Plasma | 0.801 | 1581 |
| 3021339 | Microscopic observation [Identifier] in Tissue by Wright Giemsa stain | 0.801 |  |
| 3016088 | Carotene.alpha [Moles/volume] in Plasma | 0.801 |  |
| 3043725 | Clot Lysis [Time] in Control Platelet poor plasma by Coagulation assay | 0.801 |  |
| 3034099 | Cytomegalovirus Ab [Titer] in Cerebral spinal fluid | 0.800 |  |
| 3033891 | Prothrombin time (PT) in Platelet poor plasma from Control by Coagulation assay | 0.800 |  |
| 3016031 | Almond IgE Ab [Units/volume] in Serum | 0.800 | 1024 |
| 3047220 | Lambda light chains [Presence] in 24 hour Urine | 0.798 |  |
| 3004993 | Microscopic observation [Identifier] in Superficial tissue fine needle aspirate by Cyto stain | 0.797 |  |
| 1091858 | Prothrombin time (PT) factor substitution [Time Ratio] in Control Platelet poor plasma by Coagulation assay --2H post incubation with 1:1 normal plasma | 0.797 |  |
| 3027785 | IgA.monoclonal [Presence] in Serum | 0.797 |  |
| 3030561 | Karyotype [Identifier] in Specimen Nominal | 0.797 |  |
| 44816799 | Beta sitosterol [Moles/volume] in Serum or Plasma | 0.796 |  |
| 3023688 | Beta globulin [Presence] in 24 hour Urine | 0.796 |  |
| 3015759 | IgM [Presence] in Serum | 0.794 |  |
| 3008143 | IgG [Presence] in Serum | 0.792 |  |
| 42868409 | Thrombin time.high dose in Platelet poor plasma by Coagulation assay | 0.792 |  |
| 3005812 | Immunoglobulin light chains [Presence] in 24 hour Urine | 0.791 |  |
| 3018002 | Babesia microti identified in Blood by Light microscopy | 0.791 |  |
| 42527969 | Liver diseases autoimmune IgG panel - Serum or Plasma by Line blot | 0.791 |  |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.790 |  |
| 3034022 | Lactate dehydrogenase panel - Serum or Plasma | 0.790 |  |
| 36305978 | Lambda light chains [Presence] in 24 hour Urine by Immunofixation | 0.790 |  |
| 40759045 | IgM.monoclonal [Presence] in Serum by Immunoelectrophoresis | 0.790 |  |
| 1175909 | Lipoprotein metabolism panel - Serum or Plasma | 0.789 |  |
| 3013127 | IgA [Presence] in 24 hour Urine by Immunoelectrophoresis | 0.788 |  |
| 40759042 | IgG.monoclonal [Presence] in Serum by Immunoelectrophoresis | 0.788 |  |
| 40761536 | Microorganisms panel - Urine sediment | 0.786 |  |
| 3015504 | Ceruloplasmin [Mass/volume] in Body fluid | 0.785 |  |
| 40762155 | Lipoprofile panel - Serum or Plasma | 0.785 |  |
| 3008518 | Immunoglobulin light chains [Presence] in Serum | 0.784 |  |
| 3013005 | Retinol [Moles/volume] in Serum or Plasma | 0.784 | 942 |
| 40760081 | Ovary IgG Ab [Presence] in Serum by Immunofluorescence | 0.782 |  |
| 40762358 | Karyotype [Identifier] in Blood or Tissue by FISH Narrative | 0.781 |  |
| 3034356 | Lactoferrin [Mass/volume] in Stool | 0.780 |  |
| 3008561 | Activated protein C resistance [Time Ratio] in Platelet poor plasma by Coagulation assay | 0.779 | 797 |
| 3053027 | Karyotype [Identifier] in Urine Nominal | 0.779 |  |
| 3035711 | Parasite identified in Serum by Light microscopy | 0.776 |  |
| 3041668 | Urinalysis microscopic panel [#/area] - Urine sediment by Automated count | 0.775 |  |
| 3000208 | Alpha tocopherol [Moles/volume] in Serum or Plasma | 0.772 |  |
| 3021322 | Cryoglobulin [Presence] in Serum | 0.772 | 1165 |
| 40759788 | Carotene.alpha [Mass/volume] in Serum | 0.768 |  |
| 3041404 | Ferritin [Mass/volume] in Body fluid | 0.768 |  |
| 3030662 | Karyotype [Identifier] in Amniotic fluid Nominal | 0.767 | 1161 |
| 40757350 | Thrombin time.factor substitution immediately after 1:4 addition of normal plasma in Platelet poor plasma by Coagulation assay | 0.767 |  |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 0.766 |  |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.766 |  |
| 3037839 | Renal function 2000 panel - Serum or Plasma | 0.765 |  |
| 3044028 | Biotin [Moles/volume] in Serum or Plasma | 0.764 |  |
| 3036941 | Urinalysis complete panel - Urine | 0.763 |  |
| 3030834 | Platelet genotype [Identifier] in Blood | 0.761 |  |
| 40766287 | aPTT actual/normal in Platelet poor plasma by Coagulation assay | 0.760 |  |
| 42870499 | Thrombin time actual/Normal | 0.760 | 3000 |
| 36031200 | Hepatocellular carcinoma risk panel - Serum or Plasma | 0.760 |  |
| 1761544 | S100 calcium binding protein B [Mass/volume] in Body fluid | 0.760 |  |
| 3049710 | Thrombin time.factor substitution immediately after addition of bovine thrombin in Platelet poor plasma by Coagulation assay | 0.759 |  |
| 36660394 | Lipid and glucose panel - Serum or Plasma | 0.758 |  |
| 36304575 | Protein and creatinine panel - Urine | 0.755 |  |
| 3003985 | Beta hydroxybutyrate [Moles/volume] in Serum or Plasma | 0.755 | 1670 |
| 3024359 | Beta aminoisobutyrate [Moles/volume] in Serum or Plasma | 0.753 |  |
| 1175300 | Liver cancer antibodies and AFP panel - Serum or Plasma by Immunoassay | 0.752 |  |
| 3042044 | Coproporphyrin [Mass/mass] in Stool | 0.751 |  |
| 40759632 | Porphyrins [Mass/mass] in Stool | 0.750 |  |
| 3051707 | Protein [Mass/volume] in Stool | 0.747 |  |
| 40762025 | Protoporphyrin [Mass/mass] in Stool | 0.747 |  |
| 40757377 | Protein and Glucose panel [Mass/volume] - Body fluid | 0.746 |  |
| 3022295 | Zinc [Mass/mass] in Stool | 0.744 |  |
| 3021479 | IgA [Mass/volume] in Body fluid | 0.742 |  |
| 3015916 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma | 0.742 |  |
| 1617093 | Nuclear antibody panel - Serum | 0.740 |  |
| 3044927 | Protein electrophoresis panel - Urine | 0.739 |  |
| 3035320 | C reactive protein [Mass/volume] in Body fluid | 0.732 |  |
| 3050932 | Hepatitis A virus Ab panel - Serum | 0.731 |  |
| 40758523 | Protein and Glucose panel - Cerebral spinal fluid | 0.728 |  |
| 42529056 | Liver cytosol IgG Ab [Presence] in Serum by Line blot | 0.725 |  |
| 3007308 | Glucose [Presence] in 24 hour Urine | 0.723 |  |
| 36659717 | Hepatitis A virus IgM panel - Serum | 0.722 |  |
| 42529189 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma by Immunoassay | 0.720 |  |
| 3029645 | Glucose screen gestational panel - Urine and Serum or Plasma | 0.716 |  |
| 3015075 | Pear IgG Ab [Units/volume] in Serum | 0.716 |  |
| 645854 | Glucose [Measurement] in Urine | 0.716 |  |
| 40759838 | Liver cytosol Ab [Presence] in Serum by Immunoblot | 0.716 |  |
| 3009261 | Glucose [Presence] in Urine by Test strip | 0.715 | 309 |
| 3003169 | Glucose tolerance 2 hours gestational panel - Urine and Serum or Plasma | 0.712 |  |
| 36303714 | Connective tissue autoimmune Ab panel - Serum | 0.712 |  |
| 1091453 | Primary biliary cholangitis comprehensive Ab panel - Serum or Plasma | 0.711 |  |
| 3030180 | Alpha-1-Fetoprotein [Multiple of the median] adjusted for multiple gestations in Serum or Plasma | 0.711 |  |
| 1002070 | Acarboxyprothrombin [Units/volume] in Serum or Plasma | 0.709 |  |
| 3024370 | Alpha-1-Fetoprotein [Multiple of the median] in Serum or Plasma | 0.706 | 1109 |
| 3016670 | Alpha-1-Fetoprotein [Multiple of the median] adjusted in Serum or Plasma | 0.701 | 609 |
| 3032989 | Alpha-1-Fetoprotein multiple of the median cutoff [Multiple of the median] in Serum or Plasma | 0.698 |  |
| 21493222 | Voiding time by Uroflowmetry | 0.598 |  |
| 21493218 | Flow time by Uroflowmetry | 0.587 |  |
| 3012900 | Fluid intake urinary bladder irrigation 1 hour | 0.541 |  |
| 21493224 | Time to max urine flow by Uroflowmetry | 0.533 |  |
| 3010804 | Urinary bladder Length by US | 0.529 |  |
| 3035875 | Fluid intake urinary bladder irrigation Estimated | 0.526 |  |
| 3008117 | Fluid intake urinary bladder irrigation 10 hour | 0.525 |  |
| 3037423 | Fluid intake urinary bladder irrigation 24 hour | 0.522 |  |
| 3004775 | Volume in Urine collected for unspecified duration | 0.519 | 793 |
| 3036289 | Fluid intake urinary bladder irrigation 12 hour | 0.519 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 948 | -calpro | mg/l | 86% | name+unit+values | 368 | 0 | [0.1, 0.31, 0.88, 2.86, 7.72, 16.73, 36.68, 74.3, 206.67] |  |  |  | Calprotectin [Mass/volume] in Body fluid |
| 949 | -calpro | ug/g | 9% | name+unit | 37 | 0 |  |  |  |  | Calprotectin [Mass/mass] in Stool |
| 950 | -calpro |  | 5% | name | 23 | 21.74 |  |  |  |  | Calprotectin [Mass/mass] in Stool |
| 951 | 4184sk-padihot |  | 100% | name | 107 | 100 |  |  |  |  | Microscopic observation [Identifier] in Skin by Histology |
| 952 | b-karyot |  | 100% | name | 686 | 100 |  |  | Blood |  | Karyotype [Identifier] in Blood |
| 953 | b-malarv |  | 100% | name | 127 | 100 |  |  | Blood |  | Plasmodium sp identified in Blood by Light microscopy |
| 954 | b-nakkrea |  | 100% | name | 424 | 100 |  |  | Blood |  |  |
| 955 | b-pakk-e |  | 100% | name | 249 | 100 |  |  | Blood |  |  |
| 956 | b-vara |  | 100% | name | 254 | 100 |  |  | Blood |  |  |
| 957 | b-varaspr |  | 100% | name | 331 | 99.7 |  |  | Blood |  |  |
| 958 | b.parapert |  | 100% | name | 619 | 100 |  |  |  |  | Bordetella parapertussis [Presence] in Blood |
| 959 | du-parprot |  | 100% | name | 369 | 100 |  |  | 24-hour urine |  | Paraprotein [Presence] in 24 hour Urine |
| 960 | f-calpro | ug/g | 89% | name+unit+values | 144892 | 0.48 | [13.78, 23.28, 35.55, 53.95, 82, 128.24, 215.34, 397.8, 911.98] | F -Kalprotektiini; F -Calprotectin | Feces |  | Calprotectin [Mass/mass] in Stool |
| 961 | f-calpro |  | 11% | name+values | 17874 | 100 | [23.61, 33.46, 47.58, 74.67, 119.83, 157.1, 290.01, 478.43, 993.36] | F -Kalprotektiini; F -Calprotectin | Feces |  | Calprotectin [Mass/mass] in Stool |
| 962 | f-calpro2 | ug/g | 80% | name+unit+values | 395 | 0 | [28.88, 40.5, 54.65, 82.87, 126.54, 220.92, 330.47, 583.74, 1304.77] |  | Feces |  | Calprotectin [Mass/mass] in Stool |
| 963 | f-calpro2 |  | 20% | name | 97 | 100 |  |  | Feces |  | Calprotectin [Mass/mass] in Stool |
| 964 | fs-bkarot | nmol/l | 5% | name+unit | 18 | 0 |  | fS-Beetakaroteeni | Fasting serum |  | Beta carotene [Moles/volume] in Serum or Plasma |
| 965 | fs-bkarot | umol/l | 95% | name+unit+values | 318 | 0 | [0.25, 0.45, 0.6, 0.75, 0.87, 1.06, 1.29, 1.57, 2.19] | fS-Beetakaroteeni | Fasting serum |  | Beta carotene [Moles/volume] in Serum or Plasma |
| 966 | fs-sappih | umol/l | 89% | name+unit+values | 5416 | 0.04 | [1.58, 2, 2.4, 3, 3.74, 4.45, 5.67, 7.59, 13.61] |  | Fasting serum |  | Bile acids.total [Moles/volume] in Serum or Plasma |
| 967 | fs-sappih |  | 11% | name+values | 686 | 100 | [2, 2.48, 3.02, 3.91, 4.81, 5.88, 6.86, 8.3, 12.54] |  | Fasting serum |  | Bile acids.total [Moles/volume] in Serum or Plasma |
| 968 | fs-sappihapot | umol/l | 87% | name+unit+values | 198 | 0 | [1.41, 1.79, 2.06, 2.5, 3.2, 3.97, 4.98, 6.66, 11.59] |  | Fasting serum |  | Bile acids.total [Moles/volume] in Serum or Plasma |
| 969 | fs-sappihapot |  | 13% | name | 30 | 100 |  |  | Fasting serum |  | Bile acids.total [Moles/volume] in Serum or Plasma |
| 970 | li-kardab | titre | 3% | name+unit | 7 | 14.29 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  | Cardiolipin Ab [Titer] in Cerebral spinal fluid |
| 971 | li-kardab |  | 97% | name | 204 | 100 |  | Li-Kardiolipiini, vasta-aineet (VDRL) | Cerebrospinal fluid |  | Cardiolipin Ab [Titer] in Cerebral spinal fluid |
| 972 | li-varlikv |  | 100% | name | 111 | 100 |  |  | Cerebrospinal fluid |  |  |
| 973 | p-kardabg | gpl | 10% | name+unit+values | 1101 | 6.99 | [1, 1, 1.61, 2, 2, 3, 5.05, 7.62, 12.35] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma |
| 974 | p-kardabg | u/ml | 42% | name+unit+values | 4443 | 0 | [1, 1, 1.08, 2, 2, 2.64, 3.48, 5.89, 13.12] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma |
| 975 | p-kardabg |  | 47% | name+values | 4985 | 95.25 | [1, 1.14, 2, 2, 3.36, 5, 5.97, 9.03, 19.8] | P -Kardiolipiini, IgG-vasta-aineet | Plasma |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma |
| 976 | p-kardabm | mpl | 60% | name+unit+values | 1111 | 5.04 | [1, 2, 2, 2.88, 3, 4.6, 7.59, 12.86, 20.09] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma |
| 977 | p-kardabm | u/ml | 1% | name+unit | 11 | 0 |  | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma |
| 978 | p-kardabm |  | 39% | name+values | 724 | 89.09 | [1, 1, 1.45, 2, 2, 3, 4, 6, 15] | P -Kardiolipiini, IgM-vasta-aineet | Plasma |  | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma |
| 979 | p-pakk-si |  | 100% | name | 260 | 100 |  |  | Plasma |  |  |
| 980 | p-varainr |  | 100% | name | 8332 | 99.99 |  |  | Plasma |  |  |
| 981 | p-varmtr | s | 93% | name+unit+values | 1488 | 0 | [17.02, 18, 18.87, 19, 19.98, 20, 21, 21.93, 23] |  | Plasma |  | Coagulation time [Time] in Platelet poor plasma |
| 982 | p-varmtr |  | 7% | name | 111 | 100 |  |  | Plasma |  | Coagulation time [Time] in Platelet poor plasma |
| 983 | p-varmtt | % | 93% | name+unit+values | 1494 | 0 | [41.91, 74.69, 84.09, 92.24, 98.54, 104.26, 111.28, 119.13, 131.18] |  | Plasma |  | Thrombin time [Ratio] in Platelet poor plasma |
| 984 | p-varmtt |  | 7% | name | 105 | 100 |  |  | Plasma |  | Thrombin time [Ratio] in Platelet poor plasma |
| 985 | s-afmakro | u/l | 84% | name+unit+values | 2842 | 0 | [3.98, 5.01, 6.23, 7.94, 10.06, 14.01, 21.13, 33.22, 62.9] |  | Serum |  | Macroalkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 986 | s-afmakro |  | 16% | name+values | 523 | 59.85 | [4, 5, 6, 7.5, 10, 15.29, 22.33, 30.86, 49.44] |  | Serum |  | Macroalkaline phosphatase [Enzymatic activity/volume] in Serum or Plasma |
| 987 | s-afmaks1 | u/l | 94% | name+unit+values | 199 | 0 | [25.36, 33.2, 41.05, 48.96, 56.78, 64.23, 71.62, 84.6, 112.64] |  | Serum |  | Alkaline phosphatase.liver isoenzyme [Enzymatic activity/volume] in Serum or Plasma |
| 988 | s-afmaks1 |  | 6% | name | 13 | 0 |  |  | Serum |  | Alkaline phosphatase.liver isoenzyme [Enzymatic activity/volume] in Serum or Plasma |
| 989 | s-afmaks2 | u/l | 97% | name+unit+values | 205 | 0 | [3.2, 4.72, 5.48, 6.4, 7, 8.07, 11.08, 16.5, 34.56] |  | Serum |  | Alkaline phosphatase isoenzyme [Enzymatic activity/volume] in Serum or Plasma |
| 990 | s-afmaks2 |  | 3% | name | 7 | 14.29 |  |  | Serum |  | Alkaline phosphatase isoenzyme [Enzymatic activity/volume] in Serum or Plasma |
| 991 | s-afmaksa | % | 3% | name+unit+values | 94 | 0 | [39.9, 51.85, 57.9, 64.48, 69.3, 73.65, 78.41, 84.08, 89.4] |  | Serum |  | Alkaline phosphatase.liver/Alkaline phosphatase.total [Enzymatic activity Ratio] in Serum or Plasma |
| 992 | s-afmaksa | u/l | 84% | name+unit+values | 2958 | 0 | [25.04, 37.52, 47.03, 56.68, 67.64, 79.81, 95.37, 125.6, 201.78] |  | Serum |  | Alkaline phosphatase.liver isoenzyme [Enzymatic activity/volume] in Serum or Plasma |
| 993 | s-afmaksa |  | 14% | name+values | 489 | 65.03 | [32.9, 45.51, 57.63, 71.86, 79.96, 85.36, 96.57, 123.73, 246.45] |  | Serum |  | Alkaline phosphatase.liver isoenzyme [Enzymatic activity/volume] in Serum or Plasma |
| 994 | s-caspähe | u/ml | 89% | name+unit+values | 895 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.04, 0.13, 1.71] |  | Serum |  | Cashew nut IgE Ab [Units/volume] in Serum |
| 995 | s-caspähe |  | 11% | name | 106 | 80.19 |  |  | Serum |  | Cashew nut IgE Ab [Units/volume] in Serum |
| 996 | s-haspähe | u/ml | 81% | name+unit | 683 | 0.15 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  | Hazelnut (f17) IgE Ab [Units/volume] in Serum |
| 997 | s-haspähe |  | 19% | name | 162 | 73.46 |  | S -Hasselpähkinä (f17), IgE-vasta-aineet | Serum |  | Hazelnut (f17) IgE Ab [Units/volume] in Serum |
| 998 | s-hasspäe | u/ml | 87% | name+unit+values | 476 | 1.05 | [0, 0.01, 0.03, 0.29, 1.1, 3.4, 6.79, 13.75, 30.06] |  | Serum |  | Hazelnut IgE Ab [Units/volume] in Serum |
| 999 | s-hasspäe |  | 13% | name | 72 | 54.17 |  |  | Serum |  | Hazelnut IgE Ab [Units/volume] in Serum |
| 1000 | s-karba | umol/l | 76% | name+unit+values | 3476 | 0.06 | [18.5, 22.32, 25.2, 27.69, 29.91, 32.56, 35.34, 38.81, 44.25] | S -Karbamatsepiini | Serum |  | Carbamazepine [Moles/volume] in Serum or Plasma |
| 1001 | s-karba |  | 24% | name+values | 1101 | 59.49 | [18.42, 22.33, 25.59, 27.84, 29.91, 31.7, 34.15, 37.84, 41.83] | S -Karbamatsepiini | Serum |  | Carbamazepine [Moles/volume] in Serum or Plasma |
| 1002 | s-karbae | umol/l | 81% | name+unit | 88 | 0 |  | S -Karbamatsepiiniepoksidi | Serum |  | Carbamazepine 10,11-epoxide [Moles/volume] in Serum or Plasma |
| 1003 | s-karbae |  | 19% | name | 21 | 100 |  | S -Karbamatsepiiniepoksidi | Serum |  | Carbamazepine 10,11-epoxide [Moles/volume] in Serum or Plasma |
| 1004 | s-kardab | titre | 10% | name+unit+values | 1640 | 0 | [0, 1, 1.58, 2, 2.38, 4, 8.71, 19.26, 62.28] | S -Kardiolipiini, vasta-aineet | Serum |  | Cardiolipin Ab [Titer] in Serum or Plasma |
| 1005 | s-kardab |  | 90% | name | 14614 | 99.49 |  | S -Kardiolipiini, vasta-aineet | Serum |  | Cardiolipin Ab [Titer] in Serum or Plasma |
| 1006 | s-kardabg | gpl | 12% | name+unit+values | 222 | 29.28 | [6, 7, 8, 9, 11, 14.4, 18.14, 24.7, 40.7] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma |
| 1007 | s-kardabg | u/ml | 4% | name+unit+values | 83 | 0 | [1, 1, 2, 2, 2.25, 3, 4, 7.3, 23] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma |
| 1008 | s-kardabg |  | 84% | name+values | 1591 | 94.97 | [1, 2, 2, 4.55, 7, 8, 9, 11, 27] | S -Kardiolipiini, IgG-vasta-aineet | Serum |  | Cardiolipin IgG Ab [Units/volume] in Serum or Plasma |
| 1009 | s-kardabm | mpl | 18% | name+unit+values | 359 | 18.11 | [10, 11.36, 12, 13.78, 15, 17.69, 23.08, 30.86, 52.98] | S -Kardiolipiini, IgM-vasta-aineet | Serum |  | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma |
| 1010 | s-kardabm |  | 82% | name | 1672 | 96.29 |  | S -Kardiolipiini, IgM-vasta-aineet | Serum |  | Cardiolipin IgM Ab [Units/volume] in Serum or Plasma |
| 1011 | s-karni | umol/l | 95% | name+unit+values | 328 | 0 | [17.78, 24.87, 29.09, 33.28, 36.28, 39.87, 43.86, 49.4, 55.76] | S -Karnitiini | Serum |  | Carnitine [Moles/volume] in Serum or Plasma |
| 1012 | s-karni |  | 5% | name | 16 | 100 |  | S -Karnitiini | Serum |  | Carnitine [Moles/volume] in Serum or Plasma |
| 1013 | s-karni-v | umol/l | 98% | name+unit+values | 342 | 0 | [11.86, 16.35, 19.2, 22.24, 25.07, 27.94, 30.82, 35, 41.74] | S -Karnitiini, vapaa | Serum | Free or unconjugated | Carnitine.free [Moles/volume] in Serum or Plasma |
| 1014 | s-karni-v |  | 2% | name | 7 | 85.71 |  | S -Karnitiini, vapaa | Serum | Free or unconjugated | Carnitine.free [Moles/volume] in Serum or Plasma |
| 1015 | s-koopähe | u/ml | 56% | name+unit+values | 83 | 0 | [0.02, 0.02, 0.03, 0.04, 0.06, 0.11, 0.2, 0.31, 0.85] | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  | Coconut (f36) IgE Ab [Units/volume] in Serum |
| 1016 | s-koopähe |  | 44% | name | 65 | 78.46 |  | S -Kookospähkinä (f36), IgE-vasta-aineet | Serum |  | Coconut (f36) IgE Ab [Units/volume] in Serum |
| 1017 | s-leppäe | u/ml | 54% | name+unit+values | 196 | 0.51 | [0, 0.01, 0.01, 0.02, 0.06, 0.22, 0.9, 2.7, 6.69] | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  | Alder (t2) IgE Ab [Units/volume] in Serum |
| 1018 | s-leppäe |  | 46% | name | 167 | 86.23 |  | S -Lepän siitepöly (t2), IgE-vasta-aineet | Serum |  | Alder (t2) IgE Ab [Units/volume] in Serum |
| 1019 | s-maapähe | u/ml | 44% | name+unit+values | 1974 | 0.81 | [0.01, 0.02, 0.05, 0.1, 0.19, 0.37, 0.71, 1.55, 5.76] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  | Peanut (f13) IgE Ab [Units/volume] in Serum |
| 1020 | s-maapähe |  | 56% | name+values | 2541 | 94.14 | [0.04, 0.11, 0.15, 0.24, 0.38, 0.57, 1.12, 1.88, 3.68] | S -Maapähkinä (f13), IgE-vasta-aineet | Serum |  | Peanut (f13) IgE Ab [Units/volume] in Serum |
| 1021 | s-maksa |  | 100% | name | 108 | 100 |  |  | Serum |  | Liver function panel - Serum or Plasma |
| 1022 | s-maksa-1 | u/l | 95% | name+unit+values | 115 | 0 | [31.15, 42.45, 51.29, 60.72, 65.7, 69.64, 79.3, 87.8, 100.66] |  | Serum |  | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 1023 | s-maksa-1 |  | 5% | name | 6 | 16.67 |  |  | Serum |  | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 1024 | s-maksa-2 | u/l | 90% | name+unit+values | 110 | 0 | [3.95, 4.95, 5.9, 6.88, 7.37, 8.14, 9.54, 13.38, 18.4] |  | Serum |  | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 1025 | s-maksa-2 |  | 10% | name | 12 | 8.33 |  |  | Serum |  | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 1026 | s-maksa1 | u/l | 94% | name+unit+values | 134 | 0 | [36.7, 43.4, 53.05, 58.95, 67.89, 79.32, 89.06, 98.11, 147.2] |  | Serum |  | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 1027 | s-maksa1 |  | 6% | name | 9 | 66.67 |  |  | Serum |  | Alanine aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 1028 | s-maksa2 | u/l | 92% | name+unit+values | 132 | 0 | [4, 5, 6, 7.35, 9, 10.85, 14.35, 21.6, 43.05] |  | Serum |  | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 1029 | s-maksa2 |  | 8% | name | 11 | 81.82 |  |  | Serum |  | Aspartate aminotransferase [Enzymatic activity/volume] in Serum or Plasma |
| 1030 | s-maksaab |  | 100% | name | 1108 | 100 |  |  | Serum |  | Liver autoantibody panel - Serum |
| 1031 | s-maksap |  | 100% | name | 147 | 100 |  |  | Serum |  | Liver function panel - Serum or Plasma |
| 1032 | s-makspak |  | 100% | name | 778 | 100 |  |  | Serum |  | Liver function panel - Serum or Plasma |
| 1033 | s-ohkarba | umol/l | 84% | name+unit+values | 4080 | 0.02 | [27.1, 35.97, 41.95, 47.99, 54.61, 61.42, 68.9, 80.34, 98.86] | S -Hydroksikarbatsepiini (10-) | Serum |  | Oxcarbazepine 10-hydroxy metabolite [Moles/volume] in Serum or Plasma |
| 1034 | s-ohkarba |  | 16% | name+values | 797 | 53.58 | [25.02, 33.78, 40.6, 47.36, 53.64, 59.31, 68.63, 83.49, 103.17] | S -Hydroksikarbatsepiini (10-) | Serum |  | Oxcarbazepine 10-hydroxy metabolite [Moles/volume] in Serum or Plasma |
| 1035 | s-okarba | umol/l | 49% | name+unit+values | 163 | 10.43 | [0.4, 0.4, 0.8, 0.8, 0.8, 1, 1.2, 2, 2.28] | S -Okskarbatsepiini | Serum |  | Oxcarbazepine [Moles/volume] in Serum or Plasma |
| 1036 | s-okarba |  | 51% | name | 168 | 92.26 |  | S -Okskarbatsepiini | Serum |  | Oxcarbazepine [Moles/volume] in Serum or Plasma |
| 1037 | s-ovarab | titre | 8% | name+unit | 22 | 9.09 |  | S -Munasarja, vasta-aineet | Serum |  | Ovary Ab [Titer] in Serum |
| 1038 | s-ovarab |  | 92% | name | 250 | 99.2 |  | S -Munasarja, vasta-aineet | Serum |  | Ovary Ab [Titer] in Serum |
| 1039 | s-pakast5 |  | 100% | name | 880 | 100 |  |  | Serum |  |  |
| 1040 | s-pakast7 |  | 100% | name | 106 | 100 |  |  | Serum |  |  |
| 1041 | s-pakaste |  | 100% | name | 345 | 100 |  |  | Serum |  |  |
| 1042 | s-pakkas |  | 100% | name | 1423 | 100 |  |  | Serum |  |  |
| 1043 | s-pakkase |  | 100% | name | 262 | 100 |  |  | Serum |  |  |
| 1044 | s-pakkask |  | 100% | name | 1061 | 100 |  |  | Serum |  |  |
| 1045 | s-pakkasl |  | 100% | name | 919 | 100 |  |  | Serum |  |  |
| 1046 | s-pakkasn |  | 100% | name | 563 | 100 |  |  | Serum |  |  |
| 1047 | s-pakkasv |  | 100% | name | 357 | 100 |  |  | Serum |  |  |
| 1048 | s-papp-a | mu/l | 61% | name+unit+values | 533 | 0 | [227.4, 357.69, 452.41, 562.07, 709.24, 895.85, 1154.59, 1409.1, 2163.11] |  | Serum |  | Pregnancy associated plasma protein A [Units/volume] in Serum |
| 1049 | s-papp-a |  | 39% | name+values | 338 | 2.37 | [167.71, 318.34, 452.63, 572.23, 702.5, 894.09, 1122.57, 1356.65, 1789.1] |  | Serum |  | Pregnancy associated plasma protein A [Units/volume] in Serum |
| 1050 | s-pappa | form | 0% | name+unit+values | 136 | 0 | [318.92, 443.67, 549.54, 657.05, 734.74, 894.71, 1259.38, 1647.76, 2113.41] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy associated plasma protein A [Units/volume] in Serum |
| 1051 | s-pappa | mu/l | 99% | name+unit+values | 41976 | 0 | [274.01, 424.82, 564.51, 708.65, 861.85, 1046.47, 1281.47, 1624.11, 2236.83] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy associated plasma protein A [Units/volume] in Serum |
| 1052 | s-pappa |  | 1% | name+values | 357 | 100 | [254.51, 396.2, 527.37, 666.3, 821.3, 1003.01, 1225.19, 1551.35, 2139.86] | S -Plasmaproteiini A, raskauteen liittyvä | Serum |  | Pregnancy associated plasma protein A [Units/volume] in Serum |
| 1053 | s-pappmom | mom | 100% | name+unit+values | 461 | 0 | [0.48, 0.64, 0.76, 0.89, 1.03, 1.22, 1.42, 1.67, 2.13] |  | Serum |  | Pregnancy associated plasma protein A MoM [Ratio] in Serum |
| 1054 | s-parapäe | u/ml | 96% | name+unit+values | 829 | 0 | [0, 0, 0, 0, 0.01, 0.01, 0.02, 0.06, 0.35] |  | Serum |  | Brazil nut IgE Ab [Units/volume] in Serum |
| 1055 | s-parapäe |  | 4% | name | 34 | 61.76 |  |  | Serum |  | Brazil nut IgE Ab [Units/volume] in Serum |
| 1056 | s-paras | umol/l | 52% | name+unit+values | 2680 | 3.1 | [16.09, 27.95, 44.46, 65.68, 102.63, 158.13, 258.09, 473.45, 862.14] | S -Parasetamoli | Serum |  | Acetaminophen [Moles/volume] in Serum or Plasma |
| 1057 | s-paras |  | 48% | name | 2490 | 99.24 |  | S -Parasetamoli | Serum |  | Acetaminophen [Moles/volume] in Serum or Plasma |
| 1058 | s-paroab |  | 100% | name | 212 | 100 |  | S -Sikotautivirus, vasta-aineet | Serum |  | Mumps virus Ab [Presence] in Serum |
| 1059 | s-paroabg | au/ml | 25% | name+unit+values | 72 | 0 | [14.1, 32.2, 47.68, 60.86, 78.93, 100.49, 117, 176, 216] | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab [Units/volume] in Serum |
| 1060 | s-paroabg | titre | 16% | name+unit | 45 | 0 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab [Titer] in Serum |
| 1061 | s-paroabg |  | 60% | name | 172 | 91.86 |  | S -Sikotautivirus, IgG-vasta-aineet | Serum |  | Mumps virus IgG Ab [Units/volume] in Serum |
| 1062 | s-paroabm |  | 100% | name | 197 | 98.98 |  | S -Sikotautivirus, IgM-vasta-aineet | Serum |  | Mumps virus IgM Ab [Presence] in Serum |
| 1063 | s-parprot |  | 100% | name | 1578 | 100 |  |  | Serum |  | Paraprotein [Presence] in Serum |
| 1064 | s-parpäh | u/ml | 27% | name+unit | 67 | 0 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  | Brazil nut (f18) IgE Ab [Units/volume] in Serum |
| 1065 | s-parpäh |  | 73% | name | 184 | 96.2 |  | S -Parapähkinä (f18), IgE-vasta-aineet | Serum |  | Brazil nut (f18) IgE Ab [Units/volume] in Serum |
| 1066 | s-parvab |  | 100% | name | 3096 | 100 |  | S -Parvovirus, vasta-aineet | Serum |  | Parvovirus B19 Ab [Presence] in Serum |
| 1067 | s-parvabg | eiu | 2% | name+unit+values | 67 | 0 | [10, 35, 50, 61, 71.88, 80.25, 90, 90, 100] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Units/volume] in Serum |
| 1068 | s-parvabg | ie/ml | 0% | name+unit | 5 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Units/volume] in Serum |
| 1069 | s-parvabg | index | 8% | name+unit+values | 250 | 0 | [10.1, 15.96, 22.67, 26.36, 30.21, 33.04, 36.98, 39.69, 42.76] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Ratio] in Serum |
| 1070 | s-parvabg | iu/ml | 2% | name+unit | 57 | 0 |  | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Units/volume] in Serum |
| 1071 | s-parvabg | titre | 19% | name+unit+values | 558 | 0 | [200, 400, 800, 800, 800, 1555.56, 1600, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Titer] in Serum |
| 1072 | s-parvabg |  | 69% | name+values | 2056 | 91.73 | [4.91, 11.45, 38.67, 122.23, 400, 800, 800, 1600, 1600] | S -Parvovirus, IgG-vasta-aineet | Serum |  | Parvovirus B19 IgG Ab [Titer] in Serum |
| 1073 | s-parvabm |  | 100% | name | 2965 | 99.46 |  | S -Parvovirus, IgM-vasta-aineet | Serum |  | Parvovirus B19 IgM Ab [Presence] in Serum |
| 1074 | s-parvavi | % | 2% | name+unit | 13 | 0 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  | Parvovirus B19 IgG Ab Avidity [Ratio] in Serum |
| 1075 | s-parvavi |  | 98% | name | 600 | 95.33 |  | S -Parvovirus, vasta-aineet, aviditeetti | Serum |  | Parvovirus B19 IgG Ab Avidity [Ratio] in Serum |
| 1076 | s-pekpähe | u/ml | 29% | name+unit | 31 | 0 |  |  | Serum |  | Pecan nut IgE Ab [Units/volume] in Serum |
| 1077 | s-pekpähe |  | 71% | name | 77 | 96.1 |  |  | Serum |  | Pecan nut IgE Ab [Units/volume] in Serum |
| 1078 | s-sakspäe | u/ml | 90% | name+unit+values | 883 | 0 | [0, 0, 0, 0.01, 0.01, 0.03, 0.07, 0.21, 1.55] |  | Serum |  | Walnut IgE Ab [Units/volume] in Serum |
| 1079 | s-sakspäe |  | 10% | name | 95 | 74.74 |  |  | Serum |  | Walnut IgE Ab [Units/volume] in Serum |
| 1080 | s-sappih | umol/l | 82% | name+unit+values | 9172 | 0.36 | [2, 2.87, 3.49, 4.45, 5.83, 7.59, 10.65, 16.77, 32.84] | S -Sappihapot | Serum |  | Bile acids.total [Moles/volume] in Serum or Plasma |
| 1081 | s-sappih |  | 18% | name+values | 1955 | 50.33 | [2, 3, 3, 4, 4.4, 5.33, 7.05, 9.69, 18.19] | S -Sappihapot | Serum |  | Bile acids.total [Moles/volume] in Serum or Plasma |
| 1082 | s-valpr | % | 0% | name+unit | 33 | 0 |  | S -Valproaatti | Serum |  | Valproate [Moles/volume] in Serum or Plasma |
| 1083 | s-valpr | umol/l | 96% | name+unit+values | 35853 | 0.05 | [220.39, 285.23, 332.16, 372.59, 408.92, 446.56, 486.81, 533.22, 600.78] | S -Valproaatti | Serum |  | Valproate [Moles/volume] in Serum or Plasma |
| 1084 | s-valpr |  | 4% | name+values | 1583 | 100 | [195.88, 257.11, 300.41, 340.81, 382.77, 422.91, 465.76, 516.34, 588.53] | S -Valproaatti | Serum |  | Valproate [Moles/volume] in Serum or Plasma |
| 1085 | s-valpr-v | umol/l | 79% | name+unit+values | 818 | 0 | [25.49, 29.94, 35.24, 39.88, 44.93, 50.41, 57.45, 67.85, 86.45] | S -Valproaatti, vapaa | Serum | Free or unconjugated | Valproate.free [Moles/volume] in Serum or Plasma |
| 1086 | s-valpr-v |  | 21% | name | 221 | 80.54 |  | S -Valproaatti, vapaa | Serum | Free or unconjugated | Valproate.free [Moles/volume] in Serum or Plasma |
| 1087 | s-valpro | umol/l | 97% | name+unit | 171 | 0 |  |  | Serum |  | Valproate [Moles/volume] in Serum or Plasma |
| 1088 | s-valpro |  | 3% | name | 5 | 100 |  |  | Serum |  | Valproate [Moles/volume] in Serum or Plasma |
| 1089 | s-vara |  | 100% | name | 340 | 100 |  |  | Serum |  |  |
| 1090 | s-varah |  | 100% | name | 253 | 100 |  |  | Serum |  |  |
| 1091 | sappihapot | umol/l | 92% | name+unit | 161 | 0 |  |  |  |  | Bile acids.total [Moles/volume] in Serum or Plasma |
| 1092 | sappihapot |  | 8% | name | 14 | 100 |  |  |  |  | Bile acids.total [Moles/volume] in Serum or Plasma |
| 1093 | sk-padihot |  | 100% | name | 24730 | 100 |  | Sk-Ihottumanäytteen histologinen tutkimus | Skin |  | Microscopic observation [Identifier] in Skin by Histology |
| 1094 | tupakka | u/24h | 85% | name+unit+values | 599 | 0 | [0, 0, 0, 0, 0, 0, 0, 0, 8.55] |  |  |  | Cotinine [Mass/time] in 24 hour Urine |
| 1095 | tupakka |  | 15% | name | 104 | 100 |  |  |  |  | Cotinine [Presence] in Urine |
| 1096 | u-gluprot |  | 100% | name | 2097 | 100 |  |  | Urine |  | Glucose and Protein panel - Urine |
| 1097 | u-partik |  | 100% | name | 14759 | 100 |  |  | Urine |  | Urinalysis sediment microscopy panel - Urine |
| 1098 | u-partikk |  | 100% | name | 5466 | 100 |  |  | Urine |  | Urinalysis sediment microscopy panel - Urine |
| 1099 | u-rakkoai | h | 99% | name+unit+values | 373 | 0 | [2.84, 4, 4, 4.03, 5, 6, 6.66, 7.87, 8.33] |  | Urine |  | Bladder dwell time [Time] |
| 1100 | u-rakkoai |  | 1% | name | 5 | 100 |  |  | Urine |  | Bladder dwell time [Time] |
| 1101 | u-sakka |  | 100% | name | 2736 | 100 |  |  | Urine |  | Urinalysis sediment microscopy panel - Urine |
| 1102 | u-valvott |  | 100% | name | 1125 | 100 |  |  | Urine |  |  |
| 1103 | u-varabak |  | 100% | name | 206 | 100 |  |  | Urine |  |  |

