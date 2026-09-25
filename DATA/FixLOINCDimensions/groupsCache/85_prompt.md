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
Here is group 85.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3005136 | Cladosporium herbarum IgE Ab [Units/volume] in Serum | 1.000 | 718 |
| 3020710 | Acetone [Moles/volume] in Serum or Plasma | 1.000 | 1019 |
| 3022859 | Acetone [Presence] in Serum or Plasma | 1.000 |  |
| 3026470 | Cobalt [Mass/volume] in Blood | 1.000 |  |
| 3026493 | Urate [Moles/volume] in Serum or Plasma | 1.000 | 142 |
| 3042123 | Cladosporium herbarum IgG Ab [Presence] in Serum | 0.965 |  |
| 40759848 | Cladosporium cladosporioides IgE Ab [Units/volume] in Serum | 0.964 |  |
| 3042514 | Cladosporium sp IgE Ab [Units/volume] in Serum | 0.963 |  |
| 3045281 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Urine by NAA with probe detection | 0.962 |  |
| 3006832 | Cladosporium herbarum IgG Ab [Units/volume] in Serum | 0.960 |  |
| 3045260 | Cladosporium sp IgE Ab [Presence] in Serum | 0.955 |  |
| 3019084 | Cladosporium sphaerospermum IgE Ab [Units/volume] in Serum | 0.955 | 1809 |
| 647567 | Cladosporium herbarum IgE Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.952 |  |
| 3038057 | Cladosporium herbarum IgM Ab [Units/volume] in Serum | 0.945 |  |
| 3009466 | Valproate [Moles/volume] in Serum or Plasma | 0.944 | 408 |
| 3008909 | Norovirus RNA [Presence] in Stool by NAA with probe detection | 0.942 |  |
| 3023355 | Cladosporium herbarum IgG4 Ab [Units/volume] in Serum | 0.942 |  |
| 3025848 | Cobalt [Moles/volume] in Blood | 0.932 |  |
| 3966673 | Human coronavirus OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.928 |  |
| 3965970 | Human coronavirus 229E RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.927 |  |
| 3036736 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Specimen by NAA with probe detection | 0.927 |  |
| 3041642 | Human coronavirus 229E RNA [Presence] in Specimen by NAA with probe detection | 0.927 |  |
| 3019531 | Acetone [Mass/volume] in Serum or Plasma | 0.926 |  |
| 36304464 | Human coronavirus OC43 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.924 |  |
| 3003568 | Cladosporium cladosporioides IgG Ab [Units/volume] in Serum | 0.923 |  |
| 21491446 | Chlamydia trachomatis+Neisseria gonorrhoeae rRNA [Presence] in Urine by NAA with probe detection | 0.923 | 3000 |
| 40764010 | Cladosporium herbarum IgE Ab/IgE total in Serum | 0.922 |  |
| 3045789 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Genital specimen by NAA with probe detection | 0.922 |  |
| 40758036 | Norovirus genogroup II RNA [Presence] in Stool by NAA with probe detection | 0.921 |  |
| 36304601 | Human coronavirus 229E RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.921 |  |
| 3037556 | Urate [Mass/volume] in Serum or Plasma | 0.921 |  |
| 3965395 | Human coronavirus NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.920 |  |
| 3031825 | Cladosporium sp IgG Ab [Presence] in Serum | 0.918 |  |
| 3038546 | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with probe detection | 0.918 |  |
| 3964787 | Human coronavirus HKU1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.917 |  |
| 3042090 | Cladosporium cladosporioides IgG Ab [Presence] in Serum | 0.917 |  |
| 40758035 | Norovirus genogroup I RNA [Presence] in Stool by NAA with probe detection | 0.916 |  |
| 36031212 | Human papilloma virus 31 DNA [Presence] in Cervix by NAA with probe detection | 0.914 |  |
| 36304330 | Human coronavirus 229E RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.913 |  |
| 37019702 | Norovirus genogroup I+II RNA [Presence] in Stool by NAA with probe detection | 0.912 |  |
| 36304548 | Human coronavirus NL63 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.912 |  |
| 646724 | Human coronavirus 229E RNA [Presence] in Specimen by NAA with non-probe detection | 0.911 |  |
| 36660491 | Human coronavirus 229E RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.911 |  |
| 1092421 | Human coronavirus OC43 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.910 |  |
| 3965635 | Cladosporium herbarum IgE Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.910 |  |
| 40763125 | Cobalt [Mass/volume] in Red Blood Cells | 0.910 |  |
| 36305656 | Human coronavirus NL63 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.909 |  |
| 36304961 | Human coronavirus OC43 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.908 |  |
| 36305676 | Human coronavirus HKU1 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.908 |  |
| 36660364 | Human coronavirus OC43 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.908 |  |
| 21493479 | Norovirus genogroup I+II RNA [Presence] in Stool by NAA with non-probe detection | 0.907 |  |
| 46236100 | Human papilloma virus 16 DNA [Presence] in Cervix by NAA with probe detection | 0.906 |  |
| 3040359 | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with probe detection | 0.906 |  |
| 37020776 | Human coronavirus 229E+NL63 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.904 |  |
| 645449 | Human coronavirus OC43 RNA [Presence] in Specimen by NAA with non-probe detection | 0.904 |  |
| 36032296 | Human papilloma virus 52 DNA [Presence] in Cervix by NAA with probe detection | 0.903 |  |
| 36660329 | Human coronavirus NL63 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.902 |  |
| 1091709 | Human coronavirus NL63 RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.902 |  |
| 3026389 | Candida sp identified in Specimen by Organism specific culture | 0.901 |  |
| 40765160 | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with probe detection | 0.901 |  |
| 3037286 | Acetone [Presence] in Serum or Plasma by Screen method | 0.900 | 1801 |
| 36031312 | Human papilloma virus 45 DNA [Presence] in Cervix by NAA with probe detection | 0.899 |  |
| 36305349 | Human coronavirus HKU1 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.899 |  |
| 36032213 | Human papilloma virus 51 DNA [Presence] in Cervix by NAA with probe detection | 0.898 |  |
| 646956 | Acetone [Measurement] in Serum or Plasma | 0.898 |  |
| 3035526 | Acetoacetate [Moles/volume] in Serum or Plasma | 0.897 |  |
| 3031021 | Cobalt [Mass/volume] in Body fluid | 0.897 |  |
| 3028447 | Cobalt [Mass/volume] in Serum or Plasma | 0.896 |  |
| 36659667 | Human coronavirus HKU1 RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.895 |  |
| 40759867 | Norovirus RNA [Presence] in Specimen by NAA with probe detection | 0.894 |  |
| 1091933 | Human coronavirus OC43 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.894 |  |
| 3045367 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Cervix by NAA with probe detection | 0.893 | 2001 |
| 1091444 | Human coronavirus 229E RNA [Presence] in Specimen | 0.892 |  |
| 3016201 | Valproate [Mass/volume] in Serum or Plasma | 0.892 |  |
| 36032027 | Human papilloma virus 56+59+66 DNA [Presence] in Cervix by NAA with probe detection | 0.891 |  |
| 645895 | Human coronavirus HKU1 RNA [Presence] in Specimen by NAA with non-probe detection | 0.890 |  |
| 46236101 | Human papilloma virus 18 DNA [Presence] in Cervix by NAA with probe detection | 0.890 |  |
| 3033714 | Cladosporium herbarum IgG Ab [Mass/volume] in Serum | 0.890 |  |
| 1259531 | Human papilloma virus 31+33+52+58 DNA [Presence] in Cervix by NAA with probe detection | 0.889 |  |
| 3024950 | Chlamydia trachomatis DNA [Presence] in Urine by NAA with probe detection | 0.887 | 726 |
| 3964590 | Cladosporium herbarum IgG4 Ab [Presence] in Serum by Radioallergosorbent test (RAST) | 0.887 |  |
| 36031448 | Human papilloma virus 33+58 DNA [Presence] in Cervix by NAA with probe detection | 0.887 |  |
| 3028566 | Urate [Moles/volume] in Specimen | 0.886 |  |
| 646769 | Human coronavirus NL63 RNA [Presence] in Specimen by NAA with non-probe detection | 0.886 |  |
| 36031556 | Human papilloma virus 35+39+68 DNA [Presence] in Cervix by NAA with probe detection | 0.885 |  |
| 1091921 | Human coronavirus OC43 RNA [Presence] in Bronchoalveolar lavage by NAA with probe detection | 0.885 |  |
| 1616915 | Norovirus genogroup II RNA [Presence] in Specimen by NAA with probe detection | 0.885 |  |
| 37019802 | Human coronavirus HKU1+OC43 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.884 |  |
| 21493148 | Human coronavirus OC43 RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.884 |  |
| 21493147 | Human coronavirus 229E RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.883 |  |
| 1091342 | Human coronavirus HKU1 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.882 |  |
| 1091866 | Human coronavirus NL63 RNA [Presence] in Nasopharynx by NAA with probe detection | 0.882 |  |
| 37020262 | Human coronavirus 229E+HKU1+NL63+OC43 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.881 |  |
| 1091840 | Human coronavirus NL63 RNA [Presence] in Bronchoalveolar lavage by NAA with probe detection | 0.879 |  |
| 646011 | Cladosporium herbarum IgG Ab [Measurement] in Serum | 0.879 |  |
| 1616677 | Norovirus genogroup I RNA [Presence] in Specimen by NAA with probe detection | 0.879 |  |
| 3024085 | Cobalt [Mass/volume] in Urine | 0.876 |  |
| 3001791 | Acetoacetate [Presence] in Serum or Plasma | 0.875 |  |
| 3022915 | Valproate Free [Moles/volume] in Serum or Plasma | 0.875 |  |
| 3027874 | Urate [Moles/volume] in Urine | 0.874 | 1405 |
| 36305615 | Human coronavirus NL63 RNA [Presence] in Aspirate by NAA with probe detection | 0.871 |  |
| 647936 | Urate [Measurement] in Serum or Plasma | 0.870 |  |
| 46235167 | Norovirus genogroup I and II RNA [Identifier] in Stool by NAA with probe detection | 0.869 |  |
| 36305386 | Human coronavirus HKU1 RNA [Presence] in Aspirate by NAA with probe detection | 0.867 |  |
| 21493330 | Human coronavirus HKU1 RNA [Presence] in Nasopharynx by NAA with non-probe detection | 0.867 |  |
| 1176001 | Norovirus RNA [Presence] in Vomitus by NAA with probe detection | 0.867 |  |
| 21492666 | Norovirus genogroup I+II orf1-orf2 junction region [Presence] in Stool by NAA with probe detection | 0.867 |  |
| 46234794 | Acetone [Moles/volume] in Blood | 0.866 |  |
| 21492850 | Chlamydia trachomatis+Neisseria gonorrhoeae rRNA [Presence] in Vaginal fluid by NAA with probe detection | 0.865 | 3000 |
| 3044280 | Acetone [Presence] in Blood | 0.865 |  |
| 40763482 | Norovirus RNA [Presence] in Isolate by NAA with probe detection | 0.864 |  |
| 3013867 | Bacteria identified in Specimen by Aerobe culture | 0.862 | 276 |
| 3004527 | Acetone [Presence] in Specimen | 0.861 |  |
| 3011298 | Bacteria identified in Specimen by Anaerobe culture | 0.859 | 333 |
| 3008520 | Urate [Moles/volume] in Body fluid | 0.858 |  |
| 3002322 | Acetone [Moles/volume] in Specimen | 0.857 |  |
| 3020115 | Chlamydia trachomatis DNA [Presence] in Urethra by NAA with probe detection | 0.857 |  |
| 3019205 | Cobalt [Mass/volume] in Specimen | 0.856 |  |
| 3035800 | Chlamydia trachomatis and Neisseria gonorrhoeae DNA [Identifier] in Specimen by NAA with probe detection | 0.856 | 327 |
| 3022033 | Acetone [Presence] in Body fluid | 0.856 |  |
| 3029311 | Acetone [Moles/volume] in Body fluid | 0.855 |  |
| 3035132 | Ketones [Presence] in Serum or Plasma | 0.853 | 1276 |
| 3044125 | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Specimen by Probe with signal amplification | 0.853 |  |
| 21492849 | Chlamydia trachomatis+Neisseria gonorrhoeae rRNA [Presence] in Cervix by NAA with probe detection | 0.852 | 3000 |
| 3030560 | Chlamydia sp DNA [Presence] in Urine by NAA with probe detection | 0.852 |  |
| 42870622 | 2-Methylacetoacetate [Moles/volume] in Serum or Plasma | 0.851 |  |
| 3029348 | Methyl ethyl ketone [Moles/volume] in Serum or Plasma | 0.851 |  |
| 3019518 | Acetone [Presence] in Urine | 0.850 | 473 |
| 1091339 | Norovirus genogroup I+II RNA [Presence] in Specimen | 0.850 |  |
| 1175713 | Norovirus genogroup I and II RNA [Identifier] in Specimen by NAA with probe detection | 0.849 |  |
| 3024421 | Chlamydia trachomatis DNA [Presence] in Genital specimen by NAA with probe detection | 0.849 |  |
| 3006093 | Chlamydia trachomatis DNA [Presence] in Specimen by NAA with probe detection | 0.846 | 180 |
| 3041890 | Norovirus RNA [Presence] in Specimen by Probe | 0.845 |  |
| 3020779 | Urea [Moles/volume] in Serum or Plasma | 0.845 |  |
| 3029886 | Cobalt [Moles/volume] in Red Blood Cells | 0.844 |  |
| 3021311 | Cobalt [Moles/volume] in Serum or Plasma | 0.844 |  |
| 3002619 | Bacteria identified in Specimen by Culture | 0.843 | 39 |
| 3052265 | Chlamydia trachomatis+Neisseria gonorrhoeae rRNA [Presence] in Specimen from Donor by NAA with probe detection | 0.842 |  |
| 3024447 | Bacteria identified in Specimen by Anaerobe+Aerobe culture | 0.841 | 1062 |
| 1175308 | Norovirus genogroup II RNA [Presence] in Vomitus by NAA with probe detection | 0.840 |  |
| 40761050 | Cobalt [Mass/volume] in Cerebral spinal fluid | 0.838 |  |
| 3022620 | Valproate [Mass/volume] in Serum or Plasma --trough | 0.836 |  |
| 3046547 | Bacteria # 3 identified in Specimen by Anaerobe culture | 0.835 |  |
| 3012713 | Urate [Moles/volume] in 24 hour Urine | 0.833 |  |
| 3044387 | Bacteria # 2 identified in Specimen by Anaerobe culture | 0.833 |  |
| 3043007 | Bacteria # 6 identified in Specimen by Anaerobe culture | 0.831 |  |
| 3020200 | Chlamydia trachomatis DNA [Presence] in Cervix by NAA with probe detection | 0.830 | 751 |
| 3043307 | Bacteria # 4 identified in Specimen by Anaerobe culture | 0.829 |  |
| 3046504 | Bacteria # 5 identified in Specimen by Anaerobe culture | 0.829 |  |
| 3048895 | Bacteria # 8 identified in Specimen by Aerobe culture | 0.829 |  |
| 3042301 | Urate [Moles/volume] in Synovial fluid | 0.828 |  |
| 21491327 | Allopurinol [Moles/volume] in Serum or Plasma | 0.828 |  |
| 3043573 | Bacteria # 7 identified in Specimen by Anaerobe culture | 0.827 |  |
| 3012167 | Candida sp identified in Stool by Organism specific culture | 0.825 |  |
| 3021600 | Valproate Free [Mass/volume] in Serum or Plasma | 0.822 |  |
| 3049818 | Bacteria # 7 identified in Specimen by Aerobe culture | 0.818 |  |
| 3053009 | Bacteria # 3 identified in Specimen by Aerobe culture | 0.818 |  |
| 43533702 | Valproate [Mass/volume] in Serum or Plasma --peak | 0.810 |  |
| 3000494 | Fungus identified in Specimen by Culture | 0.810 | 328 |
| 3037330 | Chlamydia sp DNA [Presence] in Cervix by NAA with probe detection | 0.808 |  |
| 3043867 | Bacteria # 8 identified in Specimen by Culture | 0.808 |  |
| 3026551 | Bacteria identified in Unknown substance by Aerobe culture | 0.807 |  |
| 3047178 | Yeast [Presence] in Specimen by Wet preparation | 0.805 | 874 |
| 3046136 | Bacteria # 7 identified in Specimen by Culture | 0.804 |  |
| 37020691 | Bacteria identified in Upper respiratory specimen by Aerobe culture | 0.804 |  |
| 40758651 | Acetazolamide [Moles/volume] in Serum or Plasma | 0.801 |  |
| 3041732 | Fungus identified in Genital specimen by Culture | 0.795 |  |
| 3050209 | Cryptococcus sp identified in Specimen by Organism specific culture | 0.793 |  |
| 3025093 | Yeast [Presence] in Genital specimen by Wet preparation | 0.789 |  |
| 3025633 | Candida sp identified in Saliva (oral fluid) by Organism specific culture | 0.788 |  |
| 36305715 | Candida sp identified in Isolate | 0.787 |  |
| 3020485 | Acetaminophen [Moles/volume] in Serum or Plasma | 0.785 | 402 |
| 3046121 | Yeast.hyphae [Presence] in Specimen by Wet preparation | 0.784 |  |
| 3019779 | Phenytoin [Moles/volume] in Serum or Plasma | 0.784 | 356 |
| 3022515 | Vigabatrin [Moles/volume] in Serum or Plasma | 0.783 |  |
| 1761571 | Yeast and Candida sp identification panel - Specimen by Organism specific culture | 0.781 |  |
| 3042263 | Yeast identified in Genital specimen by Organism specific culture | 0.777 |  |
| 1617523 | Candida sp identified in Isolate by Sequencing | 0.760 |  |
| 3011034 | Cladosporium herbarum Ab [Units/volume] in Serum | 0.759 |  |
| 3009648 | Yeast [Presence] in Cervix by Wet preparation | 0.758 |  |
| 3001496 | Yeast [Presence] in Vaginal fluid by Wet preparation | 0.750 |  |
| 3020030 | Yeast [Presence] in Urethra by Wet preparation | 0.745 |  |
| 3046994 | Cladosporium herbarum Ab [Presence] in Serum by Immune diffusion (ID) | 0.745 |  |
| 40758444 | Yeast [Presence] in Specimen by KOH preparation | 0.745 |  |
| 40758437 | Yeast.pseudohyphae [Presence] in Specimen by KOH preparation | 0.743 |  |
| 42868608 | Yeast.hyphae [Presence] in Specimen by KOH preparation | 0.739 |  |
| 3002256 | Pathology report gross observation | 0.689 |  |
| 3007597 | Pathology report gross observation Narrative | 0.660 | 248 |
| 3964745 | Pathology report microscopic observation in Specimen | 0.617 |  |
| 36305536 | Placenta examination findings Document | 0.615 |  |
| 44817246 | Macroscopic observation [Interpretation] in Specimen Narrative | 0.607 |  |
| 3002855 | Fetal Placenta Grade US (narrative) | 0.588 |  |
| 36304944 | Microscopic observation [Identifier] in Placenta by Gram stain | 0.585 |  |
| 1617280 | Sex [Type] in Products of Conception by Molecular genetics method | 0.584 |  |
| 46237006 | Karyotype [Identifier] in Products of Conception Nominal | 0.575 |  |
| 42529483 | Pathology report intraoperative observation in Specimen Document | 0.572 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1241 | -aerobivi |  | 100% | name | 314 | 100 |  |  |  |  | Bacteria aerobic identified in Unspecified specimen by Culture |
| 1242 | -anaerobi |  | 100% | name | 320 | 100 |  |  |  |  | Bacteria anaerobic identified in Unspecified specimen by Culture |
| 1243 | -omactgc |  | 100% | name | 591 | 100 |  |  |  |  | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Unspecified specimen by NAA |
| 1244 | annosvoim |  | 100% | name | 182 | 65.93 |  |  |  |  |  |
| 1245 | b-koboltti | ug/l | 100% | name+unit+values | 157 | 0 | [0.5, 0.72, 0.96, 1.18, 1.68, 2.2, 3.97, 6.08, 10.46] |  | Blood |  | Cobalt [Mass/volume] in Blood |
| 1246 | cand-odl. |  | 100% | name | 542 | 89.67 |  |  |  |  | Candida sp identified in Unspecified specimen by Culture |
| 1247 | cand.nativ |  | 100% | name | 286 | 100 |  |  |  |  | Candida sp [Presence] in Unspecified specimen by Wet mount |
| 1248 | cladosp.he | mm | 1% | name+unit | 11 | 0 |  |  |  |  | Cladosporium herbarum Ab [Length] in Skin by Skin test |
| 1249 | cladosp.he | u/ml | 9% | name+unit+values | 69 | 0 | [0, 0.01, 0.01, 0.04, 0.13, 0.41, 0.5, 0.87, 4.4] |  |  |  | Cladosporium herbarum IgE Ab [Units/volume] in Serum |
| 1250 | cladosp.he |  | 89% | name | 680 | 93.82 |  |  |  |  | Cladosporium herbarum IgE Ab [Presence] in Serum |
| 1251 | corona229e |  | 100% | name | 619 | 100 |  |  |  |  | Coronavirus 229E RNA [Presence] in Respiratory specimen by NAA |
| 1252 | coronahku1 |  | 100% | name | 619 | 100 |  |  |  |  | Coronavirus HKU1 RNA [Presence] in Respiratory specimen by NAA |
| 1253 | coronanl63 |  | 100% | name | 619 | 100 |  |  |  |  | Coronavirus NL63 RNA [Presence] in Respiratory specimen by NAA |
| 1254 | coronaoc43 |  | 100% | name | 619 | 100 |  |  |  |  | Coronavirus OC43 RNA [Presence] in Respiratory specimen by NAA |
| 1255 | f-norogi |  | 100% | name | 261 | 100 |  |  | Feces |  | Norovirus G1 RNA [Presence] in Stool by NAA |
| 1256 | f-norogii |  | 100% | name | 261 | 100 |  |  | Feces |  | Norovirus G2 RNA [Presence] in Stool by NAA |
| 1257 | f-projekti |  | 100% | name | 469 | 100 |  |  | Feces |  |  |
| 1258 | hpvpapctgc |  | 100% | name | 116 | 100 |  |  |  |  | Human papillomavirus DNA+Chlamydia trachomatis DNA+Neisseria gonorrhoeae DNA [Presence] in Cervix by NAA |
| 1259 | hpvrefctgc |  | 100% | name | 135 | 100 |  |  |  |  | Human papillomavirus DNA [Presence] in Cervix by NAA |
| 1260 | norogi |  | 100% | name | 139 | 100 |  |  |  |  | Norovirus G1 RNA [Presence] in Unspecified specimen by NAA |
| 1261 | norogii |  | 100% | name | 139 | 100 |  |  |  |  | Norovirus G2 RNA [Presence] in Unspecified specimen by NAA |
| 1262 | p-asetoni | mmol/l | 36% | name+unit+values | 171 | 0 | [0, 0, 0, 0, 0, 0, 0.99, 1.7, 3.4] |  | Plasma |  | Acetone [Moles/volume] in Serum or Plasma |
| 1263 | p-asetoni |  | 64% | name | 305 | 100 |  |  | Plasma |  | Acetone [Presence] in Serum or Plasma |
| 1264 | p-uraatti | umol/l | 100% | name+unit+values | 6902 | 0 | [234.14, 271.61, 301.37, 327.94, 355.71, 383.49, 416.66, 458.38, 518.94] |  | Plasma |  | Urate [Moles/volume] in Serum or Plasma |
| 1265 | p-uraatti |  | 0% | name | 32 | 87.5 |  |  | Plasma |  | Urate [Moles/volume] in Serum or Plasma |
| 1266 | projekti1 |  | 100% | name | 160 | 100 |  |  |  |  |  |
| 1267 | s-asetoni | mmol/l | 9% | name+unit | 42 | 0 |  | S -Asetoni | Serum |  | Acetone [Moles/volume] in Serum or Plasma |
| 1268 | s-asetoni |  | 91% | name | 414 | 100 |  | S -Asetoni | Serum |  | Acetone [Presence] in Serum or Plasma |
| 1269 | s-uraatti | umol/l | 94% | name+unit+values | 621 | 0 | [231.75, 257.74, 279.08, 298.35, 317.34, 343.64, 366.52, 401.97, 449.54] |  | Serum |  | Urate [Moles/volume] in Serum or Plasma |
| 1270 | s-uraatti |  | 6% | name | 38 | 100 |  |  | Serum |  | Urate [Moles/volume] in Serum or Plasma |
| 1271 | s-valproaatti | umol/l | 96% | name+unit+values | 431 | 0 | [243.85, 308.03, 356.19, 396.72, 425.61, 467.25, 503.69, 550.21, 628.49] |  | Serum |  | Valproic acid [Moles/volume] in Serum or Plasma |
| 1272 | s-valproaatti |  | 4% | name | 16 | 87.5 |  |  | Serum |  | Valproic acid [Moles/volume] in Serum or Plasma |
| 1273 | ts-abortti |  | 100% | name | 315 | 100 |  | Ts-Aborttikudoksen dissektiotutkimus | Tissue |  | Gross description in Products of conception by Macroscopy |
| 1274 | u-omactgc |  | 100% | name | 480 | 100 |  |  | Urine |  | Chlamydia trachomatis+Neisseria gonorrhoeae DNA [Presence] in Urine by NAA |
| 1275 | uraatti | umol/l | 99% | name+unit+values | 3560 | 0 | [230.56, 267.35, 298.53, 325.87, 354.19, 383.04, 414.66, 454.9, 512.27] |  |  |  | Urate [Moles/volume] in Serum or Plasma |
| 1276 | uraatti |  | 1% | name | 19 | 100 |  |  |  |  | Urate [Moles/volume] in Serum or Plasma |

