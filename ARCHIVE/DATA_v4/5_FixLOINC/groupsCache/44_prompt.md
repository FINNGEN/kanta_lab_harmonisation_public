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
Here is group 44.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3005715 | Vancomycin [Mass/volume] in Serum or Plasma | 1.000 | 2009 |
| 3018954 | Choriogonadotropin [Presence] in Urine | 1.000 | 184 |
| 3023511 | Choriogonadotropin [Units/volume] in Urine | 1.000 |  |
| 3027974 | Hepatitis B virus e Ag [Presence] in Serum | 1.000 | 1108 |
| 3029075 | Extractable nuclear Ab panel - Serum | 1.000 |  |
| 3035510 | Gentamicin [Mass/volume] in Serum or Plasma | 1.000 | 1092 |
| 3036152 | Amikacin [Mass/volume] in Serum or Plasma | 1.000 |  |
| 3015916 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma | 0.981 |  |
| 3009306 | Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma | 0.977 | 386 |
| 3018171 | Choriogonadotropin [Units/volume] in Serum or Plasma | 0.971 | 252 |
| 3001686 | Cold agglutinin [Titer] in Serum or Plasma | 0.968 |  |
| 3052649 | Adenosine deaminase [Enzymatic activity/volume] in Serum or Plasma | 0.968 |  |
| 3013945 | Hepatitis B virus e Ab [Presence] in Serum | 0.966 |  |
| 3018308 | Bromide [Moles/volume] in Serum or Plasma | 0.964 |  |
| 3034780 | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum or Plasma | 0.963 | 730 |
| 3004248 | Sex hormone binding globulin [Moles/volume] in Serum or Plasma | 0.962 | 681 |
| 3009960 | Adenosine deaminase [Enzymatic activity/volume] in Blood | 0.953 |  |
| 3016724 | Homocysteine [Moles/volume] in Serum or Plasma | 0.952 | 358 |
| 3038575 | Hepatitis B virus e Ag [Presence] in Specimen | 0.950 |  |
| 3027505 | Alpha-1-Fetoprotein [Units/volume] in Amniotic fluid | 0.949 | 1501 |
| 3023378 | Hepatitis B virus e Ag [Presence] in Serum or Plasma by Immunoassay | 0.947 | 804 |
| 3014339 | Estrone (E1) [Moles/volume] in Serum or Plasma | 0.945 | 1123 |
| 3036335 | Angiotensin converting enzyme [Enzymatic activity/volume] in Blood | 0.943 | 1299 |
| 3046839 | Endomysium IgA Ab [Presence] in Serum by Immunofluorescence | 0.939 |  |
| 3010935 | Vancomycin [Moles/volume] in Serum or Plasma | 0.936 | 2009 |
| 3026531 | Cold agglutinin [Titer] in Serum or Plasma by Agglutination | 0.936 |  |
| 3009461 | 5-Hydroxyindoleacetate [Moles/time] in 24 hour Urine | 0.936 | 1449 |
| 3045958 | Alpha-1-Fetoprotein [Units/volume] in Body fluid | 0.936 |  |
| 3034165 | Alpha-1-Fetoprotein [Mass/volume] in Body fluid | 0.935 |  |
| 3010296 | Alpha-1-Fetoprotein [Mass/volume] in Amniotic fluid | 0.933 |  |
| 1989578 | Choriogonadotropin [Mass/volume] in Urine | 0.931 |  |
| 1091389 | Endomysium IgG Ab [Presence] in Serum by Immunofluorescence | 0.930 |  |
| 3010801 | 5-Hydroxyindoleacetate [Moles/volume] in 24 hour Urine | 0.930 |  |
| 3018680 | Endomysium Ab [Presence] in Serum by Immunofluorescence | 0.930 |  |
| 42529189 | Alpha-1-Fetoprotein [Units/volume] in Serum or Plasma by Immunoassay | 0.929 |  |
| 3027880 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma | 0.924 | 833 |
| 42529203 | Choriogonadotropin [Units/volume] in Serum or Plasma by Immunoassay | 0.924 |  |
| 46234929 | Hepatitis B virus e Ag [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.924 |  |
| 3022237 | Choriogonadotropin [Moles/volume] in Urine | 0.923 |  |
| 3036184 | Bromide [Moles/volume] in Blood | 0.923 |  |
| 3037123 | Amikacin [Mass/volume] in Serum or Plasma --trough | 0.923 |  |
| 3018920 | Vancomycin [Mass/volume] in Serum or Plasma --trough | 0.923 | 382 |
| 3053140 | Gentamicin [Moles/volume] in Serum or Plasma | 0.923 | 1092 |
| 3028050 | Streptolysin O Ab [Titer] in Serum | 0.922 | 1851 |
| 3026725 | Estradiol (E2) [Moles/volume] in Serum or Plasma | 0.922 | 231 |
| 3038911 | Alpha-1-fetoprotein.tumor marker [Units/volume] in Serum or Plasma | 0.921 |  |
| 3011724 | Hepatitis B virus e Ag [Presence] in Serum by Radioimmunoassay (RIA) | 0.921 |  |
| 3016254 | Gentamicin [Mass/volume] in Serum or Plasma --trough | 0.920 | 871 |
| 40759747 | Amikacin [Moles/volume] in Serum or Plasma | 0.920 |  |
| 3026383 | Bromide [Mass/volume] in Serum or Plasma | 0.919 |  |
| 3040941 | Hepatitis B virus e IgG Ab [Presence] in Serum | 0.919 |  |
| 1617524 | Alpha-1-Fetoprotein [Units/volume] in Aspirate | 0.919 |  |
| 3016103 | Fatty acids [Moles/volume] in Serum or Plasma | 0.918 |  |
| 3021236 | Streptolysin O Ab [Units/volume] in Serum or Plasma | 0.916 | 744 |
| 3016616 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in Serum or Plasma | 0.916 | 468 |
| 3039783 | Alpha-1-fetoprotein.tumor marker [Mass/volume] in Serum or Plasma | 0.915 | 746 |
| 3005886 | Vancomycin Free [Mass/volume] in Serum or Plasma | 0.913 |  |
| 646410 | Hepatitis B virus e Ag [Measurement] in Serum | 0.913 |  |
| 40757479 | Alpha-1-Fetoprotein [Mass/volume] in Cord blood | 0.910 |  |
| 3031166 | Choriogonadotropin [Mass/volume] in Serum or Plasma | 0.909 |  |
| 3021607 | Alpha-1-Fetoprotein [Moles/volume] in Serum or Plasma | 0.909 |  |
| 42529190 | Alpha-1-Fetoprotein [Mass/volume] in Serum or Plasma by Immunoassay | 0.909 |  |
| 1617106 | Alpha-1-Fetoprotein [Mass/volume] in Aspirate | 0.908 |  |
| 42529191 | Alpha-1-Fetoprotein [Units/volume] in Amniotic fluid by Immunoassay | 0.908 |  |
| 40759904 | Baker's yeast Ab [Units/volume] in Serum | 0.908 |  |
| 3036988 | Choriogonadotropin.intact [Units/volume] in Serum or Plasma | 0.907 | 834 |
| 646451 | Extractable nuclear Ab [Measurement] in Serum | 0.907 |  |
| 21492990 | Choriogonadotropin [Presence] in Urine by Rapid immunoassay | 0.907 |  |
| 3036806 | Hepatitis B virus e Ab [Presence] in Serum or Plasma by Immunoassay | 0.907 | 787 |
| 3030136 | 5-Hydroxyindoleacetate [Moles/volume] in Serum or Plasma | 0.905 |  |
| 3037437 | Adenosine deaminase [Enzymatic activity/volume] in Body fluid | 0.904 |  |
| 3011461 | Vancomycin [Mass/volume] in Serum or Plasma --peak | 0.904 | 937 |
| 3028755 | Hepatitis B virus e Ag [Titer] in Serum | 0.903 |  |
| 3011089 | Cold agglutinin [Titer] in Serum or Plasma by Cord RBC agglutination | 0.903 |  |
| 1175777 | Alpha-1-Fetoprotein Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.903 |  |
| 3009917 | Gentamicin [Mass/volume] in Serum or Plasma --peak | 0.903 | 965 |
| 3028331 | Alpha-1-Fetoprotein [Units/volume] in Pleural fluid | 0.902 |  |
| 3015171 | Extractable nuclear Ab [Units/volume] in Serum | 0.901 |  |
| 1616334 | Vancomycin [Mass/volume] in Serum or Plasma --2 hours post dose | 0.901 |  |
| 21494226 | Gentamicin free [Mass/volume] in Serum or Plasma | 0.901 |  |
| 3010554 | Cold agglutinin [Titer] in Serum or Plasma by Adult RBC Agglutination | 0.900 |  |
| 42868681 | Estrogen [Moles/volume] in Serum or Plasma | 0.899 | 920 |
| 3008080 | Adenosine monophosphate deaminase [Enzymatic activity/volume] in Serum | 0.899 |  |
| 3037522 | Nuclear Ab [Titer] in Serum | 0.899 | 890 |
| 3008977 | Amikacin [Mass/volume] in Serum or Plasma --peak | 0.899 |  |
| 3009417 | Choriogonadotropin.beta subunit [Presence] in Urine | 0.898 | 1227 |
| 3037641 | Choriogonadotropin [Units/volume] in Body fluid | 0.898 |  |
| 21494227 | Amikacin free [Mass/volume] in Serum or Plasma | 0.898 |  |
| 3016728 | Homocystine [Moles/volume] in Serum or Plasma | 0.898 |  |
| 3032506 | Alpha-1-Fetoprotein [Mass/volume] in Peritoneal fluid | 0.897 |  |
| 3013293 | Extractable nuclear Ab [Presence] in Serum | 0.896 |  |
| 648034 | Choriogonadotropin [Measurement] in Urine | 0.895 |  |
| 21492226 | Cold agglutinin [Titer] in Serum by 4 deg C incubation --1 hour post incubation | 0.895 |  |
| 3041244 | Adenosine deaminase [Enzymatic activity/volume] in Synovial fluid | 0.895 |  |
| 3002091 | Choriogonadotropin [Moles/volume] in Serum or Plasma | 0.893 |  |
| 3009471 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma | 0.893 |  |
| 3005148 | 5-Hydroxyindoleacetate [Mass/time] in 24 hour Urine | 0.892 |  |
| 3008692 | Estrone (E1) [Moles/volume] in Urine | 0.890 |  |
| 3035947 | Staphylolysin Ab [Units/volume] in Serum | 0.890 |  |
| 3023640 | Estrone (E1) [Mass/volume] in Serum or Plasma | 0.890 |  |
| 3007061 | Streptolysin O Ab [Units/volume] in Serum by Latex agglutination | 0.890 |  |
| 646220 | Cold agglutinin [Measurement] in Serum | 0.890 |  |
| 3004616 | Nuclear Ab [Presence] in Serum | 0.887 | 208 |
| 21492225 | Cold agglutinin [Titer] in Serum by 22 degree C incubation --1 hour post incubation | 0.887 |  |
| 40759128 | Platelet aggregation in Blood by arachidonate induced 500 ug/mL | 0.885 |  |
| 40758998 | Homocysteine [Moles/volume] in Body fluid | 0.885 |  |
| 40766122 | Extractable nuclear Ab [Presence] in Serum by Immunoassay | 0.885 |  |
| 40759269 | Smith extractable nuclear Ab and Ribonucleoprotein extractable nuclear Ab panel - Serum | 0.885 |  |
| 3036309 | 5-Hydroxyindoleacetate [Moles/volume] in Urine | 0.884 |  |
| 1176189 | Extractable nuclear antigen Ab.IgG panel - Serum | 0.883 |  |
| 21492227 | Cold agglutinin [Titer] in Serum by 4 deg C incubation --24 hour post incubation | 0.880 |  |
| 21492224 | Cold agglutinin [Titer] in Serum by 37 degree C incubation --1 hour post incubation | 0.879 |  |
| 3038136 | Choriogonadotropin.beta subunit [Units/volume] in Serum or Plasma | 0.879 | 364 |
| 3043496 | Extractable nuclear Ab [Interpretation] in Serum | 0.879 |  |
| 3005574 | Amikacin [Mass/volume] in Serum or Plasma --trough post extended interval dosing | 0.879 |  |
| 3023028 | 5-Hydroxyindoleacetate [Mass/volume] in 24 hour Urine | 0.878 |  |
| 3019258 | Amikacin [Mass/volume] in Body fluid | 0.877 |  |
| 3052820 | Kanamycin [Mass/volume] in Serum or Plasma | 0.874 |  |
| 3052507 | Netilmicin [Mass/volume] in Serum or Plasma | 0.874 |  |
| 3033818 | Extractable nuclear Ab [Units/volume] in Serum by Immunoassay | 0.873 |  |
| 3037585 | Homocysteine [Mass/volume] in Serum or Plasma | 0.873 | 1310 |
| 40762469 | Amikacin [Mass/volume] in Serum or Plasma --post dialysis | 0.873 |  |
| 3034552 | Adenosine deaminase [Enzymatic activity/volume] in Cerebral spinal fluid | 0.872 |  |
| 3017622 | Homocysteine [Moles/volume] in Urine | 0.872 |  |
| 3038038 | Choriogonadotropin [Units/volume] in Semen | 0.872 |  |
| 3036428 | Adenosine deaminase [Enzymatic activity/volume] in Pleural fluid | 0.872 |  |
| 3039257 | Vancomycin [Moles/volume] in Serum or Plasma --trough | 0.871 | 382 |
| 3035509 | Tobramycin [Mass/volume] in Serum or Plasma | 0.870 | 1858 |
| 3036065 | Streptolysin O Ab [Titer] in Serum by Latex agglutination | 0.870 |  |
| 3031814 | Bromide [Mass/volume] in Blood | 0.870 |  |
| 3005135 | Extractable nuclear Ab [Identifier] in Serum | 0.869 |  |
| 3016278 | Endomysium IgA Ab [Presence] in Serum | 0.869 | 547 |
| 3026429 | Gentamicin [Mass/volume] in Serum or Plasma --trough post extended interval dosing | 0.869 |  |
| 3011099 | Sex hormone binding globulin [Mass/volume] in Serum or Plasma | 0.869 |  |
| 3017915 | Endomysium Ab [Titer] in Serum by Immunofluorescence | 0.868 |  |
| 3037371 | Bromide [Moles/volume] in Urine | 0.868 |  |
| 40771477 | Baker's yeast Ab [Units/volume] in Serum by Immunoassay | 0.867 |  |
| 43055127 | Homocyst(e)ine [Moles/volume] in Serum or Plasma --fasting | 0.867 |  |
| 40762472 | Vancomycin [Mass/volume] in Serum or Plasma --post dialysis | 0.867 |  |
| 3002412 | Gentamicin [Moles/volume] in Serum or Plasma --trough | 0.866 | 871 |
| 3038624 | Choriogonadotropin.tumor marker [Units/volume] in Serum or Plasma | 0.866 |  |
| 3040662 | Nuclear Ab [Titer] in Serum by Immunoassay | 0.866 |  |
| 40769146 | Heparin unfractionated [Units/volume] in Platelet poor plasma | 0.866 |  |
| 648828 | Cold agglutinin [Measurement] in Serum or Plasma | 0.866 |  |
| 3015760 | Choriogonadotropin [Presence] in Body fluid | 0.864 |  |
| 3015128 | Streptolysin O Ab [Units/volume] in Body fluid | 0.864 |  |
| 3003191 | Choriogonadotropin [Presence] in Serum or Plasma | 0.863 | 615 |
| 3002225 | Fatty acids [Mass/volume] in Serum or Plasma | 0.863 |  |
| 3019583 | Endomysium IgA Ab [Titer] in Serum by Immunofluorescence | 0.863 | 976 |
| 3042164 | Endomysium IgG Ab [Presence] in Serum | 0.862 |  |
| 3044334 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in Urine | 0.862 |  |
| 3023122 | Fatty acids.very long chain [Moles/volume] in Serum or Plasma | 0.862 | 1826 |
| 3019257 | Choriogonadotropin.beta subunit [Moles/volume] in Urine | 0.862 |  |
| 3016906 | Vancomycin [Mass/volume] in Body fluid | 0.862 |  |
| 3021106 | 5-Hydroxyindoleacetate [Mass/volume] in Serum or Plasma | 0.862 |  |
| 3014854 | Endomysium Ab [Presence] in Serum | 0.862 |  |
| 40760543 | Extractable nuclear Ab [Presence] in Serum by Immunoblot | 0.861 |  |
| 3045452 | LMW Heparin [Units/volume] in Platelet poor plasma | 0.861 |  |
| 3045218 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Urine | 0.861 |  |
| 40758603 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma --baseline | 0.859 |  |
| 3029213 | Adenosine deaminase [Enzymatic activity/volume] in Pericardial fluid | 0.859 |  |
| 3044606 | Estradiol (E2) [Moles/volume] in Urine | 0.859 |  |
| 3051403 | 5-Hydroxyindoleacetate [Moles/volume] in Cerebral spinal fluid | 0.859 |  |
| 3038531 | Vancomycin [Moles/volume] in Serum or Plasma --peak | 0.858 | 937 |
| 42529214 | Estradiol (E2) [Moles/volume] in Serum or Plasma by Immunoassay | 0.858 |  |
| 3002971 | Nuclear Ab [Titer] in Serum by Immunofluorescence | 0.857 | 345 |
| 3045479 | Estrone (E1) [Moles/volume] in 24 hour Urine | 0.856 |  |
| 3012631 | Estriol (E3) [Moles/volume] in Serum or Plasma | 0.856 | 1565 |
| 3021133 | Inter alpha trypsin inhibitor [Mass/volume] in Serum | 0.856 |  |
| 3045640 | Choriogonadotropin [Units/volume] in Amniotic fluid | 0.856 |  |
| 40758605 | Estradiol (E2) [Moles/volume] in Serum or Plasma --baseline | 0.855 |  |
| 3045688 | Homocysteine cysteine disulfide [Moles/volume] in Serum or Plasma | 0.855 |  |
| 3027536 | Estrone sulfate [Mass/volume] in Serum or Plasma | 0.854 |  |
| 3033252 | Adenosine deaminase [Enzymatic activity/volume] in Peritoneal fluid | 0.854 |  |
| 3029103 | Nuclear Ab [Presence] in Serum by Immunofluorescence | 0.852 |  |
| 3008092 | Baker's yeast IgG Ab [Units/volume] in Serum | 0.852 |  |
| 40759126 | Platelet aggregation in Blood by ADP induced 5 umol/L | 0.852 |  |
| 3045127 | Homocystine Free [Moles/volume] in Serum or Plasma | 0.851 |  |
| 40758979 | Estradiol (E2) [Moles/volume] in Body fluid | 0.850 |  |
| 21492815 | Adenosine deaminase [Enzymatic activity/mass] in Leukocytes | 0.850 |  |
| 3039041 | Endomysium IgG Ab [Titer] in Serum by Immunofluorescence | 0.850 |  |
| 3046071 | Choriogonadotropin.intact+Beta subunit [Units/volume] in Serum or Plasma | 0.850 |  |
| 43534046 | Estradiol (E2) [Moles/volume] in Serum or Plasma by High sensitivity method | 0.849 |  |
| 3037275 | Staphylococcus aureus Ab [Units/volume] in Serum | 0.849 |  |
| 648716 | Choriogonadotropin [Measurement] in Serum or Plasma | 0.849 |  |
| 3005831 | Streptolysin O Ab [Units/volume] in Synovial fluid | 0.846 |  |
| 3040491 | Angiotensin converting enzyme [Enzymatic activity/volume] in Pleural fluid | 0.845 |  |
| 3002924 | Fatty acids.nonesterified [Mass/volume] in Serum or Plasma | 0.845 |  |
| 40759134 | Platelet aggregation in Blood by arachidonate induced ATP secretion 500 umol/L | 0.845 |  |
| 3022000 | Dehydroepiandrosterone (DHEA) [Mass/volume] in Serum or Plasma | 0.845 |  |
| 3039445 | 5-Hydroxytryptophan [Moles/volume] in 24 hour Urine | 0.843 |  |
| 3017071 | Smith extractable nuclear Ab [Titer] in Serum | 0.843 |  |
| 3011339 | Nuclear IgG Ab [Presence] in Serum | 0.842 |  |
| 3032897 | Saturated fatty acids [Moles/volume] in Serum or Plasma | 0.842 |  |
| 40759127 | Platelet aggregation in Blood by ADP induced 10 umol/L | 0.841 |  |
| 3009623 | Estrone (E1).unconjugated [Mass/volume] in Serum or Plasma | 0.841 |  |
| 3024856 | Heparin unfractionated [Units/volume] in Platelet poor plasma by Coagulation assay | 0.841 |  |
| 3026837 | Homocystine [Moles/volume] in Specimen | 0.840 |  |
| 3046268 | Streptolysin O Ab [Mass/volume] in Serum | 0.840 |  |
| 3025285 | Estradiol (E2) [Mass/volume] in Serum or Plasma | 0.840 |  |
| 3029054 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --5th specimen fasting | 0.839 |  |
| 3015884 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma | 0.839 |  |
| 40758999 | Homocysteine [Moles/volume] in 24 hour Urine | 0.839 |  |
| 3032218 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --3rd specimen fasting | 0.838 |  |
| 3008085 | Endomysium Ab [Units/volume] in Serum by Immunofluorescence | 0.838 |  |
| 3009991 | Angiotensin converting enzyme [Enzymatic activity/volume] in Cerebral spinal fluid | 0.838 |  |
| 40761580 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --6th specimen fasting | 0.837 |  |
| 646971 | Smith extractable nuclear Ab [Measurement] in Serum | 0.837 |  |
| 3017596 | Platelet aggregation in Platelet rich plasma by arachidonate induced | 0.837 |  |
| 3036168 | 5-Hydroxyindoleacetate [Presence] in 24 hour Urine | 0.837 |  |
| 3023428 | Smith extractable nuclear Ab [Presence] in Serum | 0.836 |  |
| 647790 | Streptolysin O Ab [Measurement] in Serum | 0.835 |  |
| 3039998 | Platelet aggregation [Units/volume] in Blood by arachidonate induced | 0.835 |  |
| 3050002 | Nuclear Ab [Presence] in Serum by Immunoassay | 0.835 | 1546 |
| 3021385 | 5-Hydroxyindoleacetate [Mass/volume] in Urine | 0.835 |  |
| 40759782 | 5-Hydroxytryptophan [Moles/time] in 24 hour Urine | 0.834 |  |
| 40761579 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --7th specimen fasting | 0.834 |  |
| 648952 | Baker's yeast Ab [Measurement] in Serum | 0.833 |  |
| 3003099 | Streptolysin O Ab [Units/volume] in Serum --1st specimen | 0.831 |  |
| 21494067 | Heparin unfractionated [Units/volume] in Blood by Heparin protamine titration | 0.831 |  |
| 3039179 | Angiotensin converting enzyme [Enzymatic activity/volume] in Peritoneal fluid | 0.831 |  |
| 1092039 | Platelet aggregation in Plasma by arachidonate induced 1 umol/L | 0.828 |  |
| 3019320 | Dehydroepiandrosterone (DHEA) [Moles/volume] in 24 hour Urine | 0.828 |  |
| 3024445 | Bromide [Mass/volume] in Specimen | 0.828 |  |
| 3021636 | Estrone (E1) [Mass/volume] in Urine | 0.827 |  |
| 3035369 | Rheumatoid arthritis nuclear Ab [Presence] in Serum | 0.827 |  |
| 3025684 | Heparin unfractionated [Units/volume] in Platelet poor plasma by Chromogenic method | 0.825 |  |
| 40768055 | Sex hormone binding globulin [Moles/volume] in Serum or Plasma --pre or post XXX challenge | 0.825 |  |
| 3049738 | Baker's yeast IgG Ab [Units/volume] in Serum by Immunoassay | 0.825 |  |
| 3004593 | Baker's yeast IgA Ab [Units/volume] in Serum | 0.823 | 1368 |
| 3007957 | LMW Heparin [Units/volume] in Platelet poor plasma by Coagulation assay | 0.823 |  |
| 3051057 | 5-Hydroxyindoleacetate/Creatinine [Molar ratio] in 24 hour Urine | 0.823 |  |
| 3047826 | Mullerian inhibiting substance [Mass/volume] in Serum or Plasma | 0.821 | 1599 |
| 3014670 | 5-Hydroxyindoleacetate [Mass/volume] in Cerebral spinal fluid | 0.821 |  |
| 3044342 | Dehydroepiandrosterone sulfate (DHEA-S) [Moles/volume] in 24 hour Urine | 0.821 |  |
| 3012673 | Bromide [Mass/volume] in Urine | 0.819 |  |
| 3042234 | Platelet aggregation [Units/volume] in Blood by ADP induced | 0.817 |  |
| 3048833 | Staphylolysin Ab [Units/volume] in Body fluid | 0.816 |  |
| 3015881 | Streptolysin O Ab [Units/volume] in Serum --2nd specimen | 0.816 |  |
| 21491008 | Platelet aggregation in Platelet rich plasma by arachidonate induced 1.6 mmol/L | 0.816 |  |
| 3038629 | Platelet aggregation in Platelet rich plasma by arachidonate induced 500 ug/mL | 0.816 |  |
| 3030077 | Nuclear Ab [Titer] in Serum by Hep2 substrate | 0.815 |  |
| 3044096 | 5-Hydroxyindoleacetate panel - 24 hour Urine | 0.815 |  |
| 3037035 | Baker's yeast IgG Ab [Mass/volume] in Serum | 0.814 | 1311 |
| 3051055 | Staphylolysin Ab [Titer] in Serum | 0.814 |  |
| 3007104 | Heparinoid [Units/volume] in Platelet poor plasma by Chromogenic method | 0.814 |  |
| 3018358 | Nuclear Ab [Titer] in Body fluid | 0.813 |  |
| 3011407 | Baker's yeast IgE Ab [Units/volume] in Serum | 0.812 | 1945 |
| 3025563 | Saccharopolyspora rectivirgula Ab [Units/volume] in Serum | 0.812 |  |
| 40758972 | Androstenediol [Moles/volume] in Serum or Plasma | 0.812 |  |
| 3052277 | 11-Hydroxyandrostenedione [Moles/volume] in Serum or Plasma | 0.812 |  |
| 3021195 | Candida albicans Ab [Units/volume] in Serum | 0.811 |  |
| 3017055 | Platelet aggregation in Platelet rich plasma by ADP induced | 0.811 |  |
| 3052047 | Heparin IgE Ab [Units/volume] in Serum | 0.811 |  |
| 3025879 | Neuronal nuclear Ab [Presence] in Serum | 0.810 |  |
| 3002118 | Nuclear IgG Ab [Presence] in Serum by Immunoassay | 0.810 |  |
| 3001440 | Nuclear IgG Ab [Presence] in Serum by Immunofluorescence | 0.808 |  |
| 1259621 | Platelet aggregation in Blood by ADP induced ATP secretion 2 umol/L | 0.808 |  |
| 3028919 | Platelet aggregation in Control Platelet rich plasma by arachidonate induced | 0.807 |  |
| 40758604 | Dehydroepiandrosterone (DHEA) [Moles/volume] in Serum or Plasma --1 hour post dose corticotropin | 0.807 |  |
| 40759753 | Nuclear IgG Ab [Titer] in Serum by Immunofluorescence | 0.806 |  |
| 40759123 | Platelet aggregation in Blood by ADP induced ATP secretion 5 umol/L | 0.806 |  |
| 40759132 | Platelet aggregation in Blood by ADP induced ATP secretion 10 umol/L | 0.806 |  |
| 3038049 | Nucleolar nuclear Ab pattern [Titer] in Serum | 0.804 | 513 |
| 40758465 | N Ab [Titer] in Serum or Plasma | 0.804 |  |
| 44816667 | 5-Hydroxyindoleacetate [Moles/volume] in Platelet rich plasma | 0.803 |  |
| 3026712 | Neutrophil cytoplasmic Ab [Titer] in Serum | 0.803 | 1456 |
| 3003927 | Nuclear Ab [Titer] in Synovial fluid | 0.802 |  |
| 3000481 | Estrogen+Progesterone receptor Ag [Presence] in Tissue by Immune stain | 0.802 |  |
| 3018337 | Streptolysin O Ab [Presence] in Serum | 0.801 |  |
| 3012343 | Heparin anti Xa [Units/volume] in Nonbiological fluid | 0.799 |  |
| 3036566 | Thyroxine binding globulin [Moles/volume] in Serum or Plasma | 0.796 |  |
| 3009400 | Neuronal nuclear Ab [Titer] in Serum | 0.795 |  |
| 3006792 | LMW Heparin [Units/volume] in Platelet poor plasma by Chromogenic method | 0.794 |  |
| 3001740 | Acetylcholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.792 |  |
| 3008541 | Platelet aggregation interpretation in Platelet rich plasma Qualitative Induced by Arachidonate | 0.791 |  |
| 3043429 | Thyroperoxidase Ab [Titer] in Serum or Plasma | 0.791 | 1613 |
| 40759672 | Dehydroepiandrosterone sulfate (DHEA-S) [Mass/volume] in Serum or Plasma --baseline | 0.790 |  |
| 646250 | Bromide [Measurement] in Urine | 0.789 |  |
| 40758310 | Human epididymis protein 4 [Moles/volume] in Serum or Plasma | 0.788 |  |
| 36660109 | Platelet aggregation in Platelet rich plasma by ADP induced 1.2 umol/L | 0.787 |  |
| 42529221 | Mullerian inhibiting substance [Mass/volume] in Serum or Plasma by Immunoassay | 0.786 |  |
| 3010312 | Streptococcus sp Ab [Titer] in Serum | 0.786 |  |
| 3049189 | Streptococcus sp exoenzyme Ab [Units/volume] in Serum | 0.785 |  |
| 3049799 | Mullerian inhibiting substance [Moles/volume] in Serum or Plasma | 0.784 |  |
| 3038915 | Platelet aggregation in Platelet rich plasma by ADP induced 20 umol/mL | 0.783 |  |
| 40759133 | Platelet aggregation interpretation in Blood Qualitative by Arachidonate induced ATP secretion.500 umol/L | 0.780 |  |
| 3022795 | Bromazepam [Moles/volume] in Serum or Plasma | 0.779 |  |
| 3009059 | Enolase [Enzymatic activity/volume] in Serum | 0.778 |  |
| 36032285 | Pregnenolone sulfate [Mass/volume] in Serum or Plasma | 0.778 |  |
| 40758655 | Brompheniramine [Moles/volume] in Serum or Plasma | 0.777 |  |
| 3018595 | Inhibin A [Mass/volume] in Serum or Plasma | 0.774 | 702 |
| 3010866 | Cholinesterase [Enzymatic activity/volume] in Serum or Plasma | 0.774 |  |
| 3030073 | Trypsin [Mass/volume] in Serum or Plasma | 0.769 |  |
| 1091624 | Hereditary angioedema multigene analysis in Blood by Molecular genetics method | 0.768 |  |
| 3007808 | Renin [Enzymatic activity/volume] in Plasma | 0.768 | 822 |
| 21491244 | Platelet aggregation [Units/volume] in Blood by adenosine diphosphate+prostaglandin E1 induced | 0.763 |  |
| 3010578 | Choriomammotropin [Mass/volume] in Serum | 0.759 |  |
| 3006791 | Alpha naphthylesterase [Enzymatic activity/volume] in Serum | 0.759 |  |
| 42529222 | Mullerian inhibiting substance [Moles/volume] in Serum or Plasma by Immunoassay | 0.758 |  |
| 645118 | Mullerian inhibiting substance [Measurement] in Serum or Plasma | 0.756 |  |
| 3017446 | Testosterone [Moles/volume] in Serum or Plasma | 0.756 | 203 |
| 3012620 | Inhibin [Mass/volume] in Serum or Plasma | 0.756 |  |
| 21491003 | Platelet aggregation in Platelet rich plasma by ADP induced 2.5 umol/L | 0.752 |  |
| 3045781 | Inhibin B [Mass/volume] in Serum or Plasma | 0.752 |  |
| 3021925 | Trypsin+Trypsinogen [Mass/volume] in Serum or Plasma | 0.750 |  |
| 3043105 | HER2 Ag [Mass/volume] in Serum | 0.746 |  |
| 3003289 | Progesterone receptor [Interpretation] in Tissue | 0.743 |  |
| 3035828 | Inhibin A [Multiple of the median] in Serum or Plasma | 0.742 |  |
| 3023763 | Trypsinogen [Mass/volume] in Serum or Plasma | 0.741 |  |
| 3025283 | Somatotropin binding protein [Moles/volume] in Serum or Plasma | 0.739 |  |
| 3004390 | Estrogen receptor [Interpretation] in Tissue | 0.738 |  |
| 36031680 | Human epididymis protein 4 [Mass/volume] in Serum or Plasma | 0.736 |  |
| 3041343 | Estrogen receptor Ag [Presence] in Tissue by Immune stain | 0.733 |  |
| 3020924 | Thyroxine binding globulin [Mass/volume] in Serum or Plasma | 0.731 |  |
| 44786758 | Tissue inhibitor of metalloproteinases 1 [Mass/volume] in Serum or Plasma by Immunoassay | 0.730 |  |
| 3000275 | Trypsinogen I Free [Mass/volume] in Serum or Plasma | 0.717 |  |
| 3042818 | Melanoma inhibitory activity protein [Mass/volume] in Serum or Plasma | 0.716 |  |
| 3042084 | Tryptase [Moles/volume] in Serum or Plasma | 0.712 |  |
| 3050153 | Food allergen panel - Serum | 0.710 |  |
| 3013770 | Testosterone [Mass/volume] adjusted for sex hormone binding globulin in Serum or Plasma | 0.710 |  |
| 3016794 | Cells.estrogen receptor/100 cells in Tissue by Immune stain | 0.710 |  |
| 3037704 | Thyroxine binding globulin [Mass/volume] in Blood | 0.710 |  |
| 3024028 | Trypsin [Enzymatic activity/volume] in Serum or Plasma | 0.708 |  |
| 3003489 | Gonadotropin releasing hormone [Moles/volume] in Serum or Plasma | 0.708 |  |
| 3022156 | Cells.progesterone receptor/100 cells in Tissue by Immune stain | 0.705 |  |
| 3019420 | Tryptase [Mass/volume] in Serum or Plasma | 0.704 | 1562 |
| 647003 | HER2 Ag [Measurement] in Serum | 0.704 |  |
| 3031549 | HER2 Ag [Mass/volume] in Serum by Immunoassay | 0.702 |  |
| 21491058 | 4-Hydroxyvalerate [Moles/volume] in Serum or Plasma | 0.702 |  |
| 3002776 | Chymotrypsin [Mass/volume] in Serum or Plasma | 0.700 |  |
| 3033670 | Parathyrin related protein [Moles/volume] in Serum or Plasma | 0.697 |  |
| 40757296 | Tumor necrosis factor binding protein [Units/volume] in Serum | 0.696 |  |
| 3041608 | Progesterone receptor Ag [Presence] in Tissue by Immune stain | 0.694 |  |
| 40771562 | Chronic urticaria index panel - Serum or Plasma | 0.693 |  |
| 36203156 | Cells.progesterone receptor/100 cells in Breast cancer specimen by Immune stain | 0.689 |  |
| 3965002 | Hereditary sensory and autonomic neuropathy type 1 panel - Serum by LC/MS/MS | 0.689 |  |
| 46234766 | Alpha 1 antitrypsin [Moles/volume] in Serum or Plasma | 0.687 |  |
| 3045759 | Histamine [Moles/volume] in Serum or Plasma | 0.686 |  |
| 3051091 | 3-Hydroxyvalerate [Moles/volume] in Plasma | 0.685 |  |
| 3030860 | Tumor necrosis factor.alpha [Moles/volume] in Serum or Plasma | 0.685 |  |
| 42870325 | Hepcidin 25 amino acid peptide [Moles/volume] in Serum or Plasma | 0.681 |  |
| 40766216 | Nut allergen panel - Serum | 0.677 |  |
| 36031523 | Indoor respiratory allergen IgE panel - Serum | 0.675 |  |
| 43534081 | HNA genotype panel - Serum or Plasma | 0.673 |  |
| 3024228 | EPINEPHrine [Moles/volume] in Plasma | 0.673 |  |
| 3041250 | Core respiratory allergens panel - Serum | 0.670 |  |
| 36304449 | IgA, IgA1 and IgA2 panel - Serum or Plasma | 0.661 |  |
| 1092321 | Egg White IgE Panel - Serum | 0.659 |  |
| 1002111 | Dermatan sulfate and heparan sulfate and keratan sulfate panel - Serum or Plasma | 0.644 |  |
| 44786995 | Cryoglobulin and cryofibrinogen panel - Serum and Plasma | 0.641 |  |
| 3048571 | Activated protein C resistance panel - Platelet poor plasma | 0.641 |  |
| 43533700 | Adenosine triphosphate/Adenosine diphosphate [Entitic molar ratio] in Platelets | 0.640 |  |
| 1091832 | Egg Comprehensive IgE Ab panel - Serum or Plasma | 0.640 |  |
| 3010564 | Serotonin [Mass/volume] in Platelets | 0.606 |  |
| 3036193 | Monoamine oxidase [Enzymatic activity/volume] in Platelet rich plasma | 0.601 |  |
| 3032078 | Adenosine triphosphate/Adenosine diphosphate [Mass Ratio] in Blood | 0.600 |  |
| 3050758 | Platelet aggregation [Units/volume] in Platelet rich plasma by arachidonate induced | 0.596 |  |
| 3048603 | Platelet aggregation [Units/volume] in Platelet rich plasma by ADP induced | 0.595 |  |
| 3039417 | Platelet distribution width [Ratio] in Blood | 0.592 |  |
| 21493869 | von Willebrand factor (vWf) ristocetin cofactor/von Willebrand factor (vWf) Ag [Ratio] in Platelet poor plasma | 0.590 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | value_missing_p | value_deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 583 | -ana | titre | 11% | name+unit | 21 | 0 |  | -Tuma, vasta-aineet |  |  | Antinuclear Ab [Titer] in Serum or Plasma |
| 584 | -ana |  | 89% | name | 169 | 100 |  | -Tuma, vasta-aineet |  |  | Antinuclear Ab [Presence] in Serum or Plasma |
| 585 | b-adp | auc | 8% | name+unit | 28 | 0 |  |  | Blood |  | Platelet aggregation.ADP induced [Area under curve] in Blood |
| 586 | b-adp |  | 92% | name | 340 | 100 |  |  | Blood |  | Platelet aggregation.ADP induced in Blood |
| 587 | b-aspi | auc | 8% | name+unit | 28 | 0 |  |  | Blood |  | Platelet aggregation.Arachidonate induced [Area under curve] in Blood |
| 588 | b-aspi |  | 92% | name | 340 | 100 |  |  | Blood |  | Platelet aggregation.Arachidonate induced in Blood |
| 589 | b-vasp | % | 71% | name+unit+values | 165 | 0.61 | [15.75, 23.9, 29.38, 35.29, 42.07, 50.51, 57, 61.68, 75.5] |  | Blood |  | Vasodilator-stimulated phosphoprotein phosphorylation [Ratio] in Platelets |
| 590 | b-vasp |  | 29% | name | 67 | 100 |  |  | Blood |  | Vasodilator-stimulated phosphoprotein phosphorylation [Ratio] in Platelets |
| 591 | du-5hiaa | umol | 49% | name+unit+values | 332 | 0 | [14.84, 17.93, 19.97, 21.95, 24.09, 26.9, 29.86, 35.62, 54.61] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine |
| 592 | du-5hiaa | umol/24h | 26% | name+unit+values | 175 | 0 | [12.52, 16.28, 19.6, 22.92, 25.58, 30.54, 36.9, 47, 66.84] | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine |
| 593 | du-5hiaa | umol/l | 4% | name+unit | 25 | 0 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | Hydroxyindoleacetic acid [Moles/volume] in 24 hour Urine |
| 594 | du-5hiaa |  | 22% | name | 147 | 100 |  | dU-Hydroksi-indolyyliasetaatti (5-) | 24-hour urine |  | Hydroxyindoleacetic acid [Moles/time] in 24 hour Urine |
| 595 | fs-ace | u/l | 91% | name+unit+values | 33401 | 0 | [20.01, 26.72, 31.85, 36.77, 41.74, 47.12, 53.86, 62.72, 77.07] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum |
| 596 | fs-ace |  | 9% | name+values | 3291 | 100 | [11.74, 22.42, 28.98, 33.88, 39.56, 44.46, 50.35, 61.63, 75.64] | fS-Angiotensiini-1-konvertaasi | Fasting serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum |
| 597 | fs-ffa | mmol/l | 90% | name+unit+values | 170 | 0.59 | [0.18, 0.25, 0.3, 0.38, 0.42, 0.5, 0.56, 0.69, 0.9] | fS-Rasvahapot, vapaat | Fasting serum |  | Fatty acids.free [Moles/volume] in Serum |
| 598 | fs-ffa |  | 10% | name | 19 | 100 |  | fS-Rasvahapot, vapaat | Fasting serum |  | Fatty acids.free [Moles/volume] in Serum |
| 599 | p-hae |  | 100% | name | 461 | 100 |  |  | Plasma |  | Hereditary angioedema panel - Plasma |
| 600 | p-hcg | iu/l | 3% | name+unit+values | 858 | 0 | [3.48, 10.49, 27.21, 71.9, 194.98, 530.06, 1481.95, 5270.49, 17544.85] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Units/volume] in Plasma |
| 601 | p-hcg | u/l | 45% | name+unit+values | 13156 | 0 | [0, 1.47, 5, 22.74, 99.28, 332.77, 1072.06, 3554.69, 18400.55] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Units/volume] in Plasma |
| 602 | p-hcg |  | 52% | name+values | 15471 | 100 | [2.3, 12.1, 34.61, 97.94, 275.98, 842.13, 2833.73, 7394.19, 31975.3] | P -Koriongonadotropiini | Plasma |  | Choriogonadotropin [Units/volume] in Plasma |
| 603 | p-he4 | pmol/l | 100% | name+unit+values | 2505 | 0 | [38.56, 42.77, 46.8, 51.21, 56.04, 62.65, 72.66, 92.27, 148.13] | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  | HE4 protein [Moles/volume] in Plasma |
| 604 | p-he4 |  | 0% | name | 6 | 100 |  | P -Epididymaalinen antigeeni 4 (HE4) | Plasma |  | HE4 protein [Moles/volume] in Plasma |
| 605 | p-hepg |  | 100% | name | 107 | 100 |  |  | Plasma |  | Heparin [Units/volume] in Plasma |
| 606 | p-hok |  | 100% | name | 397 | 100 |  |  | Plasma |  | Homocysteine [Moles/volume] in Plasma |
| 607 | p-shbg | nmol/l | 51% | name+unit+values | 791 | 0 | [18.05, 23.19, 26.53, 30.08, 34.17, 38.11, 43.33, 50.43, 63.58] |  | Plasma |  | Sex hormone binding globulin [Moles/volume] in Plasma |
| 608 | p-shbg |  | 49% | name+values | 758 | 100 | [17.44, 21.87, 26.42, 30.98, 35.64, 41.79, 47.18, 56.49, 73.47] |  | Plasma |  | Sex hormone binding globulin [Moles/volume] in Plasma |
| 609 | s-5hiaa | nmol/l | 99% | name+unit+values | 10313 | 0 | [44.24, 52.84, 60.81, 69.7, 80.24, 95.18, 123.37, 200.27, 541.18] | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  | Hydroxyindoleacetic acid [Moles/volume] in Serum |
| 610 | s-5hiaa |  | 1% | name | 153 | 100 |  | S-Hydroksi-indolyyliasetaatti (5-) | Serum |  | Hydroxyindoleacetic acid [Moles/volume] in Serum |
| 611 | s-ace | u/l | 74% | name+unit+values | 2203 | 0 | [19.71, 28.37, 33.66, 38.43, 43.04, 48.17, 53.91, 61.65, 75.1] |  | Serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum |
| 612 | s-ace |  | 26% | name+values | 769 | 100 | [21.46, 30.53, 35.19, 38.74, 43.02, 46.74, 52.18, 58.12, 66.5] |  | Serum |  | Angiotensin converting enzyme [Enzymatic activity/volume] in Serum |
| 613 | s-ada | u/l | 94% | name+unit+values | 4147 | 0 | [7, 8.11, 9.17, 10.37, 11.58, 13.01, 14.79, 17.22, 21.44] | S -Adenosiinideaminaasi | Serum |  | Adenosine deaminase [Enzymatic activity/volume] in Serum |
| 614 | s-ada |  | 6% | name | 259 | 100 |  | S -Adenosiinideaminaasi | Serum |  | Adenosine deaminase [Enzymatic activity/volume] in Serum |
| 615 | s-afp | u/ml | 74% | name+unit+values | 18186 | 0.02 | [1.8, 2.09, 2.61, 3.01, 3.61, 4.34, 5.57, 7.78, 25.89] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-Fetoprotein [Units/volume] in Serum |
| 616 | s-afp | ug/l | 10% | name+unit+values | 2515 | 0.2 | [2, 2.19, 3, 3.92, 4.18, 5.4, 6.88, 9.63, 20.48] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-Fetoprotein [Mass/volume] in Serum |
| 617 | s-afp |  | 16% | name+values | 4026 | 100 | [2, 2.04, 3, 3.01, 3.97, 4, 5, 6.37, 9.78] | S -Alfa-1-fetoproteiini | Serum |  | Alpha-1-Fetoprotein [Units/volume] in Serum |
| 618 | s-afp/d | u/ml | 83% | name+unit+values | 234 | 0 | [15.07, 17.36, 19.66, 21.92, 23.81, 26.18, 29.19, 33.19, 39.28] |  | Serum |  | Alpha-1-Fetoprotein [Units/volume] in Serum |
| 619 | s-afp/d |  | 17% | name | 49 | 100 |  |  | Serum |  | Alpha-1-Fetoprotein [Units/volume] in Serum |
| 620 | s-amh | ug/l | 88% | name+unit+values | 9545 | 0 | [0.41, 0.85, 1.31, 1.76, 2.25, 2.87, 3.65, 4.79, 7.19] | S -Anti-Muller hormoni | Serum |  | Anti-Mullerian hormone [Mass/volume] in Serum |
| 621 | s-amh |  | 12% | name+values | 1328 | 100 | [0.75, 1.12, 1.6, 2, 2.6, 3.25, 3.89, 5.15, 6.81] | S -Anti-Muller hormoni | Serum |  | Anti-Mullerian hormone [Mass/volume] in Serum |
| 622 | s-ami | mg/l | 49% | name+unit+values | 294 | 0 | [1.26, 1.45, 1.68, 2.02, 2.66, 3.31, 4.38, 6.23, 11.11] | S -Amikasiini | Serum |  | Amikacin [Mass/volume] in Serum or Plasma |
| 623 | s-ami |  | 51% | name | 308 | 100 |  | S -Amikasiini | Serum |  | Amikacin [Mass/volume] in Serum or Plasma |
| 624 | s-ana | titre | 26% | name+unit+values | 21493 | 0 | [80, 159.91, 214.87, 320, 320, 320, 522.82, 1051.43, 1384.04] | S -Tuma, vasta-aineet | Serum |  | Antinuclear Ab [Titer] in Serum |
| 625 | s-ana |  | 74% | name | 62781 | 100 |  | S -Tuma, vasta-aineet | Serum |  | Antinuclear Ab [Presence] in Serum |
| 626 | s-asca | u/ml | 22% | name+unit | 89 | 0 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  | Saccharomyces cerevisiae Ab [Units/volume] in Serum |
| 627 | s-asca |  | 78% | name | 316 | 100 |  | S -Saccharomyces cerevisiae, vasta-aineet | Serum |  | Saccharomyces cerevisiae Ab [Units/volume] in Serum |
| 628 | s-ast | iu/ml | 44% | name+unit+values | 2404 | 0 | [53.94, 68.05, 79.53, 94.83, 113.69, 141.82, 180.88, 246.57, 415.18] | S -Antistreptolysiini | Serum |  | Antistreptolysin O Ab [Units/volume] in Serum |
| 629 | s-ast | titre | 0% | name+unit | 7 | 0 |  | S -Antistreptolysiini | Serum |  | Antistreptolysin O Ab [Titer] in Serum |
| 630 | s-ast | u/ml | 8% | name+unit+values | 408 | 0 | [30.69, 40.68, 53.25, 70.32, 94.82, 134.06, 198.84, 380.5, 767.49] | S -Antistreptolysiini | Serum |  | Antistreptolysin O Ab [Units/volume] in Serum |
| 631 | s-ast |  | 48% | name+values | 2603 | 100 | [61.25, 72.75, 89.71, 105.94, 136, 193.17, 248, 404.5, 714.67] | S -Antistreptolysiini | Serum |  | Antistreptolysin O Ab [Units/volume] in Serum |
| 632 | s-asta | iu/ml | 10% | name+unit+values | 256 | 0 | [2, 2, 2, 2, 3, 4, 4.2, 6, 8] | S -Antistafylolysiini | Serum |  | Antistaphylolysin Ab [Units/volume] in Serum |
| 633 | s-asta | u/ml | 0% | name+unit | 10 | 0 |  | S -Antistafylolysiini | Serum |  | Antistaphylolysin Ab [Units/volume] in Serum |
| 634 | s-asta |  | 89% | name | 2266 | 100 |  | S -Antistafylolysiini | Serum |  | Antistaphylolysin Ab [Units/volume] in Serum |
| 635 | s-br | mmol/l | 100% | name+unit | 130 | 2.31 |  | S -Bromidi | Serum |  | Bromide [Moles/volume] in Serum |
| 636 | s-dhea | nmol/l | 84% | name+unit+values | 398 | 0 | [2.51, 3.94, 5.32, 7.57, 10.22, 13.71, 18.17, 23.83, 35.37] | S -Dehydroepiandrosteroni | Serum |  | Dehydroepiandrosterone [Moles/volume] in Serum |
| 637 | s-dhea |  | 16% | name | 74 | 100 |  | S -Dehydroepiandrosteroni | Serum |  | Dehydroepiandrosterone [Moles/volume] in Serum |
| 638 | s-dheas | umol/l | 92% | name+unit+values | 3797 | 0 | [1.08, 1.91, 2.83, 3.72, 4.53, 5.45, 6.59, 8, 10.09] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  | Dehydroepiandrosterone sulfate [Moles/volume] in Serum |
| 639 | s-dheas |  | 8% | name+values | 331 | 100 | [1.32, 2.02, 2.87, 3.83, 4.89, 5.72, 6.85, 7.86, 9.48] | S -Dehydroepiandrosteroni, sulfaatti | Serum |  | Dehydroepiandrosterone sulfate [Moles/volume] in Serum |
| 640 | s-e1 | pmol/l | 80% | name+unit+values | 123 | 0 | [71.12, 113.75, 135.4, 184.19, 225.67, 280.98, 347.05, 435.31, 614] | S -Estroni | Serum |  | Estrone [Moles/volume] in Serum |
| 641 | s-e1 |  | 20% | name | 30 | 100 |  | S -Estroni | Serum |  | Estrone [Moles/volume] in Serum |
| 642 | s-e2 | nmol/l | 81% | name+unit+values | 10351 | 0 | [0.07, 0.1, 0.13, 0.16, 0.2, 0.27, 0.37, 0.54, 0.98] | S -Estradioli | Serum |  | Estradiol [Moles/volume] in Serum |
| 643 | s-e2 |  | 19% | name+values | 2381 | 100 | [0.07, 0.1, 0.11, 0.14, 0.17, 0.2, 0.26, 0.37, 0.59] | S -Estradioli | Serum |  | Estradiol [Moles/volume] in Serum |
| 644 | s-ema |  | 100% | name | 2245 | 100 |  | S -Endomysium, vasta-aineet | Serum |  | Endomysial Ab [Presence] in Serum by Immunofluorescence |
| 645 | s-ena |  | 100% | name+values | 1469 | 100 | [0.1, 0.1, 0.1, 0.2, 0.2, 0.22, 0.3, 0.5, 1.15] |  | Serum |  | Extractable nuclear Ab [Ratio] in Serum |
| 646 | s-enal |  | 100% | name | 832 | 100 |  |  | Serum |  | Extractable nuclear Ab panel - Serum |
| 647 | s-ffa | mmol/l | 100% | name+unit+values | 518 | 0 | [0.03, 0.04, 0.08, 0.13, 0.18, 0.28, 0.44, 0.57, 0.75] |  | Serum |  | Fatty acids.free [Moles/volume] in Serum |
| 648 | s-gen | mg/l | 52% | name+unit+values | 373 | 0.27 | [0.5, 0.66, 0.76, 0.89, 0.99, 1.17, 1.47, 2.03, 3.89] | S -Gentamysiini | Serum |  | Gentamicin [Mass/volume] in Serum or Plasma |
| 649 | s-gen |  | 48% | name | 339 | 100 |  | S -Gentamysiini | Serum |  | Gentamicin [Mass/volume] in Serum or Plasma |
| 650 | s-hae |  | 100% | name | 751 | 100 |  |  | Serum |  | Hereditary angioedema panel - Serum |
| 651 | s-hbe |  | 100% | name | 347 | 100 |  |  | Serum |  | Hepatitis B virus e Ag [Presence] in Serum |
| 652 | s-hcg | iu/l | 9% | name+unit+values | 2181 | 0 | [2.03, 3.95, 10.46, 38.54, 127.28, 369.25, 940.92, 2982.24, 13488.73] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Units/volume] in Serum |
| 653 | s-hcg | u/l | 24% | name+unit+values | 5914 | 0.08 | [5.54, 20.85, 66.85, 168.4, 361.64, 670.15, 1496.54, 4307.97, 16838.39] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Units/volume] in Serum |
| 654 | s-hcg |  | 67% | name+values | 16592 | 100 | [8.52, 18.24, 40.62, 113.39, 319.93, 924.91, 3362.22, 10372.34, 38864.49] | S -Koriongonadotropiini | Serum |  | Choriogonadotropin [Units/volume] in Serum |
| 655 | s-he4 | pmol/l | 96% | name+unit+values | 11193 | 0 | [31.8, 37.2, 41.86, 46.93, 53.05, 60.93, 73.32, 98.06, 184.4] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  | HE4 protein [Moles/volume] in Serum |
| 656 | s-he4 |  | 4% | name+values | 420 | 100 | [28.89, 32.42, 35.14, 39.73, 42.86, 45.92, 51.27, 61.15, 81.37] | S -Epididymaalinen antigeeni 4 (HE4) | Serum |  | HE4 protein [Moles/volume] in Serum |
| 657 | s-kem |  | 100% | name | 1473 | 100 |  |  | Serum |  |  |
| 658 | s-kyhemag | titre | 18% | name+unit+values | 180 | 0 | [8, 16, 16, 28.54, 32, 64, 163.55, 483.7, 1556.48] | S -Kylmähemagglutiniinit | Serum |  | Cold agglutinin [Titer] in Serum |
| 659 | s-kyhemag |  | 82% | name | 826 | 100 |  | S -Kylmähemagglutiniinit | Serum |  | Cold agglutinin [Titer] in Serum |
| 660 | s-shbg | nmol/l | 98% | name+unit+values | 29338 | 0 | [16.87, 21.37, 25.24, 29.25, 33.23, 37.98, 43.66, 51.48, 65.24] | S -Sukupuolihormoneja sitova globuliini | Serum |  | Sex hormone binding globulin [Moles/volume] in Serum |
| 661 | s-shbg |  | 2% | name | 614 | 100 |  | S -Sukupuolihormoneja sitova globuliini | Serum |  | Sex hormone binding globulin [Moles/volume] in Serum |
| 662 | s-tati | nmol/l | 51% | name+unit+values | 551 | 0 | [1.3, 1.48, 1.65, 1.82, 2.09, 2.38, 2.76, 3.46, 6.22] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor associated trypsin inhibitor [Moles/volume] in Serum |
| 663 | s-tati | ug/l | 41% | name+unit+values | 446 | 0 | [6.73, 8.09, 9.02, 9.95, 11.09, 12.18, 13.95, 17.1, 31.19] | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor associated trypsin inhibitor [Mass/volume] in Serum |
| 664 | s-tati |  | 8% | name | 86 | 100 |  | S -Tuumoriin liittyvä trypsiini-inhibiittori | Serum |  | Tumor associated trypsin inhibitor [Moles/volume] in Serum |
| 665 | s-van | mg/l | 96% | name+unit+values | 36935 | 0 | [6.88, 8.63, 10, 11.22, 12.44, 13.72, 15.08, 16.91, 19.82] | S -Vankomysiini | Serum |  | Vancomycin [Mass/volume] in Serum or Plasma |
| 666 | s-van |  | 4% | name | 1695 | 100 |  | S -Vankomysiini | Serum |  | Vancomycin [Mass/volume] in Serum or Plasma |
| 667 | ts-res |  | 100% | name | 1353 | 100 |  | Ts-Reseptoritutkimus | Tissue |  | Estrogen and Progesterone receptor panel in Tissue |
| 668 | u-hcg | iu/l | 28% | name+unit+values | 93 | 0 | [1.4, 1.54, 1.7, 1.9, 2.16, 2.3, 2.81, 31.3, 4256] | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Units/volume] in Urine |
| 669 | u-hcg | u/l | 4% | name+unit | 15 | 0 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Units/volume] in Urine |
| 670 | u-hcg |  | 68% | name | 227 | 100 |  | U -Koriongonadotropiini | Urine |  | Choriogonadotropin [Presence] in Urine |

