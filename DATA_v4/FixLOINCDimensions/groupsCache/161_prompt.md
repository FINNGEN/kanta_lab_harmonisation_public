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
Here is group 161.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 3024117 | Large unstained cells/Leukocytes in Blood by Automated count | 1.000 | 1894 |
| 3024944 | Large unstained cells [#/volume] in Blood by Automated count | 1.000 |  |
| 3032897 | Saturated fatty acids [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3032911 | Monounsaturated fatty acids [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3032924 | Polyunsaturated fatty acids [Moles/volume] in Serum or Plasma | 1.000 |  |
| 3042194 | Human metapneumovirus RNA [Presence] in Specimen by NAA with probe detection | 0.973 |  |
| 40759040 | C peptide [Moles/volume] in Serum or Plasma --post meal | 0.971 |  |
| 3002482 | Mycoplasma pneumoniae DNA [Presence] in Specimen by NAA with probe detection | 0.968 |  |
| 40764127 | Haemophilus influenzae DNA [Presence] in Specimen by NAA with probe detection | 0.967 |  |
| 3020565 | Legionella pneumophila DNA [Presence] in Specimen by NAA with probe detection | 0.966 |  |
| 40770421 | Human metapneumovirus A RNA [Presence] in Specimen by NAA with probe detection | 0.966 |  |
| 3039422 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 75 g glucose PO | 0.962 | 876 |
| 3012413 | Glucose [Moles/volume] in Serum or Plasma --2 hours post meal | 0.962 | 1141 |
| 3017538 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 75 g glucose PO | 0.961 | 835 |
| 647029 | Human metapneumovirus RNA [Presence] in Specimen by NAA with non-probe detection | 0.960 |  |
| 1988720 | Haemophilus influenzae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.954 |  |
| 3966625 | Legionella sp DNA [Presence] in Specimen by NAA with probe detection | 0.953 |  |
| 40770422 | Human metapneumovirus B RNA [Presence] in Specimen by NAA with probe detection | 0.952 |  |
| 46236367 | Glucose [Moles/volume] in Serum, Plasma or Blood --2 hours post meal | 0.952 |  |
| 3024270 | Haemophilus influenzae A DNA [Presence] in Specimen by NAA with probe detection | 0.952 |  |
| 21493349 | Haemophilus influenzae DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.949 |  |
| 647393 | Mycoplasma pneumoniae DNA [Presence] in Specimen by NAA with non-probe detection | 0.949 |  |
| 3004067 | Glucose [Moles/volume] in Serum or Plasma --pre 75 g glucose PO | 0.949 |  |
| 40763480 | Human metapneumovirus Ag [Presence] in Specimen | 0.948 |  |
| 645732 | Haemophilus influenzae D DNA [Presence] in Specimen by NAA with probe detection | 0.947 |  |
| 649183 | Haemophilus influenzae F DNA [Presence] in Specimen by NAA with probe detection | 0.945 |  |
| 648164 | Haemophilus influenzae E DNA [Presence] in Specimen by NAA with probe detection | 0.944 |  |
| 3009154 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 100 g glucose PO | 0.944 | 896 |
| 3037432 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 100 g glucose PO | 0.943 | 872 |
| 3020869 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 50 g glucose PO | 0.942 | 338 |
| 37020808 | Human metapneumovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.939 |  |
| 3031478 | Chlamydophila pneumoniae DNA [Presence] in Specimen by NAA with probe detection | 0.939 |  |
| 40758510 | Glucose [Moles/volume] in Serum or Plasma --2.5 hours post 75 g glucose PO | 0.937 |  |
| 1469833 | Legionella pneumophila DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.937 |  |
| 3039848 | Human metapneumovirus Ag [Presence] in Specimen by Immunofluorescence | 0.935 |  |
| 1091752 | Human metapneumovirus RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.935 |  |
| 1469765 | Mycoplasma pneumoniae DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.934 |  |
| 40758480 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post 75 g glucose PO | 0.933 |  |
| 36659861 | C peptide [Mass/volume] in Serum or Plasma --1 hour post meal | 0.932 |  |
| 3048845 | C peptide [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 0.932 |  |
| 37020057 | Human metapneumovirus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.932 |  |
| 3024794 | Haemophilus influenzae B DNA [Presence] in Specimen by NAA with probe detection | 0.931 |  |
| 3023993 | Large unstained cells [#/volume] in Blood | 0.931 |  |
| 3021525 | Glucose [Moles/volume] in Capillary blood --2 hours post meal | 0.931 |  |
| 44816559 | Phosphatidylethanol [Mass/volume] in Blood | 0.930 |  |
| 37020902 | Legionella pneumophila DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.930 |  |
| 1469884 | Haemophilus influenzae DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.929 |  |
| 3027467 | Mycoplasma sp DNA [Presence] in Specimen by NAA with probe detection | 0.926 | 1555 |
| 37019690 | Mycoplasma pneumoniae DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.926 |  |
| 40759039 | C peptide [Mass/volume] in Serum or Plasma --post meal | 0.925 |  |
| 37019853 | Mycoplasma pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.925 |  |
| 3019765 | Glucose [Moles/volume] in Serum or Plasma --pre 50 g glucose PO | 0.925 |  |
| 37020565 | Human metapneumovirus RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.925 |  |
| 36304237 | Mycoplasma pneumoniae DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.924 |  |
| 3040659 | Glucose [Moles/volume] in Serum or Plasma --1 hour post meal | 0.923 | 1362 |
| 1091652 | Human metapneumovirus RNA [Presence] in Sputum by NAA with probe detection | 0.923 |  |
| 36303340 | Legionella pneumophila DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.923 |  |
| 646649 | Chlamydophila pneumoniae DNA [Presence] in Specimen by NAA with non-probe detection | 0.922 |  |
| 40770181 | Legionella micdadei DNA [Presence] in Specimen by NAA with probe detection | 0.921 |  |
| 37019632 | Legionella pneumophila DNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.921 |  |
| 1176113 | Human metapneumovirus RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.921 |  |
| 1091344 | Haemophilus parainfluenzae DNA [Presence] in Specimen by NAA with probe detection | 0.921 |  |
| 37020896 | Mycoplasma pneumoniae DNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.920 |  |
| 3051746 | C peptide [Moles/volume] in Serum or Plasma --1.5 hours post dose glucose | 0.919 |  |
| 37020338 | Haemophilus influenzae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.918 |  |
| 648705 | Haemophilus influenzae C DNA [Presence] in Specimen by NAA with probe detection | 0.916 |  |
| 3042995 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post meal | 0.916 |  |
| 1259858 | Legionella pneumophila DNA [Presence] in Upper respiratory specimen by NAA with non-probe detection | 0.915 |  |
| 3016103 | Fatty acids [Moles/volume] in Serum or Plasma | 0.912 |  |
| 36660331 | C peptide [Mass/volume] in Serum or Plasma --1.5 hours post meal | 0.910 |  |
| 3047586 | C peptide [Moles/volume] in Serum or Plasma --1 hour post XXX challenge | 0.909 |  |
| 37020101 | Chlamydophila pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.909 |  |
| 3017634 | Glucose [Moles/volume] in Serum or Plasma --4 hours post 75 g glucose PO | 0.908 |  |
| 36306047 | Chlamydophila pneumoniae DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.908 |  |
| 3049810 | C peptide [Moles/volume] in Serum or Plasma --1 minute post dose glucose | 0.908 |  |
| 1761538 | Legionella spp [Presence] in Specimen by NAA with probe detection | 0.907 |  |
| 3025673 | Glucose [Mass/volume] in Serum or Plasma --2 hours post 75 g glucose PO | 0.907 |  |
| 37020392 | Chlamydophila pneumoniae DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.907 |  |
| 3016701 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 0.907 | 884 |
| 37019511 | Chlamydophila pneumoniae DNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.906 |  |
| 36305704 | Legionella pneumophila DNA [Presence] in Tissue by NAA with probe detection | 0.906 |  |
| 3017091 | Glucose [Moles/volume] in Serum or Plasma --3 hours post 75 g glucose PO | 0.905 |  |
| 3005793 | Glucose [Moles/volume] in Serum or Plasma --30 minutes post 75 g glucose PO | 0.905 | 1230 |
| 3018175 | Glucose [Moles/volume] in Serum or Plasma --5 hours post 75 g glucose PO | 0.905 |  |
| 42868682 | Glucose [Moles/volume] in Serum or Plasma --pre 100 g glucose PO | 0.905 | 1450 |
| 3001501 | Glucose [Moles/volume] in Capillary blood by Glucometer | 0.905 |  |
| 3052723 | C peptide [Moles/volume] in Serum or Plasma --1.5 hours post XXX challenge | 0.905 |  |
| 3049479 | C peptide [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 0.905 |  |
| 3041930 | Glucose [Moles/volume] in Serum or Plasma --post meal | 0.905 |  |
| 1092267 | Chlamydophila pneumoniae DNA [Presence] in Specimen | 0.904 |  |
| 3034530 | Glucose [Mass/volume] in Blood --2 hours post meal | 0.904 |  |
| 36305584 | Mycoplasma pneumoniae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.903 |  |
| 37021263 | Human metapneumovirus Ag [Presence] in Upper respiratory specimen by Immunofluorescence | 0.903 |  |
| 40761619 | C peptide [Moles/volume] in Serum or Plasma --5 hours post dose glucose | 0.900 |  |
| 3015024 | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 0.900 | 928 |
| 649408 | Mycoplasma pneumoniae DNA [Presence] in Bronchoalveolar aspirate by NAA with non-probe detection | 0.900 |  |
| 3007332 | Glucose [Mass/volume] in Serum or Plasma --1 hour post 75 g glucose PO | 0.900 |  |
| 3003435 | Glucose [Mass/volume] in Serum or Plasma --pre 75 g glucose PO | 0.896 |  |
| 3050109 | C peptide [Moles/volume] in Serum or Plasma --5 minutes post dose glucose | 0.896 |  |
| 36660342 | C peptide [Mass/volume] in Serum or Plasma --2 hours post meal | 0.896 |  |
| 3053233 | C peptide [Moles/volume] in Serum or Plasma --10 minutes post dose glucose | 0.894 |  |
| 36660548 | C peptide [Mass/volume] in Serum or Plasma --5 hours post meal | 0.893 |  |
| 36304484 | Chlamydophila pneumoniae DNA [Presence] in Aspirate by NAA with probe detection | 0.891 |  |
| 43055143 | Glucose [Moles/volume] in Blood by Automated test strip | 0.891 |  |
| 1091284 | Glucose [Moles/volume] in Interstitial fluid | 0.889 |  |
| 3036505 | Phosphoethanolamine [Moles/volume] in Blood | 0.886 |  |
| 37021514 | Human metapneumovirus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.886 |  |
| 44787039 | Large unstained cells/Leukocytes in Cord blood by Automated count | 0.885 |  |
| 3023323 | Follitropin [Units/volume] in Serum or Plasma | 0.885 | 230 |
| 645620 | Chlamydophila pneumoniae DNA [Presence] in Bronchoalveolar aspirate by NAA with non-probe detection | 0.885 |  |
| 37021229 | Gastrointestinal viral pathogens panel - Stool by NAA with probe detection | 0.884 |  |
| 44787101 | Large unstained cells/Leukocytes in Blood from Fetus by Automated count | 0.876 |  |
| 3008770 | Glucose [Moles/volume] in Urine by Test strip | 0.874 | 73 |
| 3038872 | Human metapneumovirus IgG Ab [Presence] in Serum by Immunoassay | 0.874 |  |
| 1616586 | Haemophilus influenzae DNA [Presence] in Synovial fluid by NAA with non-probe detection | 0.872 |  |
| 36305650 | Human metapneumovirus Ag [Presence] in Nasopharynx by Immunofluorescence | 0.871 |  |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 0.871 |  |
| 3010224 | Large unstained cells/Leukocytes in Blood | 0.869 |  |
| 3009214 | Lutropin [Units/volume] in Serum or Plasma | 0.867 | 271 |
| 1469787 | Haemophilus influenzae DNA [Presence] in Body fluid by NAA with non-probe detection | 0.864 |  |
| 3044398 | Haemophilus influenzae B Ag [Presence] in Serum | 0.864 |  |
| 40758481 | Glucose [Moles/volume] in Serum or Plasma --45 minutes post 75 g glucose PO | 0.862 |  |
| 3002225 | Fatty acids [Mass/volume] in Serum or Plasma | 0.860 |  |
| 3020058 | Glucose [Mass/volume] in Serum or Plasma --pre 100 g glucose PO | 0.860 |  |
| 3039777 | Haemophilus influenzae B DNA [Presence] in Blood by NAA with probe detection | 0.859 |  |
| 1091209 | Haemophilus influenzae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.859 |  |
| 42529215 | Follitropin [Units/volume] in Serum or Plasma by Immunoassay | 0.854 |  |
| 3025226 | Haemophilus influenzae A Ag [Presence] in Specimen | 0.853 |  |
| 1091501 | Haemophilus influenzae DNA [Presence] in Bronchoalveolar lavage by NAA with probe detection | 0.853 |  |
| 3014053 | Glucose [Mass/volume] in Blood by Test strip manual | 0.852 |  |
| 3024576 | Haemophilus influenzae B Ag [Presence] in Specimen | 0.849 |  |
| 3039249 | Haemophilus influenzae Ag [Presence] in Urine | 0.848 |  |
| 21492659 | Gastrointestinal pathogens panel - Stool by NAA with probe detection | 0.847 |  |
| 3025178 | Haemophilus influenzae E Ag [Presence] in Specimen | 0.846 |  |
| 40762249 | Glucose [Moles/volume] in Urine by Automated test strip | 0.845 |  |
| 3031088 | Haemophilus influenzae B Ag [Presence] in Body fluid | 0.843 |  |
| 36305767 | Norovirus genogroups I and II RNA panel - Stool by NAA with probe detection | 0.842 |  |
| 3023122 | Fatty acids.very long chain [Moles/volume] in Serum or Plasma | 0.842 | 1826 |
| 3002727 | Haemophilus influenzae B Ag [Presence] in Urine | 0.841 |  |
| 3009848 | Haemophilus influenzae A Ag [Presence] in Urine | 0.840 |  |
| 3009471 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma | 0.838 |  |
| 3026840 | Haemophilus influenzae F Ag [Presence] in Specimen | 0.837 |  |
| 42529220 | Lutropin [Units/volume] in Serum or Plasma by Immunoassay | 0.837 |  |
| 3034962 | Glucose [Mass/volume] in Capillary blood by Glucometer | 0.835 |  |
| 3044002 | Follitropin and Lutropin panel [Units/volume] - Serum or Plasma | 0.834 |  |
| 3017703 | Fasting glucose [Moles/volume] in Capillary blood by Glucometer | 0.832 |  |
| 3011562 | Phosphoethanolamine [Moles/volume] in Serum or Plasma | 0.831 |  |
| 1988482 | Polyunsaturated fatty acids [Moles/volume] in RBC.lysate | 0.830 |  |
| 3011424 | Glucose [Mass/volume] in Blood by Automated test strip | 0.828 |  |
| 3037523 | Haemophilus influenzae Ag [Presence] in Cerebral spinal fluid | 0.827 |  |
| 3044775 | Unidentified cells/Leukocytes in Blood by Automated count | 0.825 |  |
| 1989265 | Glucose [Mass/volume] in Interstitial fluid | 0.825 |  |
| 3031148 | Octadecanoate (C18:0) [Moles/volume] in Serum or Plasma | 0.822 |  |
| 21493361 | Gastrointestinal pathogens DNA and RNA panel - Stool by NAA with non-probe detection | 0.821 |  |
| 3045692 | Fatty acids.very long chain C26:1 (Hexacosenoate) [Moles/volume] in Serum or Plasma | 0.820 |  |
| 648169 | Glucose [Measurement] in Interstitial fluid | 0.820 |  |
| 3014305 | Glucose [Presence] in Blood by Test strip | 0.819 |  |
| 3004198 | Follitropin [Units/volume] in Serum or Plasma --baseline | 0.819 |  |
| 3031028 | Follitropin [Units/volume] in Serum or Plasma --1st specimen | 0.817 |  |
| 3031429 | Oleate (C18:1w9) [Moles/volume] in Serum or Plasma | 0.817 |  |
| 1989322 | Saturated fatty acids [Moles/volume] in RBC.lysate | 0.817 |  |
| 3006361 | Follitropin [Units/volume] in Serum or Plasma by 2nd IRP | 0.816 |  |
| 647169 | Follitropin [Measurement] in Serum or Plasma | 0.812 |  |
| 3029896 | Follitropin [Units/volume] in Serum or Plasma --5th specimen | 0.812 |  |
| 3015962 | Follitropin.beta subunit [Moles/volume] in Serum or Plasma | 0.810 |  |
| 1091681 | Glucose [Moles/volume] in Reporting Period mean Interstitial fluid by calculation | 0.810 |  |
| 3025484 | Inhibin [Units/volume] in Serum or Plasma | 0.809 |  |
| 3009201 | Thyrotropin [Units/volume] in Serum or Plasma | 0.809 | 105 |
| 3032325 | Omega 3 fatty acids (w3) [Moles/volume] in Serum or Plasma | 0.808 |  |
| 3032337 | Omega 6 fatty acids (w6) [Moles/volume] in Serum or Plasma | 0.808 |  |
| 37019628 | Gastrointestinal bacterial pathogens panel - Stool by NAA with probe detection | 0.807 |  |
| 46235199 | Phosphatidylethanol [Presence] in Blood by Screen method | 0.806 |  |
| 3964626 | Phosphatidylethanol panel - Blood | 0.806 |  |
| 3051732 | Lutropin [Units/volume] in Serum or Plasma --pre 100 ug luteinizing releasing hormone IV | 0.806 |  |
| 3018171 | Choriogonadotropin [Units/volume] in Serum or Plasma | 0.805 | 252 |
| 3036078 | Lutropin [Moles/volume] in Serum or Plasma | 0.801 |  |
| 3025119 | Lutropin [Units/volume] in Serum or Plasma --baseline | 0.801 |  |
| 37021149 | Gastrointestinal parasitic pathogens panel - Stool by NAA with probe detection | 0.801 |  |
| 3021387 | Prolactin [Units/volume] in Serum or Plasma | 0.800 |  |
| 42529121 | Adenovirus and Norovirus and Rotavirus Ag panel - Stool by Rapid immunoassay | 0.799 |  |
| 3031157 | Palmitoleate (C16:1w7) [Moles/volume] in Serum or Plasma | 0.797 |  |
| 1988524 | Monounsaturated fatty acids [Moles/volume] in RBC.lysate | 0.796 |  |
| 3027241 | Phosphoethanolamine [Moles/volume] in Urine | 0.796 |  |
| 3005019 | Lutropin [Units/volume] in Serum or Plasma --30 minutes post 100 ug luteinizing releasing hormone IV | 0.795 |  |
| 3024897 | Lutropin [Units/volume] in Serum or Plasma --1 hour post 100 ug luteinizing releasing hormone IV | 0.795 |  |
| 3032660 | Eicosapentaenoate (C20:5w3) [Moles/volume] in Serum or Plasma | 0.793 |  |
| 1092191 | Enteric pathogen panel - Stool by NAA with probe detection | 0.790 |  |
| 1091245 | Enteric bacteria panel - Stool by NAA with probe detection | 0.790 |  |
| 3031194 | Linoleate (C18:2w6) [Moles/volume] in Serum or Plasma | 0.790 |  |
| 1092353 | Enteric parasite panel - Stool by NAA with probe detection | 0.788 |  |
| 40757457 | Phosphoethanolamine [Moles/volume] in DBS | 0.781 |  |
| 3021077 | Phosphoethanolamine [Mass/volume] in Serum or Plasma | 0.781 |  |
| 3000905 | Leukocytes [#/volume] in Blood by Automated count | 0.778 | 15 |
| 3001574 | Phosphoethanolamine [Moles/volume] in Amniotic fluid | 0.774 |  |
| 3044584 | Phosphoethanolamine [Moles/volume] in 24 hour Urine | 0.771 |  |
| 1617169 | Average glucose [Mass/volume] in Interstitial fluid during Reporting Period | 0.751 |  |
| 3020491 | Glucose [Moles/volume] in Blood | 0.745 | 13 |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.744 | 788 |
| 3020044 | Glucose [Moles/volume] in Cerebral spinal fluid | 0.742 | 550 |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1790 | b-fosfatidyylietanoli | umol/l | 49% | name+unit+values | 4792 | 0 | [0.06, 0.1, 0.15, 0.22, 0.3, 0.44, 0.64, 0.94, 1.57] |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1791 | b-fosfatidyylietanoli |  | 51% | name+values | 4963 | 89.32 | [0.09, 0.13, 0.17, 0.29, 0.43, 0.63, 0.85, 1.22, 1.87] |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1792 | b-fosfatidyylietanoli,verestä | umol/l | 50% | name+unit+values | 1555 | 0 | [0.06, 0.1, 0.15, 0.22, 0.29, 0.41, 0.59, 0.87, 1.44] |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1793 | b-fosfatidyylietanoli,verestä |  | 50% | name | 1534 | 97.07 |  |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1794 | b-fosfatidyylietanolivita | umol/l | 38% | name+unit | 43 | 0 |  |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1795 | b-fosfatidyylietanolivita |  | 62% | name | 69 | 100 |  |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1796 | b-haemophilusinfluenzae |  | 100% | name | 144 | 100 |  |  | Blood |  | Haemophilus influenzae [Presence] in Blood |
| 1797 | b-suuretvärjäytymättömätsolut | e9/l | 100% | name+unit+values | 171 | 0 | [0.07, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.18] |  | Blood |  | Large unstained cells [#/volume] in Blood by Automated count |
| 1798 | chlamydiapneumoniae,nukleiin |  | 100% | name | 109 | 100 |  |  |  |  | Chlamydia pneumoniae DNA [Presence] in Specimen by NAA |
| 1799 | follikkeliastimuloivahormoni | u/l | 100% | name+unit+values | 138 | 0 | [3, 4.75, 6.19, 8.24, 10, 19.35, 36.42, 56.82, 73.33] |  |  |  | Follicle stimulating hormone [Units/volume] in Serum or Plasma |
| 1800 | fosfatidyylietanoli | umol/l | 49% | name+unit+values | 1540 | 0 | [0.05, 0.09, 0.14, 0.2, 0.29, 0.43, 0.63, 0.98, 1.62] |  |  |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1801 | fosfatidyylietanoli |  | 51% | name+values | 1635 | 92.35 | [0.09, 0.19, 0.32, 0.43, 0.64, 0.89, 1.16, 1.43, 1.78] |  |  |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1802 | fosfatidyylietanoli,verestä | umol/l | 50% | name+unit+values | 3284 | 0 | [0.06, 0.08, 0.12, 0.16, 0.22, 0.3, 0.44, 0.66, 1.2] |  |  |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1803 | fosfatidyylietanoli,verestä |  | 50% | name | 3273 | 98.93 |  |  |  |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1804 | fosfatidyylietanoli,verestätth | umol/l | 35% | name+unit | 35 | 0 |  |  |  |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1805 | fosfatidyylietanoli,verestätth |  | 65% | name | 66 | 100 |  |  |  |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1806 | fosfatidyylietanoli,veri | umol/l | 50% | name+unit+values | 335 | 0 | [0.06, 0.1, 0.15, 0.2, 0.28, 0.39, 0.6, 0.91, 1.55] |  |  |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1807 | fosfatidyylietanoli,veri |  | 50% | name | 333 | 91.89 |  |  |  |  | Phosphatidylethanol [Moles/volume] in Blood |
| 1808 | haemophilusinfluenzaenukleii |  | 100% | name | 459 | 100 |  |  |  |  | Haemophilus influenzae DNA [Presence] in Specimen by NAA |
| 1809 | humaanimetapneumovirus,nukle |  | 100% | name | 109 | 100 |  |  |  |  | Human metapneumovirus RNA [Presence] in Specimen by NAA |
| 1810 | humanmetapneumovirus,ag |  | 100% | name | 102 | 100 |  |  |  |  | Human metapneumovirus Ag [Presence] in Specimen by Immunoassay |
| 1811 | l-suuretvärjääntymättömätsolut | % | 100% | name+unit+values | 171 | 0 | [1.19, 1.35, 1.5, 1.62, 1.83, 1.97, 2.16, 2.45, 2.85] |  | Leukocyte |  | Large unstained cells/Leukocytes in Blood by Automated count |
| 1812 | legionellapneumoniaenukleiin |  | 100% | name | 109 | 100 |  |  |  |  | Legionella pneumophila DNA [Presence] in Specimen by NAA |
| 1813 | li-haemophilusinfluenzaenukl.haponos. |  | 100% | name | 119 | 100 |  |  | Cerebrospinal fluid |  | Haemophilus influenzae DNA [Presence] in Cerebral spinal fluid by NAA |
| 1814 | mycoplasmapneumoniae,nukleii |  | 100% | name | 141 | 100 |  |  |  |  | Mycoplasma pneumoniae DNA [Presence] in Specimen by NAA |
| 1815 | p-follikkeliastimuloivahormoni | u/l | 100% | name+unit+values | 511 | 0 | [2.89, 4.55, 5.71, 7.4, 9.51, 16.11, 32.21, 53.45, 77.25] |  | Plasma |  | Follicle stimulating hormone [Units/volume] in Serum or Plasma |
| 1816 | p-glukoosi,2tuntiaaterianjälkeen | mmol/l | 100% | name+unit+values | 125 | 0 | [6.3, 7.71, 9.12, 10.17, 11.1, 12.22, 14.28, 15.89, 18.81] |  | Plasma |  | Glucose [Moles/volume] in Plasma --2 hours post meal |
| 1817 | p-glukoosi,toimintakokeissa,1h | mmol/l | 100% | name+unit+values | 126 | 0 | [5.54, 6.18, 6.52, 7.01, 7.43, 7.82, 8.23, 9.1, 9.88] |  | Plasma |  | Glucose [Moles/volume] in Plasma --1 hour post 75 g glucose PO |
| 1818 | p-glukoosi,toimintakokeissa,2h | mmol/l | 100% | name+unit+values | 240 | 0 | [4.47, 5.01, 5.34, 5.8, 6.31, 7.03, 7.79, 8.75, 11.07] |  | Plasma |  | Glucose [Moles/volume] in Plasma --2 hours post 75 g glucose PO |
| 1819 | p-glukoosi,toimntakokeissa0m | mmol/l | 100% | name+unit+values | 242 | 0 | [4.3, 4.6, 4.8, 5.01, 5.22, 5.42, 5.83, 6.26, 6.93] |  | Plasma |  | Glucose [Moles/volume] in Plasma --pre 75 g glucose PO |
| 1820 | p-luteinisoivahormoni | u/l | 95% | name+unit+values | 198 | 0 | [2.79, 3.77, 4.73, 5.42, 6.66, 8.63, 10.71, 14.48, 27.26] |  | Plasma |  | Luteinizing hormone [Units/volume] in Serum or Plasma |
| 1821 | p-luteinisoivahormoni |  | 5% | name | 10 | 100 |  |  | Plasma |  | Luteinizing hormone [Units/volume] in Serum or Plasma |
| 1822 | p-omagluk,,potilasmittaringlukoosi |  | 100% | name | 1376 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Capillary blood by Test strip |
| 1823 | potilasmittaringlukoosi,ihopisto | mmol/l | 54% | name+unit+values | 749 | 0 | [5.9, 6.36, 6.79, 7.19, 7.51, 7.86, 8.26, 8.85, 9.69] |  |  |  | Glucose [Moles/volume] in Capillary blood by Test strip |
| 1824 | potilasmittaringlukoosi,ihopisto |  | 46% | name | 638 | 100 |  |  |  |  | Glucose [Moles/volume] in Capillary blood by Test strip |
| 1825 | potilasmittaringlukoosi,sensori | mmol/l | 26% | name+unit+values | 201 | 0 | [5.55, 6.53, 7.01, 7.7, 8.35, 9.14, 10.02, 11.7, 13.49] |  |  |  | Glucose [Moles/volume] in Interstitial fluid by Continuous glucose monitoring |
| 1826 | potilasmittaringlukoosi,sensori |  | 74% | name | 568 | 100 |  |  |  |  | Glucose [Moles/volume] in Interstitial fluid by Continuous glucose monitoring |
| 1827 | s-c-peptidi1haterianjälkeen | nmol/l | 96% | name+unit+values | 275 | 0 | [0.5, 0.75, 0.96, 1.2, 1.4, 1.62, 1.92, 2.33, 3.08] |  | Serum |  | C-peptide [Moles/volume] in Serum or Plasma --1 hour post meal |
| 1828 | s-c-peptidi1haterianjälkeen |  | 4% | name | 10 | 90 |  |  | Serum |  | C-peptide [Moles/volume] in Serum or Plasma --1 hour post meal |
| 1829 | s-c-peptidiaterianjälkeen | nmol/l | 100% | name+unit+values | 150 | 0 | [0.4, 0.65, 0.9, 1.07, 1.22, 1.49, 2.03, 2.41, 2.88] |  | Serum |  | C-peptide [Moles/volume] in Serum or Plasma --post meal |
| 1830 | s-follikkeliastimuloivahormoni | iu/l | 83% | name+unit+values | 416 | 0 | [3.31, 4.85, 6.04, 7.33, 10.33, 18.46, 32.36, 54.77, 76.02] |  | Serum |  | Follicle stimulating hormone [Units/volume] in Serum or Plasma |
| 1831 | s-follikkeliastimuloivahormoni | u/l | 16% | name+unit+values | 80 | 0 | [3.2, 4.8, 5.65, 6.55, 7.78, 10.22, 16.95, 45.35, 68.7] |  | Serum |  | Follicle stimulating hormone [Units/volume] in Serum or Plasma |
| 1832 | s-follikkeliastimuloivahormoni |  | 1% | name | 7 | 100 |  |  | Serum |  | Follicle stimulating hormone [Units/volume] in Serum or Plasma |
| 1833 | s-kertatyydyttymättömätrasvahapot | mmol/l | 100% | name+unit+values | 263 | 0 | [2.43, 2.7, 2.8, 2.99, 3.17, 3.35, 3.54, 3.9, 4.36] |  | Serum |  | Monounsaturated fatty acids [Moles/volume] in Serum or Plasma |
| 1834 | s-luteinisoivahormoni | iu/l | 82% | name+unit+values | 178 | 0 | [1.51, 2.37, 3.11, 3.71, 4.6, 5.61, 7.56, 11.94, 22.46] |  | Serum |  | Luteinizing hormone [Units/volume] in Serum or Plasma |
| 1835 | s-luteinisoivahormoni | u/l | 12% | name+unit | 26 | 0 |  |  | Serum |  | Luteinizing hormone [Units/volume] in Serum or Plasma |
| 1836 | s-luteinisoivahormoni |  | 6% | name | 14 | 100 |  |  | Serum |  | Luteinizing hormone [Units/volume] in Serum or Plasma |
| 1837 | s-monityydyttymättömätrasvahapot | mmol/l | 96% | name+unit+values | 255 | 0 | [4.74, 4.99, 5.23, 5.48, 5.58, 5.7, 5.92, 6.18, 6.55] |  | Serum |  | Polyunsaturated fatty acids [Moles/volume] in Serum or Plasma |
| 1838 | s-monityydyttymättömätrasvahapot |  | 4% | name | 11 | 100 |  |  | Serum |  | Polyunsaturated fatty acids [Moles/volume] in Serum or Plasma |
| 1839 | s-tyydyttyneetrasvahapot | mmol/l | 100% | name+unit+values | 265 | 0 | [3.09, 3.37, 3.58, 3.77, 3.9, 4.15, 4.36, 4.73, 5.26] |  | Serum |  | Saturated fatty acids [Moles/volume] in Serum or Plasma |
| 1840 | ulosteenripulivirukset,nukle |  | 100% | name | 109 | 100 |  |  |  |  | Viral gastroenteritis panel - Stool by NAA |

