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
Here is group 51.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 1259853 | Infliximab and Infliximab Ab Panel - Serum or Plasma | 1.000 |  |
| 3002823 | Mycoplasma pneumoniae IgG Ab [Units/volume] in Cerebral spinal fluid | 1.000 |  |
| 3004762 | Giardia lamblia Ag [Presence] in Stool | 1.000 |  |
| 3005411 | Squamous cell carcinoma Ag [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3008284 | Rotavirus Ag [Presence] in Stool | 1.000 |  |
| 3010959 | Adenovirus IgG Ab [Units/volume] in Serum | 1.000 |  |
| 3011363 | Streptococcus pneumoniae Ag [Presence] in Urine | 1.000 |  |
| 3015147 | Influenza virus A IgG Ab [Units/volume] in Serum | 1.000 |  |
| 3016413 | Influenza virus B IgG Ab [Units/volume] in Serum | 1.000 |  |
| 3018387 | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum | 1.000 |  |
| 3018940 | Influenza virus B Ab [Units/volume] in Serum | 1.000 |  |
| 3020393 | Adenovirus Ag [Presence] in Stool | 1.000 |  |
| 3021082 | Mycoplasma pneumoniae IgM Ab [Presence] in Serum | 1.000 |  |
| 3034468 | Parainfluenza virus 1 IgG Ab [Presence] in Serum | 1.000 |  |
| 3035162 | Adenovirus Ag [Presence] in Nasopharynx | 1.000 |  |
| 3035420 | Mycoplasma pneumoniae Ab [Presence] in Serum | 1.000 |  |
| 3035523 | Parainfluenza virus 1 IgG Ab [Units/volume] in Serum | 1.000 |  |
| 3040947 | Adenovirus IgG Ab [Presence] in Serum | 1.000 |  |
| 3042299 | inFLIXimab [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3042885 | Influenza virus A IgG Ab [Presence] in Serum | 1.000 |  |
| 3042988 | Influenza virus B Ab [Presence] in Serum | 1.000 |  |
| 3045344 | Influenza virus B IgG Ab [Presence] in Serum | 1.000 |  |
| 3046684 | Mycoplasma pneumoniae IgG Ab [Presence] in Serum | 1.000 |  |
| 3052592 | Norovirus Ag [Presence] in Stool | 1.000 |  |
| 3051042 | Giardia lamblia+Cryptosporidium parvum Ag [Presence] in Stool | 0.990 |  |
| 3001684 | Respiratory syncytial virus Ag [Presence] in Specimen | 0.987 |  |
| 3052347 | Giardia lamblia+Cryptosporidium sp Ag [Presence] in Stool | 0.980 |  |
| 3016955 | Mycoplasma pneumoniae IgM Ab [Units/volume] in Cerebral spinal fluid | 0.979 |  |
| 43055457 | inFLIXimab Ab [Mass/volume] in Serum or Plasma | 0.978 |  |
| 3000836 | Parainfluenza virus 1 IgM Ab [Presence] in Serum | 0.975 |  |
| 3035919 | Mycoplasma pneumoniae IgG+IgM Ab [Units/volume] in Serum | 0.971 |  |
| 3015828 | Influenza virus B Ab [Units/volume] in Cerebral spinal fluid | 0.971 |  |
| 3008417 | Mycoplasma pneumoniae IgM Ab [Units/volume] in Serum | 0.971 |  |
| 3010464 | Parainfluenza virus 1 Ag [Presence] in Specimen | 0.971 |  |
| 40763480 | Human metapneumovirus Ag [Presence] in Specimen | 0.970 |  |
| 3005880 | Parainfluenza virus 3 Ag [Presence] in Specimen | 0.970 |  |
| 3005293 | Parainfluenza virus 1 IgM Ab [Units/volume] in Serum | 0.969 |  |
| 3038516 | Parainfluenza virus 1 IgG Ab [Presence] in Serum by Immunoassay | 0.968 |  |
| 3046180 | Influenza virus B IgA Ab [Presence] in Serum | 0.967 |  |
| 3021578 | Parainfluenza virus 2 Ag [Presence] in Specimen | 0.965 |  |
| 3048901 | Influenza virus B IgG Ab [Mass/volume] in Cerebral spinal fluid | 0.965 |  |
| 3007625 | Streptococcus pneumoniae Ag [Presence] in Specimen | 0.965 |  |
| 36304214 | Influenza virus B IgG Ab [Presence] in Serum by Immunoassay | 0.964 |  |
| 3035929 | Mycoplasma pneumoniae Ab [Units/volume] in Cerebral spinal fluid | 0.964 |  |
| 3003221 | Pneumocystis jirovecii Ag [Presence] in Specimen | 0.963 |  |
| 3036242 | Adenovirus IgM Ab [Presence] in Serum | 0.963 |  |
| 3051600 | Influenza virus B IgG Ab [Units/volume] in Serum by Immunoassay | 0.963 |  |
| 3000251 | Influenza virus B Ag [Presence] in Throat | 0.962 |  |
| 3016636 | Influenza virus B IgM Ab [Units/volume] in Serum | 0.962 |  |
| 3002523 | Influenza virus A Ag [Presence] in Specimen | 0.962 |  |
| 3036072 | Legionella pneumophila 1 Ag [Presence] in Urine | 0.962 |  |
| 3041248 | Adenovirus IgG Ab [Units/volume] in Serum by Immunoassay | 0.962 |  |
| 3044141 | Influenza virus A Ag [Presence] in Nasopharynx | 0.962 |  |
| 3052509 | Influenza virus A IgG Ab [Units/volume] in Serum by Immunoassay | 0.961 |  |
| 36204256 | Influenza virus A IgG Ab [Presence] in Serum by Immunoassay | 0.961 |  |
| 3045831 | Influenza virus B Ag [Presence] in Nasopharynx | 0.961 |  |
| 3010672 | Adenovirus IgM Ab [Units/volume] in Serum | 0.961 |  |
| 3031286 | Influenza virus B Ab [Presence] in Serum by Immunoassay | 0.959 |  |
| 3003740 | Influenza virus B Ag [Presence] in Specimen | 0.959 |  |
| 3042770 | Influenza virus B IgM Ab [Presence] in Serum | 0.959 |  |
| 3003551 | Influenza virus A Ag [Presence] in Throat | 0.958 |  |
| 3024891 | Influenza virus A+B Ag [Presence] in Specimen | 0.957 | 1991 |
| 36305253 | inFLIXimab [Mass/volume] in Serum or Plasma by Immunoassay | 0.956 |  |
| 3040912 | Adenovirus IgG Ab [Presence] in Serum by Immunoassay | 0.956 |  |
| 3024072 | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum by Immunoassay | 0.955 | 1563 |
| 3048553 | Influenza virus A IgG Ab [Mass/volume] in Cerebral spinal fluid | 0.954 |  |
| 3003479 | Legionella pneumophila Ag [Presence] in Urine | 0.953 |  |
| 3003330 | Adenovirus Ag [Presence] in Specimen | 0.953 |  |
| 3019430 | Parainfluenza virus 3 IgG Ab [Presence] in Serum | 0.952 |  |
| 3003306 | Rotavirus Ag [Presence] in Stool by Agglutination | 0.952 |  |
| 3043248 | Influenza virus A IgM Ab [Presence] in Serum | 0.951 |  |
| 3010521 | Mycoplasma pneumoniae IgM Ab [Presence] in Serum by Immunoassay | 0.951 |  |
| 3008907 | Influenza virus A IgM Ab [Units/volume] in Serum | 0.951 |  |
| 3045494 | Influenza virus B Ab [Units/volume] in Specimen | 0.950 |  |
| 3965803 | Influenza virus A+B RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.950 |  |
| 3002438 | Parainfluenza virus 2 IgG Ab [Presence] in Serum | 0.950 |  |
| 3045068 | Mycoplasma pneumoniae IgG Ab [Presence] in Serum by Immunoassay | 0.949 |  |
| 3016357 | Mycoplasma pneumoniae IgA Ab [Presence] in Serum | 0.949 |  |
| 3014742 | Influenza virus A Ab [Units/volume] in Cerebral spinal fluid | 0.948 |  |
| 3019407 | Mycoplasma pneumoniae IgA Ab [Units/volume] in Serum | 0.947 |  |
| 3043038 | Influenza virus B Ag [Presence] in Bronchial specimen | 0.947 |  |
| 3014008 | Giardia sp Ag [Presence] in Stool | 0.947 |  |
| 3043239 | Influenza virus A IgA Ab [Presence] in Serum | 0.947 |  |
| 40765199 | Influenza virus A+B RNA [Presence] in Specimen by NAA with probe detection | 0.946 |  |
| 3007522 | Mycoplasma pneumoniae Ab [Units/volume] in Serum | 0.945 |  |
| 3023510 | Pneumocystis jirovecii Ag [Presence] in Bronchial specimen | 0.944 |  |
| 3021514 | Adenovirus Ag [Presence] in Stool by Immunoassay | 0.944 |  |
| 3035217 | Parainfluenza virus 2 IgG Ab [Units/volume] in Serum | 0.944 |  |
| 3006264 | Giardia lamblia Ag [Presence] in Specimen | 0.943 |  |
| 3053332 | Influenza virus B IgA Ab [Mass/volume] in Cerebral spinal fluid | 0.942 |  |
| 3025861 | Parainfluenza virus 1 Ab [Units/volume] in Serum | 0.942 |  |
| 3032138 | Parainfluenza virus 4 IgG Ab [Presence] in Serum | 0.942 |  |
| 3021573 | Parainfluenza virus 3 IgG Ab [Units/volume] in Serum | 0.941 |  |
| 3014762 | Squamous cell carcinoma Ag [Moles/volume] in Serum or Plasma | 0.941 |  |
| 3047318 | Adenovirus Ab [Presence] in Cerebral spinal fluid | 0.941 |  |
| 3051390 | Giardia lamblia+Cryptosporidium parvum Ag [Presence] in Stool by Immunoassay | 0.940 |  |
| 40761802 | Mycoplasma pneumoniae IgM Ab [Presence] in Serum by Immunofluorescence | 0.939 |  |
| 3013870 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma | 0.939 |  |
| 40761876 | Mycoplasma pneumoniae IgM Ab [Units/volume] in Cerebral spinal fluid by Immunoassay | 0.939 |  |
| 3009488 | Squamous cell carcinoma Ag [Units/volume] in Serum or Plasma | 0.938 |  |
| 43055230 | Influenza virus B IgA Ab [Units/volume] in Serum by Immunoassay | 0.937 |  |
| 3042911 | Influenza virus A Ab [Presence] in Cerebral spinal fluid | 0.937 |  |
| 40758297 | Mycoplasma sp Ab [Presence] in Cerebral spinal fluid | 0.937 |  |
| 3045609 | Influenza virus A+B Ag [Presence] in Bronchial specimen | 0.937 |  |
| 3051730 | Giardia lamblia+Cryptosporidium sp Ag [Presence] in Stool by Immunoassay | 0.936 |  |
| 3014352 | Rotavirus Ag [Presence] in Stool by Immunoassay | 0.936 | 1185 |
| 3049879 | Influenza virus B IgM Ab [Mass/volume] in Cerebral spinal fluid | 0.935 |  |
| 3049481 | Giardia lamblia+Cryptosporidium parvum Ag [Presence] in Stool by Immunofluorescence | 0.935 |  |
| 3007936 | Chlamydophila pneumoniae IgG Ab [Units/volume] in Cerebral spinal fluid | 0.935 |  |
| 36305893 | Parainfluenza virus 3 Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.934 |  |
| 3047276 | Influenza virus A Ag [Presence] in Bronchial specimen | 0.934 |  |
| 3028849 | Mycoplasma pneumoniae Ab [Titer] in Cerebral spinal fluid | 0.934 |  |
| 3027545 | Mycoplasma pneumoniae Ab [Presence] in Serum by Immunoassay | 0.934 |  |
| 3012107 | Adenovirus Ag [Presence] in Stool by Immunofluorescence | 0.933 |  |
| 3033391 | Mycoplasma pneumoniae IgG Ab [Titer] in Cerebral spinal fluid | 0.933 |  |
| 40757371 | Influenza virus Ag [Presence] in Specimen | 0.933 |  |
| 1091605 | Influenza virus A+B RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.933 |  |
| 3021309 | Pneumocystis jirovecii Ag [Presence] in Sputum | 0.933 |  |
| 646703 | Parainfluenza virus 1 IgG Ab [Measurement] in Serum | 0.932 |  |
| 36304216 | Parainfluenza virus 1 Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.932 |  |
| 3037677 | Mycoplasma pneumoniae IgM Ab [Titer] in Cerebral spinal fluid | 0.932 |  |
| 3020426 | Respiratory syncytial virus Ag [Presence] in Specimen by Immunoassay | 0.932 | 881 |
| 3024605 | Mycoplasma pneumoniae IgM Ab [Units/volume] in Serum by Immunoassay | 0.932 | 1556 |
| 3008140 | Giardia lamblia Ag [Presence] in Stool by Immunoassay | 0.932 | 819 |
| 649481 | Mycoplasma pneumoniae IgM Ab [Measurement] in Cerebral spinal fluid | 0.932 |  |
| 3019247 | Parainfluenza virus 1 Ag [Presence] in Specimen by Immunofluorescence | 0.931 | 1906 |
| 42529122 | Norovirus Ag [Presence] in Stool by Rapid immunoassay | 0.931 |  |
| 3011115 | Influenza virus A+B Ab [Units/volume] in Serum | 0.931 |  |
| 36304486 | inFLIXimab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.931 |  |
| 3053225 | Giardia lamblia+Cryptosporidium sp Ag [Presence] in Stool by Immunofluorescence | 0.930 |  |
| 21491012 | Adenovirus Ag [Presence] in Stool by Rapid immunoassay | 0.930 |  |
| 3052846 | Influenza virus B IgM Ab [Units/volume] in Serum by Immunoassay | 0.930 |  |
| 3043538 | Influenza virus A+B Ab [Presence] in Serum | 0.930 |  |
| 36304243 | Parainfluenza virus 2 Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.929 |  |
| 36204260 | Influenza virus B IgM Ab [Presence] in Serum by Immunoassay | 0.929 |  |
| 3009662 | Adenovirus Ab [Units/volume] in Serum | 0.929 |  |
| 1259627 | Norovirus Ag [Presence] in Specimen | 0.929 |  |
| 3027774 | Influenza virus A Ab [Units/volume] in Serum | 0.928 |  |
| 3016669 | Influenza virus A Ab [Presence] in Serum | 0.928 |  |
| 3040191 | Adenovirus IgM Ab [Units/volume] in Serum by Immunoassay | 0.928 |  |
| 3047583 | Parainfluenza virus 1+2+3 Ab [Presence] in Serum | 0.928 |  |
| 3029458 | Influenza virus A+B Ag [Presence] in Nasopharynx | 0.928 |  |
| 3044430 | Adenovirus Ab [Presence] in Serum | 0.928 |  |
| 3005001 | Parainfluenza virus 2 IgM Ab [Presence] in Serum | 0.928 |  |
| 3033152 | Legionella pneumophila 1 Ag [Presence] in Urine by Immunoassay | 0.927 | 1169 |
| 648118 | Squamous cell carcinoma Ag [Measurement] in Serum or Plasma | 0.927 |  |
| 3022052 | Chlamydophila pneumoniae IgM Ab [Units/volume] in Cerebral spinal fluid | 0.927 |  |
| 43054917 | Rotavirus Ag [Presence] in Stool by Rapid immunoassay | 0.927 |  |
| 3046861 | Legionella sp Ag [Presence] in Urine | 0.926 |  |
| 3005444 | Respiratory syncytial virus Ag [Presence] in Specimen by Immunofluorescence | 0.926 | 1674 |
| 3039859 | Parainfluenza virus 2 IgG Ab [Presence] in Serum by Immunoassay | 0.926 |  |
| 37020635 | Influenza virus A RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.925 |  |
| 647751 | Mycoplasma pneumoniae IgG Ab [Measurement] in Cerebral spinal fluid | 0.925 |  |
| 3000425 | Parainfluenza virus Ag [Presence] in Specimen | 0.925 |  |
| 36303582 | Influenza virus B Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.925 |  |
| 43055231 | Influenza virus A IgA Ab [Units/volume] in Serum by Immunoassay | 0.924 |  |
| 3022193 | Influenza virus A+B Ag [Presence] in Throat | 0.924 |  |
| 3035716 | Adenovirus IgG Ab [Titer] in Serum | 0.924 |  |
| 3044357 | Adenovirus Ag [Presence] in Nasopharynx by Immunofluorescence | 0.924 |  |
| 3026121 | Parainfluenza virus 2 Ag [Presence] in Specimen by Immunofluorescence | 0.923 |  |
| 3027146 | Parainfluenza virus 1+2+3 Ag [Presence] in Specimen | 0.923 |  |
| 3009449 | Parainfluenza virus 3 Ag [Presence] in Specimen by Immunofluorescence | 0.923 |  |
| 648979 | Mycoplasma pneumoniae Ab [Measurement] in Cerebral spinal fluid | 0.923 |  |
| 3005443 | Influenza virus B IgG Ab [Titer] in Serum | 0.922 |  |
| 3011688 | Influenza virus B Ag [Presence] in Specimen by Immunoassay | 0.922 | 796 |
| 3050350 | Influenza virus A IgM Ab [Units/volume] in Serum by Immunoassay | 0.921 |  |
| 3010845 | Influenza virus B Ag [Presence] in Throat by Immunofluorescence | 0.921 |  |
| 37021263 | Human metapneumovirus Ag [Presence] in Upper respiratory specimen by Immunofluorescence | 0.921 |  |
| 3034339 | Parainfluenza virus 2 IgG Ab [Units/volume] in Serum by Immunoassay | 0.921 |  |
| 3004484 | Streptococcus pneumoniae Ag [Presence] in Sputum | 0.921 |  |
| 3022580 | Parainfluenza virus 3 IgM Ab [Units/volume] in Serum | 0.921 |  |
| 3043318 | Adenovirus Ag [Presence] in Nose | 0.921 |  |
| 647335 | Influenza virus B IgG Ab [Measurement] in Serum | 0.920 |  |
| 3005534 | Adenovirus Ag [Presence] in Throat | 0.920 |  |
| 37020098 | Human bocavirus Ag [Presence] in Upper respiratory specimen by Immunofluorescence | 0.920 |  |
| 36304868 | Influenza virus A Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.920 |  |
| 3010448 | Parainfluenza virus 2 IgM Ab [Units/volume] in Serum | 0.920 |  |
| 3000304 | Giardia lamblia Ag [Presence] in Stool by Immunofluorescence | 0.919 |  |
| 36204257 | Influenza virus A IgM Ab [Presence] in Serum by Immunoassay | 0.919 |  |
| 3020438 | Influenza virus B Ab [Titer] in Cerebral spinal fluid | 0.919 |  |
| 3024400 | Influenza virus A Ag [Presence] in Specimen by Immunofluorescence | 0.919 | 1296 |
| 3024940 | Influenza virus B Ag [Presence] in Throat by Immunoassay | 0.918 |  |
| 36304958 | Adenovirus Ag [Presence] in Nasopharynx by Immunoassay | 0.918 |  |
| 647586 | Influenza virus B Ab [Measurement] in Serum | 0.918 |  |
| 3040740 | Influenza virus B Ab [Units/volume] in Serum by Hemagglutination inhibition | 0.918 |  |
| 21492989 | Influenza virus B Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.918 |  |
| 37021271 | Adenovirus Ag [Presence] in Upper respiratory specimen by Immunoassay | 0.918 |  |
| 36203757 | Adenovirus IgM Ab [Presence] in Serum by Immunoassay | 0.918 |  |
| 37019857 | Pneumocystis jirovecii Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.918 |  |
| 3013704 | Influenza virus B Ag [Presence] in Specimen by Immunofluorescence | 0.918 |  |
| 3042756 | Influenza virus B Ag [Presence] in Bronchial specimen by Immunofluorescence | 0.917 |  |
| 3043286 | Influenza virus B Ab [Presence] in Body fluid | 0.917 |  |
| 36304759 | Respiratory syncytial virus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.917 |  |
| 21493666 | Mycophenolate acyl-glucuronide [Mass/volume] in Serum or Plasma | 0.917 |  |
| 3049833 | Influenza virus A IgA Ab [Mass/volume] in Cerebral spinal fluid | 0.916 |  |
| 3023613 | Influenza virus A IgG Ab [Titer] in Serum | 0.916 |  |
| 3051094 | Squamous cell carcinoma Ag [Mass/volume] in Body fluid | 0.916 |  |
| 3028459 | Influenza virus A Ag [Presence] in Specimen by Immunoassay | 0.916 | 728 |
| 3046808 | Parainfluenza virus 1 Ab [Titer] in Cerebral spinal fluid | 0.916 |  |
| 37020366 | Giardia lamblia Ag [Presence] in Stool by Rapid immunoassay | 0.916 |  |
| 3039848 | Human metapneumovirus Ag [Presence] in Specimen by Immunofluorescence | 0.915 |  |
| 3050404 | Influenza virus A IgM Ab [Mass/volume] in Cerebral spinal fluid | 0.915 |  |
| 42868411 | Adenovirus IgA Ab [Presence] in Serum by Immunoassay | 0.915 |  |
| 3046769 | Influenza virus B Ag [Presence] in Nasopharynx by Immunofluorescence | 0.915 |  |
| 1091210 | Legionella pneumophila 1 Ag [Presence] in Specimen | 0.915 |  |
| 3010064 | Influenza virus A+B Ag [Presence] in Specimen by Immunofluorescence | 0.914 |  |
| 36203321 | Influenza virus A RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.914 |  |
| 3044938 | Influenza virus A RNA [Presence] in Specimen by NAA with probe detection | 0.914 |  |
| 3043362 | Influenza virus B Ag [Presence] in Nasopharynx by Immunoassay | 0.914 | 1202 |
| 3023444 | Influenza virus A+B+C Ag [Presence] in Specimen | 0.914 |  |
| 3017558 | Chlamydophila pneumoniae IgM Ab [Presence] in Serum | 0.913 |  |
| 3045856 | Influenza virus B Ag [Presence] in Nose | 0.913 |  |
| 37021514 | Human metapneumovirus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.913 |  |
| 46236341 | Streptococcus pneumoniae Ag [Presence] in Urine by Rapid immunoassay | 0.913 |  |
| 21492988 | Influenza virus A Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.912 |  |
| 646225 | Influenza virus A IgG Ab [Measurement] in Serum | 0.912 |  |
| 3012646 | Influenza virus A+B Ag [Presence] in Specimen by Immunoassay | 0.912 | 1992 |
| 3013437 | Mycoplasma pneumoniae IgA Ab [Presence] in Serum by Immunoassay | 0.910 |  |
| 3043891 | Influenza virus A Ag [Presence] in Nose | 0.910 |  |
| 3002031 | Adenovirus 40+41 Ag [Presence] in Stool | 0.910 |  |
| 1091244 | Influenza virus A+B RNA [Presence] in Sputum by NAA with probe detection | 0.910 |  |
| 3042986 | Parainfluenza virus 2 Ab [Units/volume] in Cerebral spinal fluid | 0.909 |  |
| 645226 | Adenovirus IgG Ab [Measurement] in Serum | 0.909 |  |
| 37019896 | Adenovirus Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.909 |  |
| 3012621 | Mycoplasma pneumoniae IgG Ab [Titer] in Serum | 0.909 |  |
| 3028162 | Influenza virus A Ag [Presence] in Throat by Immunofluorescence | 0.909 |  |
| 1091443 | Influenza virus A RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.909 |  |
| 3049806 | Human bocavirus Ag [Presence] in Specimen by Immunofluorescence | 0.908 |  |
| 647204 | Mycoplasma pneumoniae IgG Ab [Measurement] in Serum | 0.908 |  |
| 3002623 | Legionella pneumophila Ag [Presence] in Urine by Latex agglutination | 0.907 |  |
| 3022602 | Parainfluenza virus 3 Ag [Presence] in Throat | 0.906 |  |
| 3009629 | Parainfluenza virus 1 Ag [Presence] in Throat | 0.906 |  |
| 37021256 | Human bocavirus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.906 |  |
| 3045936 | Influenza virus A Ag [Presence] in Nasopharynx by Immunofluorescence | 0.905 |  |
| 3002233 | Pneumocystis jirovecii Ag [Presence] in Serum | 0.905 |  |
| 36303237 | Adenovirus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.905 |  |
| 40758928 | Mycophenolate glucuronide [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.905 |  |
| 3046524 | Influenza virus A Ag [Presence] in Nasopharynx by Immunoassay | 0.905 | 1201 |
| 3026784 | Influenza virus A Ag [Presence] in Throat by Immunoassay | 0.905 |  |
| 36305662 | Influenza virus A RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.905 |  |
| 3026360 | Chlamydophila pneumoniae IgA Ab [Units/volume] in Cerebral spinal fluid | 0.905 |  |
| 1175556 | inFLIXimab Ab [Units/volume] in Serum by Immunoassay | 0.905 |  |
| 36305905 | Adenovirus Ag [Presence] in Lower respiratory specimen by Immunoassay | 0.904 |  |
| 647158 | Influenza virus A RNA [Presence] in Specimen by NAA with non-probe detection | 0.904 |  |
| 3004319 | Pneumocystis jirovecii Ag [Presence] in Urine | 0.904 |  |
| 3044569 | Mycoplasma pneumoniae Ab [Presence] in Body fluid | 0.904 |  |
| 3021320 | Legionella pneumophila Ag [Presence] in Urine by Immunoassay | 0.904 |  |
| 3006237 | Chlamydophila pneumoniae IgG Ab [Units/volume] in Serum | 0.903 |  |
| 3040380 | Adenovirus+Rotavirus Ag [Presence] in Stool | 0.901 |  |
| 3021508 | Respiratory syncytial virus Ag [Presence] in Throat | 0.901 |  |
| 3042198 | Norovirus genogroup I Ag [Presence] in Stool | 0.901 |  |
| 37020125 | Adenovirus Ag [Presence] in Lower respiratory specimen by Rapid immunoassay | 0.901 |  |
| 46236374 | Legionella pneumophila 1 Ag [Presence] in Urine by Rapid immunoassay | 0.901 |  |
| 3010633 | Mycoplasma sp Ab [Presence] in Serum | 0.901 |  |
| 3045607 | Chlamydophila pneumoniae IgG Ab [Presence] in Serum | 0.901 |  |
| 3016196 | Parainfluenza virus 2 Ag [Presence] in Throat | 0.901 |  |
| 3007979 | Giardia lamblia 65 Ag [Presence] in Stool | 0.900 |  |
| 40757375 | Influenza virus identified in Specimen | 0.900 |  |
| 3026395 | Mycoplasma pneumoniae Ab [Titer] in Serum | 0.900 |  |
| 3043593 | Parainfluenza virus 3 Ab [Presence] in Cerebral spinal fluid | 0.900 |  |
| 3003733 | Legionella pneumophila Ag [Presence] in Specimen | 0.899 |  |
| 3051190 | Parainfluenza virus 1 Ag [Presence] in Nasopharynx by Immunofluorescence | 0.899 |  |
| 40763479 | Parainfluenza virus 4 Ag [Presence] in Specimen | 0.897 |  |
| 3021705 | Mycoplasma pneumoniae Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.897 |  |
| 3011647 | Adenovirus Ag [Presence] in Specimen by Immunoassay | 0.896 |  |
| 3046856 | Respiratory syncytial virus Ag [Presence] in Nose | 0.896 |  |
| 647078 | Giardia lamblia+Cryptosporidium parvum Ag [Measurement] in Stool | 0.896 |  |
| 3036198 | Mycoplasma pneumoniae IgM Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.895 |  |
| 3009705 | Mycoplasma pneumoniae IgG Ab [Titer] in Cerebral spinal fluid by Immunofluorescence | 0.895 |  |
| 3004440 | Adenovirus Ag [Presence] in Urine | 0.895 |  |
| 46236093 | Parainfluenza virus 3 Ag [Presence] in Nasopharynx by Immunofluorescence | 0.895 |  |
| 40770410 | Parainfluenza virus 1 Ag [Presence] in Isolate by Immunofluorescence | 0.895 |  |
| 36304782 | Adenovirus Ag [Presence] in Cerebral spinal fluid by Immunoassay | 0.894 |  |
| 3009771 | Influenza virus A Ab [Titer] in Cerebral spinal fluid | 0.894 |  |
| 3020161 | Adenovirus Ag [Presence] in Conjunctival specimen | 0.894 |  |
| 3007023 | Streptococcus pneumoniae Ag [Presence] in Serum | 0.894 |  |
| 40771500 | Respiratory syncytial virus Ag [Presence] in Nasopharynx by Immunoassay | 0.893 |  |
| 648021 | Adenovirus Ag [Measurement] in Stool | 0.893 |  |
| 3001533 | Legionella pneumophila Ag [Presence] in Urine by Immunofluorescence | 0.893 |  |
| 646705 | Influenza virus A Ab [Measurement] in Cerebral spinal fluid | 0.892 |  |
| 46236092 | Parainfluenza virus 2 Ag [Presence] in Nasopharynx by Immunofluorescence | 0.892 |  |
| 3046648 | Adenovirus Ag [Presence] in Bronchial specimen by Immunofluorescence | 0.890 |  |
| 1259564 | Norovirus genogroup II Ag [Presence] in Stool | 0.890 |  |
| 3009873 | Streptococcus pneumoniae Ag [Presence] in Specimen by Latex agglutination | 0.889 |  |
| 43534059 | Respiratory syncytial virus Ag [Presence] in Nasopharynx by Rapid immunoassay | 0.888 |  |
| 40762313 | Squamous cell carcinoma Ag [Mass/volume] in Pleural fluid | 0.887 |  |
| 3023609 | Respiratory syncytial virus Ag [Presence] in Throat by Immunoassay | 0.887 |  |
| 46236091 | Respiratory syncytial virus Ag [Presence] in Nasopharynx by Immunofluorescence | 0.886 |  |
| 3010871 | Adenovirus IgM Ab [Titer] in Serum | 0.886 |  |
| 647182 | Rotavirus Ag [Presence] in Specimen by Immunoassay | 0.885 |  |
| 1092430 | Influenza virus A H1 RNA [Presence] in Specimen | 0.885 |  |
| 3010092 | Mycoplasma pneumoniae IgM Ab [Titer] in Serum | 0.885 |  |
| 3964727 | Influenza virus A H3 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.885 |  |
| 3045194 | Adenovirus Ab [Titer] in Cerebral spinal fluid | 0.885 |  |
| 46236087 | Parainfluenza virus 2 Ag [Presence] in Bronchoalveolar lavage by Immunofluorescence | 0.884 |  |
| 3050423 | Human bocavirus IgG Ab [Presence] in Specimen | 0.884 |  |
| 3043512 | Parainfluenza virus 1 Ab [Titer] in Cerebral spinal fluid by Complement fixation | 0.883 |  |
| 3015683 | Streptococcus pneumoniae Ag [Presence] in Specimen by Immunofluorescence | 0.883 |  |
| 3015211 | Giardia lamblia Ag [Presence] in Specimen by Immunoassay | 0.883 |  |
| 648510 | Giardia lamblia+Cryptosporidium sp Ag [Measurement] in Stool | 0.881 |  |
| 648236 | Rotavirus Ag [Measurement] in Stool | 0.878 |  |
| 37020808 | Human metapneumovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.877 |  |
| 645828 | Adenovirus Ag [Measurement] in Nasopharynx | 0.876 |  |
| 36305650 | Human metapneumovirus Ag [Presence] in Nasopharynx by Immunofluorescence | 0.876 |  |
| 3002261 | Adenovirus 40+41 Ag [Presence] in Stool by Immunoassay | 0.875 |  |
| 3966116 | Influenza virus A H1 RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.875 |  |
| 3050125 | Giardia lamblia+Cryptosporidium parvum Ag [Presence] in Stool by Rapid, less than 30 minutes | 0.874 |  |
| 3046184 | Adenovirus Ag [Presence] in Nose by Immunofluorescence | 0.871 |  |
| 37021392 | Influenza virus A H3 RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.870 |  |
| 3008787 | Adenovirus Ag [Presence] in Throat by Immunofluorescence | 0.869 |  |
| 3009486 | Mycoplasma pneumoniae Ab [Titer] in Cerebral spinal fluid by Complement fixation | 0.869 |  |
| 3029009 | Influenza virus A H3 Ag [Presence] in Isolate by Immunofluorescence | 0.869 |  |
| 3042194 | Human metapneumovirus RNA [Presence] in Specimen by NAA with probe detection | 0.868 |  |
| 3015977 | Adenovirus Ag [Presence] in Throat by Immunoassay | 0.868 |  |
| 36660307 | Influenza virus A H3 RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.868 |  |
| 36660200 | Influenza virus A H1 2009 pandemic RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.867 |  |
| 36304052 | Adalimumab Ab [Units/volume] in Serum or Plasma | 0.865 |  |
| 647536 | Adenovirus Ab [Measurement] in Cerebral spinal fluid | 0.865 |  |
| 3032731 | Influenza virus A H3 RNA [Presence] in Specimen by NAA with probe detection | 0.864 |  |
| 40770421 | Human metapneumovirus A RNA [Presence] in Specimen by NAA with probe detection | 0.864 |  |
| 3001507 | Influenza virus A identified in Specimen by Bioassay | 0.864 |  |
| 37020057 | Human metapneumovirus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.863 |  |
| 3047351 | Parainfluenza virus 3 Ab [Presence] in Cerebral spinal fluid by Complement fixation | 0.863 |  |
| 1091752 | Human metapneumovirus RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.863 |  |
| 40762316 | Squamous cell carcinoma Ag [Mass/volume] in Peritoneal fluid | 0.862 |  |
| 646282 | Mycoplasma pneumoniae IgM Ab [Measurement] in Serum | 0.862 |  |
| 1091476 | Influenza virus A H3 RNA [Presence] in Specimen by Molecular genetics method | 0.860 |  |
| 3012734 | Streptococcus pneumoniae Ag [Presence] in Sputum by Immunofluorescence | 0.857 |  |
| 3027653 | Mycophenolate [Mass/volume] in Serum or Plasma | 0.857 |  |
| 1091603 | Influenza virus A H1 2009 pandemic RNA [Presence] in Specimen by Molecular genetics method | 0.856 |  |
| 3044408 | Influenza virus A+B Ag [Presence] in Nose | 0.856 |  |
| 40758594 | Influenza virus A H1 2009 pandemic RNA [Presence] in Specimen by NAA with probe detection | 0.854 |  |
| 43054998 | Influenza virus A+B Ag [Presence] in Nose by Rapid immunoassay | 0.854 |  |
| 3049750 | Human bocavirus IgG Ab [Presence] in Specimen by Immunoassay | 0.853 |  |
| 3015080 | Rotavirus [Presence] in Stool by Electron microscopy | 0.853 |  |
| 3009134 | Squamous cell carcinoma Ag [Units/volume] in Pleural fluid | 0.853 |  |
| 36305655 | Human bocavirus DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.853 |  |
| 3014286 | Streptococcus pneumoniae Ag [Presence] in Cerebral spinal fluid | 0.851 |  |
| 3008909 | Norovirus RNA [Presence] in Stool by NAA with probe detection | 0.851 |  |
| 1092017 | Rotavirus A RNA [Presence] in Specimen | 0.850 |  |
| 3021630 | Parainfluenza virus 1 Ab [Units/volume] in Body fluid | 0.849 |  |
| 3037758 | Squamous cell carcinoma Ag [Moles/volume] in Pleural fluid | 0.847 |  |
| 3031540 | Cytomegalovirus IgG Ab [Presence] in Cerebral spinal fluid | 0.846 |  |
| 1259587 | Human bocavirus DNA [Presence] in Upper respiratory specimen by NAA with non-probe detection | 0.842 |  |
| 36303776 | Human bocavirus DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.842 |  |
| 40765161 | Human bocavirus DNA [Presence] in Specimen by NAA with probe detection | 0.841 |  |
| 645278 | Influenza virus A H1 2009 pandemic RNA [Presence] in Specimen by NAA with non-probe detection | 0.841 |  |
| 646316 | Squamous cell carcinoma Ag [Measurement] in Pleural fluid | 0.841 |  |
| 37021321 | Human bocavirus 1+2+3 DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.840 |  |
| 3021349 | Rotavirus IgM Ab [Presence] in Serum | 0.839 |  |
| 3035112 | Parainfluenza virus 3 IgM Ab [Presence] in Serum | 0.839 |  |
| 3038217 | Adenovirus Ab [Units/volume] in Cerebral spinal fluid | 0.837 |  |
| 3044571 | Measles virus IgG Ab [Presence] in Cerebral spinal fluid | 0.836 |  |
| 43533710 | Streptococcus pneumoniae Ag [Presence] in Isolate by Latex agglutination | 0.833 |  |
| 3043257 | Herpes virus 6 IgG Ab [Presence] in Cerebral spinal fluid | 0.833 |  |
| 40758927 | Mycophenolate [Mass/volume] in Serum or Plasma by LC/MS/MS | 0.832 |  |
| 36304315 | Certolizumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.832 |  |
| 3015162 | Norovirus [Presence] in Stool by Electron microscopy | 0.832 |  |
| 3045300 | Herpes simplex virus IgG Ab [Presence] in Cerebral spinal fluid | 0.831 |  |
| 1175645 | Adalimumab Ab [Units/volume] in Serum by Immunoassay | 0.829 |  |
| 3965476 | Ustekinumab and Ustekinumab Ab panel - Serum or Plasma | 0.829 |  |
| 44786774 | Adalimumab [Mass/volume] in Serum or Plasma | 0.829 |  |
| 36306063 | Golimumab Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.828 |  |
| 3049508 | Influenza virus A and B identified in Specimen by Bioassay | 0.827 |  |
| 1091110 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Specimen | 0.827 |  |
| 36032419 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Immunoassay | 0.827 |  |
| 37020237 | Influenza virus A subtype [Identifier] in Upper respiratory specimen by NAA with probe detection | 0.822 |  |
| 36305036 | Ustekinumab Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.819 |  |
| 723477 | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.819 |  |
| 36304617 | Golimumab [Mass/volume] in Serum or Plasma by Immunoassay | 0.818 |  |
| 37021252 | Influenza virus B RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.818 |  |
| 37021091 | Influenza virus identified in Upper respiratory specimen by Organism specific culture | 0.816 |  |
| 1989156 | Adalimumab and Adalimumab Ab panel - Serum or Plasma by Immunoassay | 0.816 |  |
| 3023788 | Influenza virus identified in Specimen by Organism specific culture | 0.814 | 1081 |
| 1175638 | Influenza virus A subtype [Identifier] in Lower respiratory specimen by NAA with probe detection | 0.814 |  |
| 1091638 | Risankizumab Ab panel - Serum or Plasma | 0.813 |  |
| 40758035 | Norovirus genogroup I RNA [Presence] in Stool by NAA with probe detection | 0.812 |  |
| 21493479 | Norovirus genogroup I+II RNA [Presence] in Stool by NAA with non-probe detection | 0.811 |  |
| 36203322 | Influenza virus B RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.811 |  |
| 36033641 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.809 |  |
| 43055501 | Mycophenolate [Mass/volume] in Serum or Plasma --trough | 0.808 |  |
| 36303956 | Influenza virus identified in Lower respiratory specimen by Organism specific culture | 0.807 |  |
| 40761116 | Natalizumab Ab [Presence] in Serum | 0.807 |  |
| 21492987 | Influenza virus A and B Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.806 |  |
| 42868685 | Mycophenolate [Moles/volume] in Serum or Plasma | 0.804 | 1787 |
| 36304919 | Influenza virus B RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.802 |  |
| 757685 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.799 |  |
| 44786773 | Adalimumab Ab [Mass/volume] in Serum or Plasma | 0.798 |  |
| 42528612 | riTUXimab [Mass/volume] in Serum or Plasma by Immunoassay | 0.798 |  |
| 3034661 | Human coronavirus Ag [Presence] in Specimen by Immunofluorescence | 0.798 |  |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.796 |  |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.792 |  |
| 36033643 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.789 |  |
| 3032518 | Natalizumab Ab [Presence] in Serum by Immunoassay | 0.787 |  |
| 46235394 | Respiratory pathogens RNA 8 panel - Specimen by NAA with probe detection | 0.787 |  |
| 1259611 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen | 0.786 |  |
| 36659876 | Respiratory viral pathogens DNA and RNA panel - Lower respiratory specimen by NAA with probe detection | 0.784 |  |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.784 |  |
| 3033385 | SARS coronavirus [Presence] in Specimen | 0.784 |  |
| 43533705 | Mycophenolate [Mass/volume] in Serum or Plasma --peak | 0.783 |  |
| 1092311 | SARS-CoV-2 (COVID-19) RNA [Presence] in Specimen | 0.781 |  |
| 42529121 | Adenovirus and Norovirus and Rotavirus Ag panel - Stool by Rapid immunoassay | 0.781 |  |
| 40763620 | Respiratory pathogens DNA and RNA 12b panel - Specimen by NAA with probe detection | 0.781 |  |
| 40757376 | Respiratory virus Ag [Identifier] in Specimen by Immunofluorescence | 0.780 |  |
| 3029826 | Respiratory pathogens DNA and RNA 12a panel - Specimen by NAA with probe detection | 0.779 |  |
| 21492862 | Rotavirus and Adenovirus Ag panel - Stool by Rapid immunoassay | 0.779 |  |
| 36303341 | Mycophenolate and mycophenolate glucuronide panel - Serum or Plasma | 0.775 |  |
| 648623 | Mycophenolate [Measurement] in Serum or Plasma | 0.774 |  |
| 3966315 | Systemic lupus Ab panel - Serum or Plasma | 0.767 |  |
| 1091483 | SP100 and GP210 Ab.IgG panel - Serum or Plasma | 0.765 |  |
| 42868548 | Enterovirus Ag [Presence] in Stool by Immunoassay | 0.764 |  |
| 37021229 | Gastrointestinal viral pathogens panel - Stool by NAA with probe detection | 0.762 |  |
| 36659953 | Connective tissue autoimmune IgG panel - Serum or Plasma | 0.761 |  |
| 36303490 | Coccidioides immitis IgG and IgM panel - Serum or Plasma | 0.758 |  |
| 649422 | Adalimumab Ab [Measurement] in Serum or Plasma | 0.756 |  |
| 3037738 | Interferon beta Ab [Presence] in Serum or Plasma | 0.751 |  |
| 1091245 | Enteric bacteria panel - Stool by NAA with probe detection | 0.745 |  |
| 1092191 | Enteric pathogen panel - Stool by NAA with probe detection | 0.736 |  |
| 1092353 | Enteric parasite panel - Stool by NAA with probe detection | 0.735 |  |
| 3043231 | Bile acid [Presence] in Bile fluid | 0.722 |  |
| 3046990 | Bile [Presence] in Body fluid | 0.721 |  |
| 21492659 | Gastrointestinal pathogens panel - Stool by NAA with probe detection | 0.712 |  |
| 3044476 | Bile acid [Presence] in Serum | 0.711 |  |
| 42529411 | Gastrointestinal pathogens panel - Stool by Culture | 0.707 |  |
| 3007153 | Bile [Presence] in Stool | 0.706 |  |
| 3043080 | Bile canalicular Ab [Presence] in Serum | 0.685 |  |
| 3044181 | Bile acid [Presence] in Urine | 0.680 |  |
| 46236152 | Bilirubin [Presence] in Peritoneal fluid | 0.652 |  |
| 3044020 | Leukocytes [Presence] in Bile fluid by Light microscopy | 0.647 |  |
| 3023109 | Acetaminophen [Presence] in Bile fluid | 0.640 |  |
| 3045512 | Giardia lamblia Ag [Presence] in Bile fluid | 0.632 |  |
| 3964822 | Translocation analysis in Embryo by Molecular genetics method | 0.541 |  |
| 3966030 | Preimplantation targeted mutation analysis in Embryo by Molecular genetics method | 0.504 |  |
| 3966415 | Preimplantation multigene analysis in Embryo by Molecular genetics method | 0.504 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 711 | -adenag |  | 100% | name | 1964 | 100 |  | -Adenovirus, antigeeni |  |  | Adenovirus Ag [Presence] in Respiratory specimen |
| 712 | -bokaag |  | 100% | name | 187 | 100 |  |  |  |  | Human bocavirus Ag [Presence] in Respiratory specimen |
| 713 | -coinrsv |  | 100% | name | 2490 | 100 |  |  |  |  | Respiratory syncytial virus Ag [Presence] in Respiratory specimen |
| 714 | -inabrsv |  | 100% | name | 19142 | 100 |  |  |  |  | Influenza virus A+B+Respiratory syncytial virus Ag [Presence] in Respiratory specimen |
| 715 | -infaag |  | 100% | name | 10730 | 100 |  | -Influenssa A -virus, antigeeni |  |  | Influenza virus A Ag [Presence] in Respiratory specimen |
| 716 | -infabag |  | 100% | name | 15107 | 100 |  | -Influenssa A ja B -virus, antigeeni |  |  | Influenza virus A+B Ag [Presence] in Respiratory specimen |
| 717 | -infabnh |  | 100% | name | 961 | 100 |  |  |  |  | Influenza virus A+B RNA [Presence] in Respiratory specimen by NAA |
| 718 | -infah03 |  | 100% | name | 227 | 100 |  |  |  |  | Influenza virus A H3 Ag [Presence] in Respiratory specimen |
| 719 | -infah09 |  | 100% | name | 488 | 100 |  |  |  |  | Influenza virus A H1N1(2009) Ag [Presence] in Respiratory specimen |
| 720 | -infah1 |  | 100% | name | 480 | 100 |  |  |  |  | Influenza virus A H1 Ag [Presence] in Respiratory specimen |
| 721 | -infah3 |  | 100% | name | 261 | 100 |  |  |  |  | Influenza virus A H3 Ag [Presence] in Respiratory specimen |
| 722 | -infavt |  | 100% | name | 1271 | 100 |  |  |  |  | Influenza virus A identified in Respiratory specimen |
| 723 | -infbag |  | 100% | name | 10722 | 100 |  | -Influenssa B -virus, antigeeni |  |  | Influenza virus B Ag [Presence] in Respiratory specimen |
| 724 | -infbvt |  | 100% | name | 1271 | 100 |  |  |  |  | Influenza virus B identified in Respiratory specimen |
| 725 | -infl.a |  | 100% | name | 220 | 100 |  |  |  |  | Influenza virus A Ag [Presence] in Respiratory specimen |
| 726 | -infl.b |  | 100% | name | 220 | 100 |  |  |  |  | Influenza virus B Ag [Presence] in Respiratory specimen |
| 727 | -infrpak |  | 100% | name | 1338 | 100 |  |  |  |  | Respiratory viruses Ag panel - Respiratory specimen |
| 728 | -infrsv |  | 100% | name | 162 | 100 |  |  |  |  | Influenza virus+Respiratory syncytial virus Ag [Presence] in Respiratory specimen |
| 729 | -ivf-et |  | 100% | name | 194 | 100 |  |  |  | Special technique | Embryo transfer |
| 730 | -koroag |  | 100% | name | 625 | 100 |  |  |  |  | Coronavirus Ag [Presence] in Respiratory specimen |
| 731 | -metpnag |  | 100% | name | 370 | 100 |  |  |  |  | Human metapneumovirus Ag [Presence] in Respiratory specimen |
| 732 | -pin1ag |  | 100% | name | 1146 | 100 |  | -Parainfluenssa 1 -virus, antigeeni |  |  | Parainfluenza virus 1 Ag [Presence] in Respiratory specimen |
| 733 | -pin2ag |  | 100% | name | 1147 | 100 |  | -Parainfluenssa 2 -virus, antigeeni |  |  | Parainfluenza virus 2 Ag [Presence] in Respiratory specimen |
| 734 | -pin3ag |  | 100% | name | 1147 | 100 |  | -Parainfluenssa 3 -virus, antigeeni |  |  | Parainfluenza virus 3 Ag [Presence] in Respiratory specimen |
| 735 | -pinf1ag |  | 100% | name | 235 | 100 |  |  |  |  | Parainfluenza virus 1 Ag [Presence] in Respiratory specimen |
| 736 | -pinf2ag |  | 100% | name | 235 | 100 |  |  |  |  | Parainfluenza virus 2 Ag [Presence] in Respiratory specimen |
| 737 | -pinf3ag |  | 100% | name | 235 | 100 |  |  |  |  | Parainfluenza virus 3 Ag [Presence] in Respiratory specimen |
| 738 | -pnjiag |  | 100% | name | 188 | 100 |  | -Pneumocystis jirovecii, antigeeni |  |  | Pneumocystis jirovecii Ag [Presence] in Respiratory specimen |
| 739 | -rvirag |  | 100% | name | 3025 | 100 |  | -Respiratoristen virusten antigeeni |  |  | Respiratory viruses Ag panel - Respiratory specimen |
| 740 | -stpnag |  | 100% | name | 4094 | 100 |  | -Streptococcus pneumoniae, antigeeni |  |  | Streptococcus pneumoniae Ag [Presence] in Respiratory specimen |
| 741 | bi-inflamm |  | 100% | name | 311 | 100 |  |  | Bile |  | Inflammatory marker [Presence] in Bile |
| 742 | f-adenag |  | 100% | name | 863 | 100 |  | F -Adenovirus, antigeeni | Feces |  | Adenovirus Ag [Presence] in Stool |
| 743 | f-giarag |  | 100% | name | 218 | 100 |  | F -Giardia, antigeeni | Feces |  | Giardia lamblia Ag [Presence] in Stool |
| 744 | f-gicrag |  | 100% | name | 163 | 99.39 |  |  | Feces |  | Giardia lamblia+Cryptosporidium Ag [Presence] in Stool |
| 745 | f-noroag |  | 100% | name | 1048 | 100 |  |  | Feces |  | Norovirus Ag [Presence] in Stool |
| 746 | f-rotaag |  | 100% | name | 886 | 100 |  | F -Rotavirus, antigeeni | Feces |  | Rotavirus Ag [Presence] in Stool |
| 747 | f-virag |  | 100% | name | 489 | 100 |  |  | Feces |  | Enteric viruses Ag panel - Stool |
| 748 | li-adenabg |  | 100% | name | 215 | 100 |  | Li-Adenovirus, IgG-vasta-aineet | Cerebrospinal fluid |  | Adenovirus IgG Ab [Presence] in Cerebral spinal fluid |
| 749 | li-infaabg | eiu | 14% | name+unit | 40 | 0 |  | Li-Influenssa A -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza virus A IgG Ab [Units/volume] in Cerebral spinal fluid |
| 750 | li-infaabg |  | 86% | name | 240 | 100 |  | Li-Influenssa A -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza virus A IgG Ab [Presence] in Cerebral spinal fluid |
| 751 | li-infbabg | eiu | 7% | name+unit | 18 | 0 |  | Li-Influenssa B -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza virus B IgG Ab [Units/volume] in Cerebral spinal fluid |
| 752 | li-infbabg |  | 93% | name | 258 | 100 |  | Li-Influenssa B -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Influenza virus B IgG Ab [Presence] in Cerebral spinal fluid |
| 753 | li-mypnab |  | 100% | name | 614 | 100 |  | Li-Mycoplasma pneumoniae, vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae Ab [Presence] in Cerebral spinal fluid |
| 754 | li-mypnabg | eiu | 2% | name+unit | 32 | 0 |  | Li-Mycoplasma pneumoniae, IgG-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Cerebral spinal fluid |
| 755 | li-mypnabg |  | 98% | name | 1292 | 100 |  | Li-Mycoplasma pneumoniae, IgG-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgG Ab [Presence] in Cerebral spinal fluid |
| 756 | li-mypnabm |  | 100% | name | 1314 | 100 |  | Li-Mycoplasma pneumoniae, IgM-vasta-aineet | Cerebrospinal fluid |  | Mycoplasma pneumoniae IgM Ab [Presence] in Cerebral spinal fluid |
| 757 | li-pin1abg | eiu | 4% | name+unit | 7 | 0 |  | Li-Parainfluenssa 1 -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Parainfluenza virus 1 IgG Ab [Units/volume] in Cerebral spinal fluid |
| 758 | li-pin1abg |  | 96% | name | 161 | 100 |  | Li-Parainfluenssa 1 -virus, IgG-vasta-aineet | Cerebrospinal fluid |  | Parainfluenza virus 1 IgG Ab [Presence] in Cerebral spinal fluid |
| 759 | ns-infab/r |  | 100% | name | 181 | 100 |  |  | Nasal secretion |  | Influenza virus A+B+Respiratory syncytial virus Ag [Presence] in Nasal specimen |
| 760 | ps-adenag |  | 100% | name | 1955 | 100 |  | Ps-Adenovirus, antigeeni (NPS-näyte) | Pharyngeal secretion |  | Adenovirus Ag [Presence] in Nasopharynx |
| 761 | ps-infaag |  | 100% | name | 11885 | 100 |  |  | Pharyngeal secretion |  | Influenza virus A Ag [Presence] in Pharynx |
| 762 | ps-infbag |  | 100% | name | 11881 | 100 |  |  | Pharyngeal secretion |  | Influenza virus B Ag [Presence] in Pharynx |
| 763 | rvirag-o |  | 100% | name | 340 | 100 |  |  |  | Qualitative test (also semi-quantitative) | Respiratory viruses Ag panel - Respiratory specimen |
| 764 | s-adenabg | eiu | 89% | name+unit+values | 240 | 0 | [29.8, 39.96, 46.52, 56.21, 66.99, 76.86, 88.44, 100.94, 123.7] | S -Adenovirus, IgG-vasta-aineet | Serum |  | Adenovirus IgG Ab [Units/volume] in Serum |
| 765 | s-adenabg |  | 11% | name | 30 | 96.67 |  | S -Adenovirus, IgG-vasta-aineet | Serum |  | Adenovirus IgG Ab [Presence] in Serum |
| 766 | s-infaabg | eiu | 79% | name+unit+values | 288 | 0 | [44.84, 67.49, 80.03, 92.84, 100.98, 109.5, 120.03, 134.44, 150.75] | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza virus A IgG Ab [Units/volume] in Serum |
| 767 | s-infaabg | u/ml | 8% | name+unit | 31 | 0 |  | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza virus A IgG Ab [Units/volume] in Serum |
| 768 | s-infaabg |  | 13% | name | 46 | 71.74 |  | S -Influenssa A -virus, IgG-vasta-aineet | Serum |  | Influenza virus A IgG Ab [Presence] in Serum |
| 769 | s-infbab | eiu | 68% | name+unit+values | 84 | 0 | [37, 45.5, 59.88, 67.83, 76.88, 87.5, 108.12, 125, 142] | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza virus B Ab [Units/volume] in Serum |
| 770 | s-infbab | u/ml | 16% | name+unit | 20 | 0 |  | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza virus B Ab [Units/volume] in Serum |
| 771 | s-infbab |  | 16% | name | 20 | 100 |  | S -Influenssa B -virus, vasta-aineet | Serum |  | Influenza virus B Ab [Presence] in Serum |
| 772 | s-infbabg | eiu | 89% | name+unit+values | 202 | 0 | [27.36, 39.2, 49.01, 55.71, 69.1, 81.14, 95.12, 117.99, 145.85] | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza virus B IgG Ab [Units/volume] in Serum |
| 773 | s-infbabg | u/ml | 2% | name+unit | 5 | 0 |  | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza virus B IgG Ab [Units/volume] in Serum |
| 774 | s-infbabg |  | 8% | name | 19 | 73.68 |  | S-Influenssa B -virus, IgG-vasta-aineet | Serum |  | Influenza virus B IgG Ab [Presence] in Serum |
| 775 | s-infli | mg/l | 74% | name+unit+values | 4337 | 0.09 | [2.45, 4.22, 5.77, 7.21, 8.78, 10.55, 12.36, 14.93, 19.68] | S -Infliksimabi | Serum |  | Infliximab [Mass/volume] in Serum or Plasma |
| 776 | s-infli | ug/l | 1% | name+unit | 62 | 0 |  | S -Infliksimabi | Serum |  | Infliximab [Mass/volume] in Serum or Plasma |
| 777 | s-infli | âug/ml | 0% | name+unit | 5 | 0 |  | S -Infliksimabi | Serum |  | Infliximab [Mass/volume] in Serum or Plasma |
| 778 | s-infli |  | 25% | name+values | 1486 | 32.77 | [2.05, 3.56, 5.06, 6.2, 7.59, 8.94, 10.97, 13.84, 18.03] | S -Infliksimabi | Serum |  | Infliximab [Mass/volume] in Serum or Plasma |
| 779 | s-infliab | au/ml | 8% | name+unit+values | 413 | 0.73 | [6.57, 14.16, 21.28, 34.4, 52.11, 73.2, 118.89, 190.88, 374.2] | S -Infliksimabi, vasta-aineet | Serum |  | Infliximab Ab [Units/volume] in Serum or Plasma |
| 780 | s-infliab |  | 92% | name | 4455 | 99.89 |  | S -Infliksimabi, vasta-aineet | Serum |  | Infliximab Ab [Presence] in Serum or Plasma |
| 781 | s-infliks | mg/l | 75% | name+unit+values | 951 | 0 | [1.81, 3, 4.49, 5.55, 6.66, 8.19, 10.34, 13.5, 19.13] |  | Serum |  | Infliximab [Mass/volume] in Serum or Plasma |
| 782 | s-infliks |  | 25% | name+values | 310 | 30.97 | [1.21, 2.24, 3.08, 4.32, 5.17, 6.19, 7.17, 7.95, 9.17] |  | Serum |  | Infliximab [Mass/volume] in Serum or Plasma |
| 783 | s-inflipa |  | 100% | name | 4630 | 100 |  |  | Serum |  | Infliximab and Infliximab Ab panel - Serum or Plasma |
| 784 | s-micfaeg | mg/l | 33% | name+unit | 45 | 0 |  |  | Serum |  | Mycophenolic acid glucuronide [Mass/volume] in Serum or Plasma |
| 785 | s-micfaeg |  | 67% | name | 90 | 76.67 |  |  | Serum |  | Mycophenolic acid glucuronide [Mass/volume] in Serum or Plasma |
| 786 | s-mypnab |  | 100% | name | 19694 | 99.92 |  | S -Mycoplasma pneumoniae, vasta-aineet | Serum |  | Mycoplasma pneumoniae Ab [Presence] in Serum |
| 787 | s-mypnabg | au/ml | 13% | name+unit+values | 2298 | 0 | [0.52, 1.18, 1.86, 2.68, 3.78, 5.69, 8.99, 16.54, 33.76] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum |
| 788 | s-mypnabg | eiu | 55% | name+unit+values | 9577 | 0 | [51.21, 64.99, 79.08, 95.09, 113.13, 134.88, 160.85, 200.43, 260.64] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum |
| 789 | s-mypnabg | form | 0% | name+unit | 53 | 0 |  | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Presence] in Serum |
| 790 | s-mypnabg | ru/ml | 2% | name+unit+values | 384 | 0 | [19.56, 23.19, 26.12, 30.65, 34.99, 40.45, 50.94, 60.03, 79.86] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum |
| 791 | s-mypnabg |  | 29% | name+values | 4994 | 100 | [0.53, 1.1, 1.73, 2.48, 3.76, 5.77, 9.79, 21.47, 68.82] | S -Mycoplasma pneumoniae, IgG-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgG Ab [Units/volume] in Serum |
| 792 | s-mypnabm | form | 0% | name+unit | 16 | 0 |  | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM Ab [Presence] in Serum |
| 793 | s-mypnabm | index | 21% | name+unit+values | 3618 | 0 | [1.53, 2.22, 2.83, 3.43, 4.2, 5.16, 6.56, 8.38, 11.18] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM Ab [Ratio] in Serum |
| 794 | s-mypnabm | s/co | 6% | name+unit+values | 1089 | 0 | [0.1, 0.1, 0.2, 0.2, 0.3, 0.33, 0.47, 0.63, 1.13] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM Ab [Ratio] in Serum |
| 795 | s-mypnabm |  | 73% | name+values | 12775 | 100 | [1.19, 1.67, 2.14, 2.58, 3.04, 3.6, 4.51, 5.78, 8.21] | S -Mycoplasma pneumoniae, IgM-vasta-aineet | Serum |  | Mycoplasma pneumoniae IgM Ab [Ratio] in Serum |
| 796 | s-pin1abg | eiu | 96% | name+unit+values | 209 | 0 | [51.38, 65.97, 78.97, 87.7, 96.4, 106.81, 114.5, 126.75, 144.62] | S -Parainfluenssa 1 -virus, IgG-vasta-aineet | Serum |  | Parainfluenza virus 1 IgG Ab [Units/volume] in Serum |
| 797 | s-pin1abg |  | 4% | name | 9 | 88.89 |  | S -Parainfluenssa 1 -virus, IgG-vasta-aineet | Serum |  | Parainfluenza virus 1 IgG Ab [Presence] in Serum |
| 798 | s-scc-ag | ug/l | 66% | name+unit+values | 959 | 0 | [0.88, 1.03, 1.2, 1.38, 1.6, 2.01, 2.55, 3.56, 6.69] | S -Squamous cell carsinoma, antigeeni | Serum | Antigen | Squamous cell carcinoma Ag [Mass/volume] in Serum or Plasma |
| 799 | s-scc-ag |  | 34% | name | 493 | 95.94 |  | S -Squamous cell carsinoma, antigeeni | Serum | Antigen | Squamous cell carcinoma Ag [Mass/volume] in Serum or Plasma |
| 800 | u-lepnag |  | 100% | name | 3943 | 100 |  | U -Legionella pneumophila, antigeeni | Urine |  | Legionella pneumophila serogroup 1 Ag [Presence] in Urine |
| 801 | u-pneuag |  | 100% | name | 2058 | 100 |  |  | Urine |  | Streptococcus pneumoniae Ag [Presence] in Urine |
| 802 | u-stpnag |  | 100% | name | 2546 | 100 |  | U -Streptococcus pneumoniae, antigeeni | Urine |  | Streptococcus pneumoniae Ag [Presence] in Urine |

