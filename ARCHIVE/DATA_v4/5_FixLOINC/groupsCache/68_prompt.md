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
Here is group 68.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 21491660 | Streptococcus pyogenes Ag [Presence] in Throat by Rapid immunoassay | 1.000 | 1051 |
| 40763543 | Streptococcus pyogenes DNA [Presence] in Throat by NAA with probe detection | 1.000 |  |
| 3964796 | Streptococcus pyogenes DNA [Presence] in Throat by NAA with non-probe detection | 0.975 |  |
| 3029920 | Streptococcus pneumoniae capsular polysaccharide IgG2 Ab [Mass/volume] in Serum | 0.943 |  |
| 3045274 | Streptococcus pneumoniae IgG Ab [Mass/volume] in Serum | 0.942 |  |
| 36204005 | Streptococcus pneumoniae Danish serotype 19F IgG Ab [Mass/volume] in Serum | 0.941 | 1324 |
| 36204094 | Streptococcus pneumoniae Danish serotype 23F IgG Ab [Mass/volume] in Serum | 0.940 | 1326 |
| 3038232 | Streptococcus pneumoniae Danish serotype 33F IgG Ab [Mass/volume] in Serum | 0.939 |  |
| 3000899 | Streptococcus pneumoniae Danish serotype 7F IgG Ab [Mass/volume] in Serum | 0.936 | 1384 |
| 3005260 | Streptococcus pneumoniae Danish serotype 9V IgG Ab [Mass/volume] in Serum | 0.935 | 1331 |
| 36203922 | Streptococcus pneumoniae Danish serotype 14 IgG Ab [Mass/volume] in Serum | 0.934 | 1259 |
| 3042065 | Streptococcus pneumoniae Danish serotype 15B IgG Ab [Mass/volume] in Serum | 0.932 |  |
| 1260031 | Streptococcus pyogenes DNA [Presence] in Specimen by NAA with probe detection | 0.932 |  |
| 3006665 | Streptococcus pneumoniae Danish serotype 18C IgG Ab [Mass/volume] in Serum | 0.932 | 1320 |
| 3022344 | Streptococcus pneumoniae IgG Ab [Units/volume] in Serum | 0.931 |  |
| 36204178 | Streptococcus pneumoniae Danish serotype 10A IgG Ab [Mass/volume] in Serum | 0.930 |  |
| 36203229 | Streptococcus pneumoniae Danish serotype 12F IgG Ab [Units/volume] in Serum | 0.930 |  |
| 36203990 | Streptococcus pneumoniae Danish serotype 17F IgG Ab [Mass/volume] in Serum | 0.929 |  |
| 36204022 | Streptococcus pneumoniae Danish serotype 20A IgG Ab [Mass/volume] in Serum | 0.928 |  |
| 3005665 | Streptococcus pneumoniae Danish serotype 6B IgG Ab [Mass/volume] in Serum | 0.927 | 1378 |
| 36203231 | Streptococcus pneumoniae Danish serotype 12F IgG Ab [Mass/volume] in Serum | 0.927 | 1402 |
| 36204278 | Streptococcus pneumoniae Danish serotype 11A IgG Ab [Mass/volume] in Serum | 0.926 |  |
| 36204351 | Streptococcus pneumoniae Danish serotype 8 IgG Ab [Mass/volume] in Serum | 0.925 | 1386 |
| 36204353 | Streptococcus pneumoniae Danish serotype 8 IgG Ab [Units/volume] in Serum | 0.923 |  |
| 36204187 | Streptococcus pneumoniae Danish serotype 4 IgG Ab [Mass/volume] in Serum | 0.922 | 1328 |
| 36204016 | Streptococcus pneumoniae Danish serotype 2 IgG Ab [Mass/volume] in Serum | 0.922 |  |
| 3033319 | Streptococcus pyogenes Ag [Presence] in Throat | 0.921 | 337 |
| 3024135 | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | 0.918 | 521 |
| 36204286 | Streptococcus pneumoniae Danish serotype 5 IgG Ab [Mass/volume] in Serum | 0.917 |  |
| 36203821 | Streptococcus pneumoniae Danish serotype 1 IgG Ab [Mass/volume] in Serum | 0.916 | 1394 |
| 36204002 | Streptococcus pneumoniae Danish serotype 19F IgG Ab [Mass/volume] in Serum by Immunoassay | 0.914 | 1325 |
| 3030716 | Streptococcus pneumoniae capsular polysaccharide IgG2 Ab [Mass/volume] in Serum by Immunoassay | 0.913 |  |
| 36204091 | Streptococcus pneumoniae Danish serotype 23F IgG Ab [Mass/volume] in Serum by Immunoassay | 0.912 | 1327 |
| 3050060 | Streptococcus pneumoniae Danish serotype 33F IgG Ab [Mass/volume] in Serum by Immunoassay | 0.911 |  |
| 3030009 | Streptococcus pneumoniae capsular polysaccharide IgG Ab [Mass/volume] in Serum | 0.910 |  |
| 3017906 | Streptococcus pyogenes Ag [Presence] in Specimen by Immunoassay | 0.910 |  |
| 3041754 | Streptococcus pneumoniae Danish serotype 9V IgG Ab [Mass/volume] in Serum by Immunoassay | 0.909 | 1332 |
| 3041896 | Streptococcus pneumoniae Danish serotype 7F IgG Ab [Mass/volume] in Serum by Immunoassay | 0.907 | 1385 |
| 36203909 | Streptococcus pneumoniae Danish serotype 12F IgG Ab [Mass/volume] in Serum by Immunoassay | 0.907 | 1403 |
| 36204373 | Streptococcus pneumoniae Danish serotype 9N IgG Ab [Mass/volume] in Serum | 0.906 | 1388 |
| 36203230 | Streptococcus pneumoniae Danish serotype 12F IgG Ab [Units/volume] in Serum by Immunoassay | 0.905 |  |
| 36204292 | Streptococcus pneumoniae Danish serotype 6A IgG Ab [Mass/volume] in Serum | 0.905 |  |
| 36203923 | Streptococcus pneumoniae Danish serotype 14 IgG Ab [Mass/volume] in Serum by Immunoassay | 0.905 | 1260 |
| 1092209 | Streptococcus sp DNA [Presence] in Specimen by NAA with probe detection | 0.905 |  |
| 3043253 | Streptococcus pneumoniae IgG Ab [Mass/volume] in Serum by Immunoassay | 0.905 |  |
| 36204023 | Streptococcus pneumoniae Danish serotype 20A IgG Ab [Mass/volume] in Serum by Immunoassay | 0.905 |  |
| 3039571 | Streptococcus pneumoniae Danish serotype 18C IgG Ab [Mass/volume] in Serum by Immunoassay | 0.903 | 1321 |
| 36204179 | Streptococcus pneumoniae Danish serotype 10A IgG Ab [Mass/volume] in Serum by Immunoassay | 0.902 |  |
| 36204354 | Streptococcus pneumoniae Danish serotype 8 IgG Ab [Units/volume] in Serum by Immunoassay | 0.902 |  |
| 3017364 | Streptococcus pyogenes Ag [Presence] in Throat by Immunofluorescence | 0.901 |  |
| 36204279 | Streptococcus pneumoniae Danish serotype 11A IgG Ab [Mass/volume] in Serum by Immunoassay | 0.901 |  |
| 3012475 | Bacteria identified in Throat by Culture | 0.901 | 638 |
| 36204001 | Streptococcus pneumoniae Danish serotype 19F Ab [Mass/volume] in Serum | 0.901 |  |
| 36660467 | Streptococcus pyogenes DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.900 |  |
| 36204188 | Streptococcus pneumoniae Danish serotype 4 IgG Ab [Mass/volume] in Serum by Immunoassay | 0.900 | 1329 |
| 3966418 | Streptococcus pyogenes DNA [Presence] in Wound by NAA with probe detection | 0.900 |  |
| 36204352 | Streptococcus pneumoniae Danish serotype 8 IgG Ab [Mass/volume] in Serum by Immunoassay | 0.900 | 1387 |
| 3049388 | Streptococcus pneumoniae Danish serotype 15B IgG Ab [Mass/volume] in Serum by Immunoassay | 0.900 |  |
| 36203991 | Streptococcus pneumoniae Danish serotype 17F IgG Ab [Mass/volume] in Serum by Immunoassay | 0.900 |  |
| 3038550 | Streptococcus pneumoniae Danish serotype 6B IgG Ab [Mass/volume] in Serum by Immunoassay | 0.899 | 1379 |
| 36204003 | Streptococcus pneumoniae Danish serotype 19F IgG Ab [Units/volume] in Serum | 0.899 |  |
| 3018048 | Streptococcus pneumoniae Danish serotype 7F IgG Ab [Units/volume] in Serum | 0.897 |  |
| 3025151 | Streptococcus pneumoniae IgM Ab [Units/volume] in Serum | 0.896 |  |
| 3000712 | Streptococcus pneumoniae Danish serotype 9V IgG Ab [Units/volume] in Serum | 0.896 |  |
| 36204285 | Streptococcus pneumoniae Danish serotype 5 IgG Ab [Mass/volume] in Serum by Immunoassay | 0.896 |  |
| 3000124 | Streptococcus pneumoniae Ab [Mass/volume] in Serum | 0.895 |  |
| 3964996 | Streptococcus dysgalactiae subspecies equisimilis DNA [Presence] in Throat by NAA with non-probe detection | 0.895 |  |
| 36203997 | Streptococcus pneumoniae Danish serotype 18F IgG Ab [Mass/volume] in Serum | 0.895 |  |
| 36204092 | Streptococcus pneumoniae Danish serotype 23F IgG Ab [Units/volume] in Serum | 0.894 |  |
| 3024832 | Streptococcus pneumoniae Danish serotype 18C IgG Ab [Units/volume] in Serum | 0.893 |  |
| 36204015 | Streptococcus pneumoniae Danish serotype 2 IgG Ab [Mass/volume] in Serum by Immunoassay | 0.893 |  |
| 3036452 | Chlamydia sp DNA [Presence] in Throat by NAA with probe detection | 0.893 |  |
| 1469570 | Streptococcus pyogenes DNA [Presence] in Body fluid by NAA with non-probe detection | 0.892 |  |
| 36203822 | Streptococcus pneumoniae Danish serotype 1 IgG Ab [Mass/volume] in Serum by Immunoassay | 0.892 | 1395 |
| 646031 | Streptococcus pneumoniae Danish serotype 19F IgG Ab [Measurement] in Serum | 0.891 |  |
| 3026908 | Streptococcus pneumoniae Danish serotype 18C Ab [Mass/volume] in Serum | 0.891 |  |
| 36204029 | Streptococcus pneumoniae Danish serotype 22F IgG Ab [Mass/volume] in Serum | 0.891 |  |
| 1092273 | Streptococcus salivarius DNA [Presence] in Specimen by NAA with probe detection | 0.890 |  |
| 36204090 | Streptococcus pneumoniae Danish serotype 23F Ab [Mass/volume] in Serum | 0.890 |  |
| 36203907 | Streptococcus pneumoniae Danish serotype 12F Ab [Units/volume] in Serum | 0.890 |  |
| 36303893 | Neisseria gonorrhoeae DNA [Presence] in Throat by NAA with probe detection | 0.889 |  |
| 3011310 | Streptococcus pneumoniae Ab [Units/volume] in Serum | 0.889 |  |
| 3032017 | Streptococcus pneumoniae Danish serotype 19B IgG Ab [Mass/volume] in Serum | 0.889 |  |
| 3026606 | Streptococcus pneumoniae Danish serotype 7F Ab [Mass/volume] in Serum | 0.889 |  |
| 3031967 | Streptococcus pneumoniae 4 serotypes IgG panel [Mass/volume] - Serum | 0.888 |  |
| 37020473 | Streptococcus pyogenes DNA [Presence] by NAA with probe detection in Positive blood culture | 0.888 |  |
| 36203924 | Streptococcus pneumoniae Danish serotype 14 IgG Ab [Units/volume] in Serum | 0.888 |  |
| 646760 | Streptococcus pneumoniae Danish serotype 7F IgG Ab [Measurement] in Serum | 0.886 |  |
| 648075 | Streptococcus pneumoniae Danish serotype 9V IgG Ab [Measurement] in Serum | 0.886 |  |
| 1091086 | Streptococcus pneumoniae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.886 |  |
| 3009696 | Streptococcus pneumoniae IgG Ab [Units/volume] in Serum by Immunoassay | 0.885 |  |
| 36204349 | Streptococcus pneumoniae Danish serotype 8 Ab [Units/volume] in Serum | 0.885 |  |
| 647089 | Streptococcus pneumoniae Danish serotype 23F IgG Ab [Measurement] in Serum | 0.885 |  |
| 3044549 | Streptococcus pneumoniae Danish serotype 19A IgG Ab [Mass/volume] in Serum | 0.884 | 1471 |
| 36204185 | Streptococcus pneumoniae Danish serotype 4 Ab [Mass/volume] in Serum | 0.884 |  |
| 649541 | Streptococcus pneumoniae Danish serotype 12F IgG Ab [Measurement] in Serum | 0.883 |  |
| 36204189 | Streptococcus pneumoniae Danish serotype 4 IgG Ab [Units/volume] in Serum | 0.883 |  |
| 3029357 | Streptococcus pneumoniae capsular polysaccharide IgG Ab [Mass/volume] in Serum by Immunoassay | 0.882 |  |
| 3005264 | Streptococcus pneumoniae Danish serotype 6B IgG Ab [Units/volume] in Serum | 0.882 |  |
| 3045758 | Streptococcus pneumoniae Danish serotype 6B Ab [Mass/volume] in Serum | 0.882 |  |
| 36203920 | Streptococcus pneumoniae Danish serotype 14 Ab [Mass/volume] in Serum | 0.882 |  |
| 36204370 | Streptococcus pneumoniae Danish serotype 9N IgG Ab [Mass/volume] in Serum by Immunoassay | 0.881 | 1389 |
| 649217 | Streptococcus pneumoniae Danish serotype 18C IgG Ab [Measurement] in Serum | 0.881 |  |
| 36204294 | Streptococcus pneumoniae Danish serotype 6A IgG Ab [Mass/volume] in Serum by Immunoassay | 0.881 |  |
| 36203906 | Streptococcus pneumoniae Danish serotype 12F Ab [Mass/volume] in Serum | 0.880 |  |
| 645976 | Streptococcus pneumoniae Danish serotype 14 IgG Ab [Measurement] in Serum | 0.880 |  |
| 36204350 | Streptococcus pneumoniae Danish serotype 8 Ab [Mass/volume] in Serum | 0.879 |  |
| 646420 | Streptococcus pneumoniae Danish serotype 6B IgG Ab [Measurement] in Serum | 0.878 |  |
| 42868504 | Streptococcus sp DNA [Presence] in Blood by NAA with probe detection | 0.878 |  |
| 3052873 | Streptococcus pneumoniae Danish serotype 33F IgG Ab [Mass/volume] in Serum --1st specimen | 0.877 |  |
| 648147 | Streptococcus pneumoniae Danish serotype 8 IgG Ab [Measurement] in Serum | 0.876 |  |
| 3023273 | Streptococcus pneumoniae IgG Ab [Units/volume] in Serum --2nd specimen | 0.874 |  |
| 3048760 | Streptococcus pneumoniae Danish serotype 9V IgG Ab [Mass/volume] in Serum --1st specimen | 0.874 |  |
| 3025980 | Streptococcus pneumoniae Danish serotype 7F IgG Ab [Units/volume] in Serum by Immunoassay | 0.874 |  |
| 3007861 | Streptococcus pneumoniae Danish serotype 7F IgG Ab [Mass/volume] in Serum --1st specimen | 0.873 |  |
| 36203992 | Streptococcus pneumoniae Danish serotype 17F IgG Ab [Mass/volume] in Serum --1st specimen | 0.873 |  |
| 649584 | Streptococcus pneumoniae Danish serotype 4 IgG Ab [Measurement] in Serum | 0.873 |  |
| 36203572 | Streptococcus pyogenes DNA [Presence] by NAA with non-probe detection in Positive blood culture | 0.872 |  |
| 3000924 | Streptococcus pyogenes [Presence] in Throat by Organism specific culture | 0.869 |  |
| 3017141 | Streptococcus pneumoniae Danish serotype 18C IgG Ab [Mass/volume] in Serum --1st specimen | 0.869 |  |
| 3021098 | Streptococcus pneumoniae Danish serotype 18C IgG Ab [Units/volume] in Serum by Immunoassay | 0.867 |  |
| 3023238 | Streptococcus pneumoniae Danish serotype 7F Ab [Units/volume] in Serum | 0.867 |  |
| 36204024 | Streptococcus pneumoniae Danish serotype 20A IgG Ab [Mass/volume] in Serum --1st specimen | 0.864 |  |
| 36204180 | Streptococcus pneumoniae Danish serotype 10A IgG Ab [Mass/volume] in Serum --1st specimen | 0.863 |  |
| 36204297 | Streptococcus pneumoniae Danish serotype 7A IgG Ab [Units/volume] in Serum | 0.862 |  |
| 36204093 | Streptococcus pneumoniae Danish serotype 23F IgG Ab [Units/volume] in Serum by Immunoassay | 0.859 |  |
| 3014999 | Streptococcus pneumoniae Ab [Units/volume] in Serum by Immunoassay | 0.858 |  |
| 648685 | Streptococcus pneumoniae IgG Ab [Measurement] in Serum | 0.858 |  |
| 36203891 | Streptococcus pneumoniae Danish serotype 1 IgG Ab [Units/volume] in Serum | 0.855 |  |
| 647010 | Streptococcus pyogenes Ag [Measurement] in Throat | 0.854 |  |
| 36204026 | Streptococcus pneumoniae Danish serotype 20A IgG Ab [Mass/volume] in Serum --2nd specimen | 0.854 |  |
| 1092202 | Streptococcus pyogenes [Presence] in Specimen | 0.852 |  |
| 36204004 | Streptococcus pneumoniae Danish serotype 19F IgG Ab [Units/volume] in Serum by Immunoassay | 0.850 |  |
| 3008051 | Streptococcus pyogenes Ag [Presence] in Specimen | 0.847 |  |
| 3000686 | Virus identified in Throat by Culture | 0.842 |  |
| 3002949 | Streptococcus pyogenes Ag [Presence] in Serum by Agglutination | 0.838 |  |
| 3018201 | Streptococcus pyogenes Ag [Presence] in Specimen by Immunofluorescence | 0.836 |  |
| 3038101 | Streptococcus agalactiae Ag [Presence] in Throat by Immunofluorescence | 0.835 |  |
| 3018121 | Streptococcus pyogenes Ag [Presence] in Serum | 0.831 |  |
| 3014536 | Streptococcus agalactiae Ag [Presence] in Throat | 0.828 |  |
| 3024740 | Streptococcus.beta-hemolytic [Presence] in Specimen by Organism specific culture | 0.827 | 334 |
| 40771489 | Streptococcus pyogenes rRNA [Presence] in Throat by Probe | 0.811 |  |
| 3035740 | Bacteria identified in Throat by Aerobe culture | 0.810 | 526 |
| 3047233 | Neisseria sp identified in Throat by Organism specific culture | 0.810 |  |
| 1091932 | Fungus identified in Throat by Culture | 0.797 |  |
| 3010629 | Chlamydia sp identified in Throat by Organism specific culture | 0.796 |  |
| 37020272 | Bordetella sp identified in Throat by Organism specific culture | 0.795 |  |
| 3053028 | Streptococcus sp identified in Specimen by Organism specific culture | 0.791 |  |
| 3013103 | Diphtheria identified in Throat by Organism specific culture | 0.787 |  |
| 3036007 | Streptococcus agalactiae [Presence] in Throat by Organism specific culture | 0.786 |  |
| 3005214 | Streptococcus.beta-hemolytic [Presence] in Genital specimen by Organism specific culture | 0.762 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 698 | ps-str-vi |  | 100% | name | 2795 | 100 |  |  | Pharyngeal secretion | Culture | Streptococcus.beta-hemolytic identified in Throat by Organism specific culture |
| 699 | ps-str1vrk |  | 100% | name | 166 | 100 |  |  | Pharyngeal secretion |  | Streptococcus identified in Throat by Culture |
| 700 | ps-stra-ag |  | 100% | name | 621 | 100 |  |  | Pharyngeal secretion | Antigen | Streptococcus pyogenes Ag [Presence] in Throat by Immunoassay |
| 701 | ps-stra-o |  | 100% | name | 204 | 100 |  |  | Pharyngeal secretion | Qualitative test (also semi-quantitative) | Streptococcus pyogenes [Presence] in Throat |
| 702 | ps-straag | form | 0% | name+unit | 12 | 0 |  | Ps-Streptococcus pyogenes (A), antigeeni | Pharyngeal secretion |  | Streptococcus pyogenes Ag [Presence] in Throat by Immunoassay |
| 703 | ps-straag |  | 100% | name | 85240 | 100 |  | Ps-Streptococcus pyogenes (A), antigeeni | Pharyngeal secretion |  | Streptococcus pyogenes Ag [Presence] in Throat by Immunoassay |
| 704 | ps-straagp |  | 100% | name | 150 | 100 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes Ag [Presence] in Throat by Rapid immunoassay |
| 705 | ps-straag␤ |  | 100% | name | 354 | 100 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes Ag [Presence] in Throat by Immunoassay |
| 706 | ps-stragho |  | 100% | name | 583 | 100 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes Ag [Presence] in Throat by Immunoassay |
| 707 | ps-stranho |  | 100% | name | 656 | 100 |  | Ps-Streptococcus pyogenes (A), nukleiinihappo (kval) | Pharyngeal secretion |  | Streptococcus pyogenes DNA [Presence] in Throat by NAA with probe detection |
| 708 | ps-straohy |  | 100% | name | 1140 | 100 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes [Presence] in Throat |
| 709 | ps-straolb |  | 100% | name | 774 | 100 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes [Presence] in Throat |
| 710 | ps-stravt |  | 100% | name | 124 | 100 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes [Presence] in Throat |
| 711 | ps-strcult |  | 100% | name | 3207 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic identified in Throat by Organism specific culture |
| 712 | ps-strjvi |  | 100% | name | 8058 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic identified in Throat by Organism specific culture |
| 713 | ps-strnho |  | 100% | name | 1019 | 100 |  | Ps-Streptococcus, nukleiinihappo (kval) | Pharyngeal secretion |  | Streptococcus DNA [Presence] in Throat by NAA with probe detection |
| 714 | ps-strtunn |  | 100% | name | 170 | 100 |  |  | Pharyngeal secretion |  | Streptococcus identified in Throat by Culture |
| 715 | ps-strvi | form | 0% | name+unit | 34 | 0 |  | Ps-Streptococcus, viljely (hemolyyttiset streptokokit) | Pharyngeal secretion |  | Streptococcus.beta-hemolytic identified in Throat by Organism specific culture |
| 716 | ps-strvi |  | 100% | name | 159634 | 100 |  | Ps-Streptococcus, viljely (hemolyyttiset streptokokit) | Pharyngeal secretion |  | Streptococcus.beta-hemolytic identified in Throat by Organism specific culture |
| 717 | s-stpn1 | mg/l | 59% | name+unit+values | 441 | 0 | [0.06, 0.11, 0.2, 0.34, 0.51, 0.79, 1.25, 2.43, 6.29] |  | Serum |  | Streptococcus pneumoniae serotype 1 IgG Ab [Mass/volume] in Serum |
| 718 | s-stpn1 |  | 41% | name+values | 305 | 100 | [0.04, 0.08, 0.17, 0.25, 0.42, 0.78, 1.17, 2.27, 6.2] |  | Serum |  | Streptococcus pneumoniae serotype 1 IgG Ab [Mass/volume] in Serum |
| 719 | s-stpn10a | fmiau/ml | 13% | name+unit | 29 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 10A IgG Ab [Units/volume] in Serum |
| 720 | s-stpn10a | ug/mlgmc | 19% | name+unit | 43 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 10A IgG Ab [Mass/volume] in Serum |
| 721 | s-stpn10a |  | 67% | name | 149 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 10A IgG Ab [Mass/volume] in Serum |
| 722 | s-stpn11a | fmiau/ml | 14% | name+unit | 30 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 11A IgG Ab [Units/volume] in Serum |
| 723 | s-stpn11a | ug/mlgmc | 21% | name+unit | 46 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 11A IgG Ab [Mass/volume] in Serum |
| 724 | s-stpn11a |  | 65% | name | 143 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 11A IgG Ab [Mass/volume] in Serum |
| 725 | s-stpn12f | fmiau/ml | 5% | name+unit | 11 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 12F IgG Ab [Units/volume] in Serum |
| 726 | s-stpn12f | ug/mlgmc | 13% | name+unit | 29 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 12F IgG Ab [Mass/volume] in Serum |
| 727 | s-stpn12f |  | 82% | name | 184 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 12F IgG Ab [Mass/volume] in Serum |
| 728 | s-stpn14 | mg/l | 58% | name+unit+values | 419 | 0 | [0.18, 0.31, 0.65, 1.11, 1.71, 2.72, 3.98, 6.24, 12.97] |  | Serum |  | Streptococcus pneumoniae serotype 14 IgG Ab [Mass/volume] in Serum |
| 729 | s-stpn14 |  | 42% | name | 309 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 14 IgG Ab [Mass/volume] in Serum |
| 730 | s-stpn15b | fmiau/ml | 11% | name+unit | 24 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 15B IgG Ab [Units/volume] in Serum |
| 731 | s-stpn15b | mg/l | 4% | name+unit | 9 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 15B IgG Ab [Mass/volume] in Serum |
| 732 | s-stpn15b | ug/mlgmc | 17% | name+unit | 38 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 15B IgG Ab [Mass/volume] in Serum |
| 733 | s-stpn15b |  | 68% | name | 153 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 15B IgG Ab [Mass/volume] in Serum |
| 734 | s-stpn17f | fmiau/ml | 12% | name+unit | 27 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 17F IgG Ab [Units/volume] in Serum |
| 735 | s-stpn17f | ug/mlgmc | 19% | name+unit | 42 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 17F IgG Ab [Mass/volume] in Serum |
| 736 | s-stpn17f |  | 68% | name | 150 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 17F IgG Ab [Mass/volume] in Serum |
| 737 | s-stpn18c | mg/l | 71% | name+unit+values | 515 | 0 | [0.06, 0.12, 0.21, 0.37, 0.6, 0.89, 1.56, 2.97, 7.38] |  | Serum |  | Streptococcus pneumoniae serotype 18C IgG Ab [Mass/volume] in Serum |
| 738 | s-stpn18c |  | 29% | name+values | 213 | 100 | [0.04, 0.07, 0.14, 0.22, 0.5, 0.69, 1.23, 2.41, 4.67] |  | Serum |  | Streptococcus pneumoniae serotype 18C IgG Ab [Mass/volume] in Serum |
| 739 | s-stpn19f | mg/l | 65% | name+unit+values | 475 | 0 | [0.1, 0.17, 0.28, 0.52, 0.88, 1.37, 2.72, 4.87, 10.06] |  | Serum |  | Streptococcus pneumoniae serotype 19F IgG Ab [Mass/volume] in Serum |
| 740 | s-stpn19f |  | 35% | name+values | 253 | 100 | [0.08, 0.13, 0.19, 0.33, 0.73, 1.29, 2.69, 4, 5.8] |  | Serum |  | Streptococcus pneumoniae serotype 19F IgG Ab [Mass/volume] in Serum |
| 741 | s-stpn2 | fmiau/ml | 11% | name+unit | 25 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 2 IgG Ab [Units/volume] in Serum |
| 742 | s-stpn2 | mg/l | 4% | name+unit | 8 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 2 IgG Ab [Mass/volume] in Serum |
| 743 | s-stpn2 | ug/mlgmc | 16% | name+unit | 37 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 2 IgG Ab [Mass/volume] in Serum |
| 744 | s-stpn2 |  | 69% | name | 155 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 2 IgG Ab [Mass/volume] in Serum |
| 745 | s-stpn20a | ug/mlgmc | 33% | name+unit | 40 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 20A IgG Ab [Mass/volume] in Serum |
| 746 | s-stpn20a |  | 67% | name | 83 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 20A IgG Ab [Mass/volume] in Serum |
| 747 | s-stpn23f | mg/l | 68% | name+unit+values | 497 | 0 | [0.05, 0.1, 0.19, 0.36, 0.54, 0.94, 1.71, 2.96, 8.89] |  | Serum |  | Streptococcus pneumoniae serotype 23F IgG Ab [Mass/volume] in Serum |
| 748 | s-stpn23f |  | 32% | name+values | 231 | 100 | [0.04, 0.09, 0.17, 0.32, 0.57, 0.88, 1.28, 2.06, 4.4] |  | Serum |  | Streptococcus pneumoniae serotype 23F IgG Ab [Mass/volume] in Serum |
| 749 | s-stpn33f | fmiau/ml | 10% | name+unit | 22 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 33F IgG Ab [Units/volume] in Serum |
| 750 | s-stpn33f | ug/mlgmc | 18% | name+unit | 39 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 33F IgG Ab [Mass/volume] in Serum |
| 751 | s-stpn33f |  | 72% | name | 155 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 33F IgG Ab [Mass/volume] in Serum |
| 752 | s-stpn4 | mg/l | 57% | name+unit+values | 415 | 0 | [0.06, 0.09, 0.14, 0.21, 0.31, 0.54, 0.86, 1.69, 3.39] |  | Serum |  | Streptococcus pneumoniae serotype 4 IgG Ab [Mass/volume] in Serum |
| 753 | s-stpn4 |  | 43% | name+values | 313 | 100 | [0.05, 0.09, 0.13, 0.2, 0.26, 0.4, 0.53, 1.4, 2.5] |  | Serum |  | Streptococcus pneumoniae serotype 4 IgG Ab [Mass/volume] in Serum |
| 754 | s-stpn5 | mg/l | 52% | name+unit+values | 381 | 0 | [0.08, 0.13, 0.24, 0.36, 0.53, 0.86, 1.47, 2.6, 5.55] |  | Serum |  | Streptococcus pneumoniae serotype 5 IgG Ab [Mass/volume] in Serum |
| 755 | s-stpn5 |  | 48% | name | 348 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 5 IgG Ab [Mass/volume] in Serum |
| 756 | s-stpn6b | mg/l | 61% | name+unit+values | 445 | 0 | [0.04, 0.07, 0.13, 0.24, 0.44, 0.85, 1.54, 2.66, 6.37] |  | Serum |  | Streptococcus pneumoniae serotype 6B IgG Ab [Mass/volume] in Serum |
| 757 | s-stpn6b |  | 39% | name+values | 283 | 100 | [0.04, 0.05, 0.08, 0.21, 0.34, 0.53, 0.91, 1.7, 3.5] |  | Serum |  | Streptococcus pneumoniae serotype 6B IgG Ab [Mass/volume] in Serum |
| 758 | s-stpn7f | mg/l | 70% | name+unit+values | 509 | 0 | [0.07, 0.15, 0.28, 0.51, 0.75, 1.27, 1.97, 2.94, 5.45] |  | Serum |  | Streptococcus pneumoniae serotype 7F IgG Ab [Mass/volume] in Serum |
| 759 | s-stpn7f |  | 30% | name+values | 220 | 100 | [0.07, 0.15, 0.21, 0.33, 0.62, 1.01, 1.83, 3.62, 5.52] |  | Serum |  | Streptococcus pneumoniae serotype 7F IgG Ab [Mass/volume] in Serum |
| 760 | s-stpn8 | fmiau/ml | 10% | name+unit | 22 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 8 IgG Ab [Units/volume] in Serum |
| 761 | s-stpn8 | mg/l | 3% | name+unit | 7 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 8 IgG Ab [Mass/volume] in Serum |
| 762 | s-stpn8 | ug/mlgmc | 18% | name+unit | 40 | 0 |  |  | Serum |  | Streptococcus pneumoniae serotype 8 IgG Ab [Mass/volume] in Serum |
| 763 | s-stpn8 |  | 69% | name | 155 | 100 |  |  | Serum |  | Streptococcus pneumoniae serotype 8 IgG Ab [Mass/volume] in Serum |
| 764 | s-stpn9v | mg/l | 63% | name+unit+values | 461 | 0 | [0.04, 0.07, 0.11, 0.18, 0.27, 0.44, 0.7, 1.43, 3.37] |  | Serum |  | Streptococcus pneumoniae serotype 9V IgG Ab [Mass/volume] in Serum |
| 765 | s-stpn9v |  | 37% | name+values | 267 | 100 | [0.04, 0.06, 0.12, 0.21, 0.38, 0.64, 1.09, 2.33, 4.2] |  | Serum |  | Streptococcus pneumoniae serotype 9V IgG Ab [Mass/volume] in Serum |

