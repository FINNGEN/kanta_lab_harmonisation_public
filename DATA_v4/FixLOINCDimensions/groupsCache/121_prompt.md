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
Here is group 121.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 |
|---|---|---|---|
| 36303746 | Microscopic observation [Identifier] in Bone marrow by Giemsa stain | 0.938 |  |
| 3014837 | Microscopic observation [Identifier] in Bone marrow by Wright Giemsa stain | 0.925 | 1579 |
| 3042168 | TPMT gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.911 |  |
| 3046976 | DPYD gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.910 |  |
| 21493707 | TPMT gene mutations found [Identifier] in Blood or Tissue by Sequencing Nominal | 0.905 |  |
| 3009106 | TP53 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.904 |  |
| 3026001 | HFE gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.898 |  |
| 40757578 | FLT3 gene targeted mutation analysis in Bone marrow by Molecular genetics method | 0.895 |  |
| 36304954 | Microscopic observation [Identifier] in Bone marrow by Gram stain | 0.894 |  |
| 3011668 | Microscopic observation [Identifier] in Bone marrow by Myeloperoxidase stain | 0.893 |  |
| 21493421 | Microscopic observation [Identifier] in Bone marrow by Toluidine blue O stain | 0.892 |  |
| 3051274 | Microscopic observation [Identifier] in Bone marrow by Rhodamine-auramine fluorochrome stain | 0.884 |  |
| 40758279 | BCR-ABL1 e1a2 fusion protein [Presence] in Blood or Tissue by Molecular genetics method | 0.882 |  |
| 3033006 | BCR-ABL1 e1a1 fusion protein [Presence] in Blood or Tissue by Molecular genetics method | 0.880 |  |
| 36303378 | Microscopic observation [Identifier] in Bone marrow by Acid fast stain | 0.878 |  |
| 3046498 | JAK2 gene p.Val617Phe [Presence] in Blood or Tissue by Molecular genetics method | 0.877 | 1692 |
| 3031317 | BCR-ABL1 b2a2 fusion protein [Presence] in Blood or Tissue by Molecular genetics method | 0.874 |  |
| 43054967 | JAK2 gene p.Val617Phe [Presence] in Bone marrow by Molecular genetics method | 0.870 |  |
| 3032498 | BCR-ABL1 b3a2 fusion protein [Presence] in Blood or Tissue by Molecular genetics method | 0.869 |  |
| 1001873 | DPYD gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.865 |  |
| 21493422 | Microscopic observation [Identifier] in Bone marrow by Oil red O stain | 0.864 |  |
| 3013321 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript [Presence] in Blood or Tissue by Molecular genetics method | 0.863 | 1776 |
| 42868452 | t(9;22)(q34.1;q11)(ABL1,BCR) e1a2 fusion transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.862 |  |
| 36304173 | Microscopic observation [Identifier] in Aspirate by Giemsa stain | 0.854 |  |
| 40761064 | DPYD2A gene targeted mutation analysis [Presence] in Blood or Tissue by Molecular genetics method | 0.854 |  |
| 3049135 | FLT3 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.853 |  |
| 3033239 | t(9;22)(q34.1;q11)(ABL1,BCR) e1a2 fusion transcript [Presence] in Blood or Tissue by Molecular genetics method | 0.853 |  |
| 44816906 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2 fusion transcript [Presence] in Blood or Tissue by Molecular genetics method | 0.852 |  |
| 36659909 | DPYD gene full mutation analysis in Blood or Tissue by Sequencing | 0.851 |  |
| 44816909 | t(9;22)(q34.1;q11)(ABL1,BCR) e19a2 fusion transcript [Presence] in Blood or Tissue by Molecular genetics method | 0.851 |  |
| 3047555 | MLH1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.850 |  |
| 1091032 | Multiple myeloma minimal residual disease analysis [Presence] in Bone marrow by NAA with non-probe detection | 0.848 |  |
| 3047340 | FMR1 gene allele 1 CGG repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.847 |  |
| 21494429 | FMR1 gene CGG repeat analysis in Blood or Tissue by Molecular genetics method | 0.847 |  |
| 3049056 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.846 |  |
| 3039049 | Pharmacogenetic DNA analysis panel | 0.846 |  |
| 44816925 | NPM1 gene mutations found [Identifier] in Bone marrow by Molecular genetics method Nominal | 0.846 |  |
| 3034974 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2+b3a2 fusion transcript [Presence] in Blood or Tissue by Molecular genetics method | 0.845 |  |
| 3041464 | NPHS1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.845 |  |
| 3017994 | Microscopic observation [Identifier] in Bone marrow by Butyrate esterase stain | 0.843 |  |
| 3038346 | JAK2 gene.p.Val617Phe mutant/Normal in Blood or Tissue by Molecular genetics method | 0.842 |  |
| 3041559 | t(9;22)(q34.1;q11)(ABL1,BCR) b3a2 fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.839 |  |
| 3025788 | FMR1 gene CGG repeats [Presence] in Blood or Tissue by Molecular genetics method | 0.839 |  |
| 3042391 | t(9;22)(q34.1;q11)(ABL1,BCR) e1a2 fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.839 |  |
| 46237016 | CALR gene exon 9 mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.838 |  |
| 3018543 | Iron.microscopic observation [Identifier] in Bone marrow by Potassium ferrocyanide stain | 0.838 |  |
| 3039381 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2 fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.838 |  |
| 21493420 | Microscopic observation [Identifier] in Bone marrow by Acetate esterase stain | 0.838 |  |
| 40771901 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2+b3a2 fusion transcript/control transcript (International Scale) [# Ratio] in Blood or Tissue by Molecular genetics method | 0.838 |  |
| 40766153 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2+b3a2+e1a2 fusion transcript [Presence] in Blood or Tissue by Molecular genetics method | 0.836 |  |
| 36303968 | JAK2 gene.p.Val617Phe mutant/Normal in Bone marrow by Molecular genetics method | 0.834 |  |
| 42527977 | FLT3 gene internal tandem duplication [Presence] in Bone marrow by Molecular genetics method | 0.832 |  |
| 3031465 | APOE gene allele 1 [Identifier] in Blood or Tissue by Molecular genetics method | 0.830 |  |
| 3045461 | Apolipoprotein E phenotype [Identifier] in Blood | 0.829 |  |
| 40758277 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2+b3a2 fusion transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.829 |  |
| 3043025 | FMR1 gene allele 2 CGG repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.828 |  |
| 1469500 | CALR gene exon 9 mutations found [Identifier] in Blood or Tissue by Sequencing Nominal | 0.826 |  |
| 42529041 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript/control transcript [Log Number Ratio] in Bone marrow by Molecular genetics method | 0.826 |  |
| 3044589 | NPHS1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.823 |  |
| 648345 | JAK2 gene.p.Val617Phe mutant/Normal in Specimen by Molecular genetics method | 0.821 |  |
| 42870298 | TPMT gene c.238G>C+460G>A+719A>G [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.821 |  |
| 37020002 | Multiple myeloma minimal residual disease panel - Bone marrow by Flow cytometry (FC) | 0.820 |  |
| 40763542 | NPHS2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.819 |  |
| 42528716 | CALR gene exon 9 full mutation analysis in Blood or Tissue by Molecular genetics method | 0.819 |  |
| 1617723 | MLH1 gene methylation analysis in Blood by Molecular genetics method | 0.818 |  |
| 3032354 | APOE gene allele 2 [Identifier] in Blood or Tissue by Molecular genetics method | 0.817 |  |
| 40761517 | MLH1 gene methylation [Presence] in Blood or Tissue by Molecular genetics method | 0.816 |  |
| 40757581 | CYP2C9 and VKORC1 panel - Blood or Tissue by Molecular genetics method | 0.815 |  |
| 21492686 | Pharmacogenomic analysis basic associated observations panel - Blood or Tissue | 0.814 |  |
| 3036403 | TP73L gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.814 |  |
| 3052805 | MSH2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.813 |  |
| 21491194 | MLH1+MSH2+MSH6+PMS2 gene deletion+duplication and full mutation analysis in Blood or Tissue by Molecular genetics method | 0.812 |  |
| 3029271 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript/control transcript [Log Number Ratio] in Blood or Tissue by Molecular genetics method | 0.811 |  |
| 46235504 | MSH2 gene+MLH1 gene+MSH6 gene mutation analysis limited to known familial mutations in Blood or Tissue by Molecular genetics method | 0.811 |  |
| 3042350 | MSH6 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.811 |  |
| 3042030 | NPHS1 gene mutations found [Identifier] in Body fluid by Molecular genetics method Nominal | 0.810 |  |
| 3026226 | HBB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.810 |  |
| 3041037 | FMR1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.809 |  |
| 40765085 | Chromosome analysis.metaphase panel - Blood by FISH | 0.804 |  |
| 3044596 | NPHS1 gene targeted mutation analysis in Body fluid by Molecular genetics method | 0.803 |  |
| 46236293 | HBB gene mutations found [Identifier] in Blood or Tissue by Sequencing Nominal | 0.800 |  |
| 40769530 | FMR1 gene premutation/premutation+full mutation in Blood by Molecular genetics method | 0.800 |  |
| 1091265 | DPYD gene.c.1236G>A [Presence] in Blood or Tissue by Molecular genetics method | 0.800 |  |
| 43054969 | NPM1 gene c.956dupTCTG transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.799 |  |
| 3024563 | HBA1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.799 |  |
| 43055147 | FLT3 gene.p.Asp835+Ile836 mutations [Presence] in Blood or Tissue by Molecular genetics method | 0.799 |  |
| 40759280 | LDLR gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.799 |  |
| 37019932 | FLT3 gene p.Asp835 mutations [Presence] in Blood or Tissue by Molecular genetics method | 0.799 |  |
| 1988594 | MET gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.798 |  |
| 40765086 | Chromosome analysis.interphase panel - Blood by FISH | 0.798 |  |
| 40769529 | FMR1 gene methylation/methylated+unmethylated in Blood by Molecular genetics method | 0.798 |  |
| 21493179 | Pharmacogenomics result panel | 0.797 |  |
| 21492353 | FLT3 gene internal tandem duplication [Presence] in Blood or Tissue by Molecular genetics method | 0.796 |  |
| 1761632 | TPMT gene c.460G>A and c.719A>G [Presence] in Blood by Molecular genetics method | 0.796 |  |
| 43054970 | NPM1 gene c.960insCCTG transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.796 |  |
| 44816910 | t(9;22)(q34.1;q11)(ABL1,BCR) e1a2 fusion transcript [Presence] in Bone marrow by Molecular genetics method | 0.796 |  |
| 40763634 | TCRG gene rearrangements [Presence] in Bone marrow by Molecular genetics method | 0.796 |  |
| 40763637 | TCRB gene rearrangements [Presence] in Bone marrow by Molecular genetics method | 0.795 |  |
| 1259714 | DPYD gene.c.1679T>G [Presence] in Blood or Tissue by Molecular genetics method | 0.795 |  |
| 40757579 | NPM1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.794 |  |
| 1259589 | DPYD gene.c.1905+1G>A [Presence] in Blood or Tissue by Molecular genetics method | 0.794 |  |
| 3043932 | GPC3 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.794 |  |
| 42529040 | t(9;22)(q34.1;q11)(ABL1,BCR) fusion transcript [Presence] in Bone marrow by Molecular genetics method | 0.793 |  |
| 43054968 | NPM1 gene c.960insCATG transcript/control transcript [# Ratio] in Bone marrow by Molecular genetics method | 0.793 |  |
| 40763629 | HC gene rearrangements [Presence] in Bone marrow by Molecular genetics method | 0.793 |  |
| 40763092 | PIK3CA gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.792 |  |
| 3048224 | HFE gene c.187G>C [Presence] in Blood or Tissue by Molecular genetics method | 0.791 |  |
| 3016769 | BCL6 gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.791 |  |
| 3029139 | APOE gene alleles e2 and e3 and e4 [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.791 |  |
| 3035795 | FMR1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.790 | 1531 |
| 3964788 | Bone marrow transplant chimerism panel - Plasma cell-free DNA by Sequencing | 0.790 |  |
| 3001099 | RB1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.790 |  |
| 1259496 | DPYD gene.c.2846A>T [Presence] in Blood or Tissue by Molecular genetics method | 0.789 |  |
| 3029984 | BRCA1+BRCA2 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.789 |  |
| 3033015 | TPMT gene c.238G>C [Presence] in Blood or Tissue by Molecular genetics method | 0.788 |  |
| 3029230 | t(9;22)(q34.1;q11)(ABL1,BCR) b2a2+b3a2 fusion transcript [#/volume] in Blood or Tissue by Molecular genetics method | 0.788 |  |
| 1259598 | Other cells/Leukocytes in Bronchoalveolar lavage by Manual count | 0.787 |  |
| 21492141 | BCL6 gene rearrangements [Presence] in Blood or Tissue by FISH | 0.787 |  |
| 1091308 | DNMT3A gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.787 |  |
| 3044282 | Cell count and Differential panel - Pleural fluid | 0.786 |  |
| 3028276 | BCL2 gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.786 |  |
| 40758056 | t(9;22)(q34.1;q11)(ABL1,BCR) e19a2 fusion transcript [#/volume] in Blood or Tissue by Molecular genetics method | 0.786 |  |
| 3032512 | TPMT gene c.460G>A [Presence] in Blood or Tissue by Molecular genetics method | 0.785 |  |
| 40769528 | FMR1 gene activation in Blood by Molecular genetics method | 0.784 |  |
| 3031701 | CCND1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.784 |  |
| 21493621 | Subtelomere analysis in Bone marrow by FISH | 0.784 |  |
| 40761114 | MSH2 gene+MLH1 gene+MSH6 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.783 |  |
| 3039791 | MLH1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.782 |  |
| 3031113 | MYC gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.782 |  |
| 3030112 | TPMT gene c.719A>G [Presence] in Blood or Tissue by Molecular genetics method | 0.782 |  |
| 3039853 | MTM1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.781 |  |
| 1989222 | Leukocytes [#/volume] in Bronchoalveolar lavage by Automated count | 0.780 |  |
| 3014186 | FRAXE gene CGG repeats [Presence] in Blood or Tissue by Molecular genetics method | 0.779 | 1557 |
| 1259630 | DPYD gene.c.1679T>G [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.779 |  |
| 1259537 | DPYD gene.c.1236G>A [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.779 |  |
| 46236487 | DLD gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.779 |  |
| 1617309 | MLH1 gene methylation analysis in Tumor by Molecular genetics method | 0.778 |  |
| 40765108 | Chromosome analysis panel by FISH | 0.778 |  |
| 37019979 | MLH1 gene deletion+duplication and full mutation analysis in Blood or Tissue by Molecular genetics method | 0.778 |  |
| 43055530 | SLC40A1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.778 |  |
| 40766184 | TPMT gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.778 |  |
| 21492156 | BCL2 gene rearrangements [Presence] in Blood or Tissue by FISH | 0.777 |  |
| 1259512 | DPYD gene.c.1905+1G>A [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.777 |  |
| 3040149 | CFH gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.777 |  |
| 1989460 | Leukocytes [#/volume] in Bronchoalveolar lavage by Manual count | 0.775 |  |
| 40762081 | FGB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.775 |  |
| 3011498 | APOE gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.775 | 1404 |
| 1469914 | CD3 cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.773 |  |
| 1617545 | FLT3 gene.p.Asp835+Ile836 mutations/Normal in Blood or Tissue by Molecular genetics method | 0.773 |  |
| 3035305 | HTT gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.773 |  |
| 40758430 | JAK2 gene exon 13 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.771 |  |
| 3013421 | HFE gene p.His63Asp [Presence] in Blood or Tissue by Molecular genetics method | 0.771 |  |
| 21494670 | JAK2 gene exon 14 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.771 |  |
| 3044045 | Cell count and Differential panel - Body fluid | 0.768 |  |
| 40758429 | JAK2 gene exon 12 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.768 |  |
| 3002228 | Alpha 1 antitrypsin phenotype [Identifier] in Serum or Plasma by Immunofixation | 0.766 |  |
| 36303911 | Respiratory pathogens panel - Bronchoalveolar lavage by Immunofluorescence | 0.765 |  |
| 43054999 | t(11;14)(q13;q32)(CCND1,IGH) fusion transcript [Presence] in Bone marrow by Molecular genetics method | 0.765 |  |
| 21494669 | JAK2 gene exon 12 targeted mutation analysis in Bone marrow by Molecular genetics method | 0.765 |  |
| 21492350 | BRCA1 gene mutation analysis limited to known familial mutations in Blood or Tissue by Molecular genetics method | 0.764 |  |
| 21494671 | JAK2 gene exon 14 targeted mutation analysis in Bone marrow by Molecular genetics method | 0.764 |  |
| 1616360 | FLT3 gene internal tandem duplication length [#] in Blood or Tissue by Molecular genetics method | 0.764 |  |
| 3031888 | t(14;18)(q32;q21.3)(IGH,BCL2) fusion transcript major break points [Presence] in Bone marrow by Molecular genetics method | 0.762 |  |
| 1260013 | Apolipoprotein E phenotype [Identifier] in Plasma by LC/MS/MS | 0.761 |  |
| 1176451 | LDLR gene full mutation analysis in Blood or Tissue by Sequencing | 0.761 |  |
| 3029715 | Chromosome analysis.interphase [Interpretation] in Bone marrow by FISH Narrative | 0.761 |  |
| 3015816 | F5 gene p.Arg506Gln [Presence] in Blood or Tissue by Molecular genetics method | 0.760 |  |
| 37020111 | FLT3 gene internal tandem duplication/Normal [Ratio] in Blood or Tissue by Molecular genetics method | 0.758 |  |
| 21492159 | IGH gene rearrangements [Presence] in Blood or Tissue by FISH | 0.758 |  |
| 3004674 | Lambda LC gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.758 |  |
| 40762358 | Karyotype [Identifier] in Blood or Tissue by FISH Narrative | 0.758 |  |
| 21492351 | BRCA2 gene mutation analysis limited to known familial mutations in Blood or Tissue by Molecular genetics method | 0.757 |  |
| 3049122 | Sequencing methodology panel - Blood or Tissue by Molecular genetics method | 0.757 |  |
| 1616323 | Hereditary breast and gynecologic cancer multigene analysis in Blood or Tissue by Molecular genetics method | 0.756 |  |
| 1091820 | CD3+HLA-DR+ cells/Lymphocytes in Bronchoalveolar lavage | 0.756 |  |
| 21491542 | DPYD gene product metabolic activity interpretation in Blood or Tissue Qualitative by Molecular genetics method | 0.754 |  |
| 42870546 | LDLR gene mutation analysis limited to known familial mutations in Blood or Tissue by Molecular genetics method | 0.754 |  |
| 3040586 | VWF gene.p.Arg854Gln [Presence] in Blood or Tissue by Molecular genetics method | 0.753 |  |
| 1091457 | DPYD Activity Score in Blood or Tissue | 0.752 |  |
| 3030128 | t(14;18)(q32;q21.3)(IGH,BCL2) fusion transcript minor break points [Presence] in Bone marrow by Molecular genetics method | 0.752 |  |
| 1470025 | CD3+CD4+ (T4 helper) cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.751 |  |
| 40759871 | APOB gene+LDLR gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.751 |  |
| 42870547 | LDLR gene deletion and duplication mutation analysis in Blood or Tissue by MLPA | 0.750 |  |
| 3017829 | Kappa LC gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.749 |  |
| 36032270 | Cell count and Differential panel - Sputum by Manual count | 0.748 |  |
| 36031944 | SARS-CoV-2 (COVID-19) specific TCRB gene rearrangements [Presence] in Blood by Sequencing | 0.748 |  |
| 40771054 | APOB+LDLR+PCSK9 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.747 |  |
| 43055276 | NPM1 gene c.956dupTCTG transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.746 |  |
| 42870302 | Y chromosome AZFb region deletion [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.746 |  |
| 1469804 | Lymphocytes/Cells in Bronchoalveolar lavage | 0.746 |  |
| 42870303 | Y chromosome AZFc region deletion [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.746 |  |
| 1616983 | Plasma cell proliferation analysis in Bone marrow by FISH | 0.745 |  |
| 3049172 | Sequence variation panel - Blood or Tissue by Molecular genetics method | 0.744 |  |
| 40759999 | TCRB gene+TCRD gene+TCRG gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.743 |  |
| 36660362 | BRCA1+BRCA2 gene deletion+duplication and full mutation analysis in Blood or Tissue by Molecular genetics method | 0.742 |  |
| 1617394 | Apolipoprotein E phenotype [Identifier] in Cerebral spinal fluid | 0.742 |  |
| 3042108 | Pharmacogenetic analysis report Document | 0.741 |  |
| 3049538 | Subtelomere analysis [Identifier] in Blood or Tissue by FISH Nominal | 0.741 |  |
| 43055275 | NPM1 gene c.960insCATG transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.740 |  |
| 42870301 | Y chromosome AZFa region deletion [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.740 |  |
| 43055274 | NPM1 gene c.960insCCTG transcript/control transcript [# Ratio] in Blood or Tissue by Molecular genetics method | 0.740 |  |
| 1988274 | Cells Counted Total [#] in Bronchoalveolar lavage | 0.740 |  |
| 1176291 | B-cell phenotyping panel - Blood | 0.740 |  |
| 3008423 | TCRB gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.738 |  |
| 43055139 | VKORC1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.738 |  |
| 1616537 | Hereditary cancer multigene analysis in Blood or Tissue by Molecular genetics method | 0.737 |  |
| 21492572 | FISH probe target gene [Identifier] in Laboratory device | 0.736 |  |
| 44816902 | t(15;17)(q24.1;q21.1)(PML,RARA) fusion transcript [Presence] in Bone marrow by Molecular genetics method | 0.736 |  |
| 40765089 | Chromosome analysis panel - Blood by G-banded | 0.736 |  |
| 3034599 | Y chromosome deletion [Identifier] in Blood or Tissue Nominal | 0.735 |  |
| 3046867 | Alpha 1 antitrypsin phenotype [Interpretation] in Serum or Plasma | 0.735 |  |
| 3040429 | SOD1 gene allele 1 [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.735 |  |
| 3045788 | Cell count panel - Pleural fluid | 0.735 |  |
| 3964908 | in Blood or Tissue by FISH | 0.735 |  |
| 1092115 | Hereditary thrombosis disorders multigene analysis in Blood by Molecular genetics method | 0.734 |  |
| 3005580 | BRCA1 gene.c.185 del AG [presence] in Blood or Tissue by Molecular genetics method | 0.733 |  |
| 1092254 | CD3+CD25+ cells/Lymphocytes in Bronchoalveolar lavage | 0.733 |  |
| 40758370 | HBB gene c.19G>A [Presence] in Blood by Molecular genetics method | 0.732 |  |
| 3965536 | Acute myeloid leukemia minimal residual disease in Bone marrow by Flow cytometry (FC) Narrative | 0.731 |  |
| 1259666 | TCL-1A gene rearrangements in Bone marrow by FISH | 0.731 |  |
| 3964769 | Acute myeloid leukemia panel - Blood or Tissue by FISH | 0.730 |  |
| 649098 | B-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.729 |  |
| 3038980 | VWF gene.p.Thr791Met [Presence] in Blood by Molecular genetics method | 0.728 |  |
| 645216 | T-ALL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.728 |  |
| 40758371 | HBB gene c.20A>T [Presence] in Blood by Molecular genetics method | 0.728 |  |
| 40758369 | HBB gene c.251G>A [Presence] in Blood by Molecular genetics method | 0.728 |  |
| 1002100 | ABO and Rh group post hematopoietic stem cell transplant panel - Blood | 0.728 |  |
| 1469794 | CD3+CD8+ (T8 suppressor) cells/Lymphocytes in Bronchoalveolar lavage by Flow cytometry (FC) | 0.727 |  |
| 3030834 | Platelet genotype [Identifier] in Blood | 0.726 |  |
| 1761572 | NUDT15 gene c.52G>A [Presence] in Blood by Molecular genetics method | 0.725 |  |
| 43055134 | VKORC1 gene c.1173C>T [Presence] in Blood or Tissue by Molecular genetics method | 0.725 |  |
| 3965372 | Myeloid sarcoma analysis in Blood or Tissue by FISH | 0.724 |  |
| 1469516 | Myelodysplastic neoplasm chromosome analysis in Blood or Marrow by FISH | 0.724 |  |
| 3033034 | Cytology report of Bronchoalveolar lavage Cyto stain | 0.723 |  |
| 40757582 | CYP2C9 and VKORC1 [Interpretation] in Blood or Tissue by Molecular genetics method Narrative | 0.723 |  |
| 40765112 | FISH probe locus [Identifier] in Laboratory device | 0.721 |  |
| 3964652 | VKORC1 gene allele [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.721 |  |
| 3040906 | PLP1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.721 |  |
| 3038231 | PYGM gene p.Arg50Ter+Gly205Ser [Presence] in Blood or Tissue by Molecular genetics method | 0.721 |  |
| 3002832 | BRCA1 gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.721 |  |
| 40759888 | Lymphocytes/Leukocytes in Bronchial specimen by Flow cytometry (FC) | 0.720 |  |
| 40758377 | HBB gene c.79G>A [Presence] in Blood by Molecular genetics method | 0.719 |  |
| 40762134 | BRCA1+BRCA2 gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.719 |  |
| 3000360 | BRCA1 gene c.5382insC [Presence] in Blood or Tissue by Molecular genetics method | 0.718 |  |
| 43534060 | CYP2D6 gene and CYP2C19 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.718 |  |
| 40758367 | HBA2 gene c.429A>T [Presence] in Blood by Molecular genetics method | 0.718 |  |
| 3043969 | HADHA gene c.1528G>C [Presence] in Blood or Tissue by Molecular genetics method | 0.718 |  |
| 40765111 | FISH probe gene name [Identifier] in Laboratory device | 0.717 |  |
| 648479 | CLL minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.716 |  |
| 40759286 | CYP2C9 gene allele 3 [Identifier] in Blood by Molecular genetics method Nominal | 0.716 |  |
| 40763541 | NPHP1 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.715 |  |
| 1989116 | Hereditary thrombocytopenia multigene analysis in Blood or Tissue by Molecular genetics method | 0.714 |  |
| 40758373 | HPFH-6 gene [Presence] in Blood by Molecular genetics method | 0.713 |  |
| 3053340 | Alpha 1 antitrypsin phenotype [Interpretation] in Serum or Plasma Narrative | 0.713 |  |
| 1002351 | Plasma cell DNA content and proliferation panel - Bone marrow by Flow cytometry (FC) | 0.713 |  |
| 3039940 | UGT1A1 gene allele 1 [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.713 |  |
| 36660048 | Chromosome region 14q32 rearrangements in Bone marrow by FISH | 0.713 |  |
| 1002327 | Warfarin response genotype panel - Blood or Tissue by Molecular genetics method | 0.713 |  |
| 3031916 | CPT2 gene p.Arg631Cys [Presence] in Blood by Molecular genetics method | 0.712 |  |
| 3046258 | 19q chromosome deletion [Presence] in Blood or Tissue by Molecular genetics method | 0.711 |  |
| 36659883 | EPHX1 gene.c.416A>G [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.711 |  |
| 3052061 | Genechip ID [Identifier] in Blood or Tissue by Molecular genetics method | 0.710 |  |
| 46236301 | C9orf72 gene GGGGCC repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.710 |  |
| 1469835 | Neutrophils/Cells in Bronchoalveolar lavage | 0.710 |  |
| 3044667 | GNE gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.710 |  |
| 21492681 | FISH probe target locus [Identifier] in Laboratory device | 0.709 |  |
| 3050171 | NCF1 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.709 |  |
| 3038435 | SOD1 gene allele 2 [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.707 |  |
| 3040425 | VWF gene p.Arg816Trp [Presence] in Blood or Tissue by Molecular genetics method | 0.707 |  |
| 3038620 | NAGS gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.707 |  |
| 3043308 | 1p chromosome deletion [Presence] in Blood or Tissue by Molecular genetics method | 0.707 |  |
| 36031192 | ABL1 gene c.944C>T [Presence] in Blood or Marrow by Molecular genetics method | 0.706 |  |
| 21493868 | CYP3A4 and CYP3A5 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.706 |  |
| 40762140 | F5 gene p.His1299Arg [Presence] in Blood or Tissue by Molecular genetics method | 0.706 |  |
| 46236486 | CLRN1 gene c.144T>G [Presence] in Blood or Tissue by Molecular genetics method | 0.705 |  |
| 37019535 | Polyclonal plasma cells [#] in Bone marrow by Flow cytometry (FC) | 0.705 |  |
| 3045008 | CASR gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.705 |  |
| 3053260 | Genechip version [Identifier] in Blood or Tissue by Molecular genetics method | 0.704 |  |
| 3051861 | Differential panel - Bone marrow | 0.703 |  |
| 3051038 | Chromosome [Identifier] in Blood or Tissue by Molecular genetics method | 0.703 |  |
| 40762031 | LCT gene mutations found [Type] in Blood or Tissue by Molecular genetics method | 0.702 |  |
| 36303264 | APOB gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.702 |  |
| 3006041 | Apolipoprotein E4 [Presence] in Blood | 0.702 |  |
| 1259870 | ABCG2 gene.p.Q141K [Presence] in Blood or Tissue by Molecular genetics method | 0.702 |  |
| 21493567 | CYP2C9 gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.702 |  |
| 1001970 | Monotypic plasma cell identification and risk stratification panel - Bone marrow by Molecular genetics method | 0.701 |  |
| 3049539 | Genetic diseases [Identifier] in Blood or Tissue by FISH Nominal | 0.700 |  |
| 649095 | Lymphocyte subset [Identifier] in Blood or Tissue by Molecular genetics method | 0.700 |  |
| 1259483 | Plasma cell myeloma multigene analysis in Bone marrow by Molecular genetics method | 0.700 |  |
| 648549 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Bone marrow by Flow cytometry (FC) Narrative | 0.700 |  |
| 3965853 | B-Cell lymphoblastic leukemia monitoring minimal residual disease detection in Blood or Marrow by Flow cytometry (FC) | 0.699 |  |
| 1259824 | UGT1A1 gene.p.P229Q [Presence] in Blood or Tissue by Molecular genetics method | 0.697 |  |
| 3051704 | Genechip kit panel - Blood or Tissue by Molecular genetics method | 0.697 |  |
| 3038762 | Genetic disease DNA analysis panel | 0.696 |  |
| 40765110 | FISH probe name panel - Laboratory device | 0.695 |  |
| 3041430 | GLA gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.695 |  |
| 37020678 | F13A1 and F13B gene full mutation analysis in Blood or Tissue by Sequencing | 0.694 |  |
| 21493139 | C9orf72 gene GGGGCC repeat analysis in Blood or Tissue by Molecular genetics method | 0.694 |  |
| 40765088 | Chromosome analysis.prenatal panel by FISH | 0.694 |  |
| 3031259 | GALT gene allele 1 [Presence] in Blood by Molecular genetics method | 0.693 |  |
| 21495008 | Discrete genetic variant panel | 0.693 |  |
| 3048571 | Activated protein C resistance panel - Platelet poor plasma | 0.692 |  |
| 3966320 | B-cell lymphoma chromosome analysis in Tissue by FISH | 0.692 |  |
| 40765090 | Chromosome analysis panel - Blood from Fetus by G-banded | 0.692 |  |
| 3048879 | Bone marrow aspiration report | 0.692 |  |
| 40766217 | Epithelial cells.squamous [Presence] in Bronchoalveolar lavage | 0.692 |  |
| 46236024 | Chromosome analysis basic associated observations panel - Blood or Tissue by Cytogenetics | 0.692 |  |
| 648844 | B-ALL minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.691 |  |
| 40765130 | Chromosome analysis master panel | 0.691 |  |
| 37020157 | THBD gene full mutation analysis in Blood or Tissue by Sequencing | 0.691 |  |
| 21494571 | CNBP gene CCTG repeat analysis in Blood or Tissue by Molecular genetics method | 0.690 |  |
| 3052324 | Genechip manufacturer ID [Identifier] in Blood or Tissue by Molecular genetics method | 0.690 |  |
| 3031118 | GALT gene allele 2 [Presence] in Blood by Molecular genetics method | 0.690 |  |
| 1001565 | NOP56 gene GGCCTG repeats [Presence] in Blood or Tissue by Molecular genetics method | 0.690 |  |
| 40770392 | Thromboelastography panel - Blood | 0.689 |  |
| 1988760 | Siderocytes panel - Blood or Marrow by Prussian blue stain | 0.689 |  |
| 3017962 | TCRG gene rearrangements [Presence] in Blood or Tissue by Molecular genetics method | 0.688 |  |
| 21494446 | Chromosome region Xp22.33 AndOr Yp11.32 deletion and duplication mutation analysis in Blood or Tissue by MLPA | 0.687 |  |
| 37020870 | LPA gene.c.3947+467T>C [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.687 |  |
| 44786878 | Immunohistochemical stains in Bone marrow Narrative | 0.687 |  |
| 40758363 | Alpha thalassemia gene panel - Blood by Molecular genetics method | 0.686 |  |
| 1091607 | Hereditary platelet function defect multigene analysis in Blood by Molecular genetics method | 0.686 |  |
| 42528767 | Chromosome painting analysis in Blood or Tissue by FISH | 0.686 |  |
| 1988986 | Epithelial cells [Presence] in Bronchoalveolar lavage by Light microscopy | 0.686 |  |
| 1761870 | Platelet disorders multigene analysis in Blood or Tissue by Sequencing | 0.685 |  |
| 40766218 | Epithelial cells.ciliated [Presence] in Bronchoalveolar lavage | 0.685 |  |
| 1469867 | Monocytes/Cells in Bronchoalveolar lavage | 0.684 |  |
| 1469704 | Measurable residual disease analysis in Specimen Qualitative by Sequencing | 0.684 |  |
| 36659869 | Psychotropic medication pharmacogenomic analysis in Blood or Tissue by Molecular genetics method | 0.684 |  |
| 46236023 | DNA analysis discrete sequence variation basic associated observations panel - Blood or Tissue by Molecular genetics method | 0.682 |  |
| 40762018 | LCT gene mutations tested for in Blood or Tissue by Molecular genetics method Nominal | 0.681 |  |
| 37020890 | LPA gene.c.5673A>G [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.681 |  |
| 647799 | T-ALL minimal residual disease detection in Blood by Flow cytometry (FC) Narrative | 0.681 |  |
| 3041491 | F9 gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.680 |  |
| 37020295 | Plasma cells with abnormal marker pattern [#] in Bone marrow by Flow cytometry (FC) | 0.678 |  |
| 3029862 | FXN gene allele 1.GAA repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.677 |  |
| 21492986 | Master HL7 genetic variant reporting panel | 0.677 |  |
| 44786880 | Cytochemical stains in Bone marrow Narrative | 0.675 |  |
| 3017365 | G6PD gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.674 |  |
| 3049082 | CYP2C9 gene allele [Genotype] in Blood or Tissue by Molecular genetics method Nominal | 0.674 |  |
| 3028968 | FXN gene allele 2.GAA repeats [Entitic number] in Blood or Tissue by Molecular genetics method | 0.673 |  |
| 40761555 | Subtelomere analysis [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.673 |  |
| 36659661 | MLYCD gene deletion+duplication and full mutation analysis in Blood or Tissue by Molecular genetics method | 0.673 |  |
| 21493620 | SRY gene deletion in Blood or Tissue by FISH | 0.672 |  |
| 3032311 | GALT gene mutations found [Identifier] in Blood or Tissue by Molecular genetics method Nominal | 0.672 |  |
| 40758365 | HBA2 gene alpha 4.2kb deletion [Presence] in Blood by Molecular genetics method | 0.671 |  |
| 1092212 | Cells.recipient derived/Cells in Blood or Tissue by Molecular genetics method --post stem cell transplant | 0.670 |  |
| 40760874 | Microscopic exam [Interpretation] of Bone marrow by Cytology | 0.669 |  |
| 37020063 | Plasma cells [#] in Bone marrow by Flow cytometry (FC) | 0.667 |  |
| 648776 | Combined humoral and cell-mediated immunodeficiency multigene analysis in Blood or Tissue by Molecular genetics method | 0.667 |  |
| 36305535 | Cytomegalovirus DNA [Presence] in Bone marrow by NAA with probe detection | 0.666 |  |
| 1469682 | Chromosome analysis in Blood by Microarray | 0.666 |  |
| 1002183 | Plasma cells monotypic population [Identifier] in Bone marrow by Flow cytometry (FC) | 0.665 |  |
| 3966008 | Cell-free DNA.donor/Cell-free DNA.total in Blood by Sequencing --post transplant | 0.663 |  |
| 36660321 | carBAMazepine hypersensitivity genotype panel - Blood or Tissue | 0.660 |  |
| 36659662 | Chromosome rearrangement [Identifier] in Blood or Tissue by Molecular genetics method Narrative | 0.656 |  |
| 3031750 | Smear morphology panel - Blood | 0.655 |  |
| 3034277 | Telomere analysis [Identifier] in Blood or Tissue Nominal | 0.651 |  |

## The rows

| row_id | TEST_NAME | UNIT | unit_share | evidence_level | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1611 | -ctr-d |  | 100% | name | 115 | 100 |  |  |  | DNA test |  |
| 1612 | -fishhyb | form | 22% | name+unit | 48 | 100 |  |  |  |  | FISH analysis [Identifier] in Tissue by FISH |
| 1613 | -fishhyb |  | 78% | name | 174 | 100 |  |  |  |  | FISH analysis [Identifier] in Tissue by FISH |
| 1614 | b-apoe-d |  | 100% | name | 146 | 100 |  | B -Apolipoproteiini E, DNA-tutkimus | Blood | DNA test | Apolipoprotein E gene genotype [Identifier] in Blood by Molgen |
| 1615 | b-aso2-qd |  | 100% | name | 102 | 100 |  |  | Blood |  |  |
| 1616 | b-atrytyd | form | 2% | name+unit | 7 | 100 |  | B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus | Blood |  | Alpha-1-antitrypsin genotype [Identifier] in Blood by Molgen |
| 1617 | b-atrytyd |  | 98% | name | 283 | 100 |  | B -Alfa-1-antitrypsiinin genotyypitys, DNA-tutkimus | Blood |  | Alpha-1-antitrypsin genotype [Identifier] in Blood by Molgen |
| 1618 | b-auria10 |  | 100% | name | 1807 | 100 |  |  | Blood |  |  |
| 1619 | b-bcr-qr | form | 9% | name+unit | 159 | 100 |  | B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Blood |  | BCR gene/ABL1 gene fusion transcript [# Ratio] in Blood by NAA |
| 1620 | b-bcr-qr |  | 91% | name | 1562 | 100 |  | B -BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Blood |  | BCR gene/ABL1 gene fusion transcript [# Ratio] in Blood by NAA |
| 1621 | b-blapcr |  | 100% | name | 138 | 100 |  |  | Blood |  | B-lymphocyte Ig gene rearrangement analysis [Presence] in Blood by PCR |
| 1622 | b-bo3-d |  | 100% | name | 963 | 100 |  |  | Blood | DNA test |  |
| 1623 | b-brcay-d |  | 100% | name | 519 | 100 |  |  | Blood | DNA test | BRCA gene analysis panel - Blood |
| 1624 | b-brovcore |  | 100% | name | 356 | 100 |  |  | Blood |  |  |
| 1625 | b-calr-d |  | 100% | name | 421 | 100 |  |  | Blood | DNA test | CALR gene mutation [Presence] in Blood by Molgen |
| 1626 | b-cmlpcr |  | 100% | name | 553 | 100 |  |  | Blood |  | BCR gene/ABL1 gene fusion transcript [Presence] in Blood by PCR |
| 1627 | b-crco |  | 100% | name | 3627 | 100 |  |  | Blood |  |  |
| 1628 | b-crcoti |  | 100% | name | 1359 | 100 |  |  | Blood |  |  |
| 1629 | b-dm2alld | form | 11% | name+unit | 19 | 100 |  | B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus | Blood |  | ZNF9 gene repeat analysis [Identifier] in Blood by Molgen |
| 1630 | b-dm2alld |  | 89% | name | 149 | 100 |  | B -Dystrofia myotonica tyyppi 2 (DM2), ZNF9-geenin toistojakson alleelikokojen DNA-tutkimus | Blood |  | ZNF9 gene repeat analysis [Identifier] in Blood by Molgen |
| 1631 | b-dpyd-d | form | 6% | name+unit | 211 | 100 |  |  | Blood | DNA test | DPYD gene mutations found [Identifier] in Blood by Molgen |
| 1632 | b-dpyd-d |  | 94% | name | 3111 | 100 |  |  | Blood | DNA test | DPYD gene mutations found [Identifier] in Blood by Molgen |
| 1633 | b-dpydl-d |  | 100% | name | 101 | 100 |  |  | Blood | DNA test | DPYD gene mutation analysis panel - Blood |
| 1634 | b-exkon-d |  | 100% | name | 147 | 100 |  |  | Blood | DNA test |  |
| 1635 | b-extri-d |  | 100% | name | 136 | 100 |  |  | Blood | DNA test |  |
| 1636 | b-farma-d |  | 100% | name | 594 | 100 |  |  | Blood | DNA test | Pharmacogenetics panel - Blood |
| 1637 | b-farml-d |  | 100% | name | 190 | 100 |  |  | Blood | DNA test | Pharmacogenetics extensive panel - Blood |
| 1638 | b-fii-d | form | 2% | name+unit | 138 | 100 |  | B -Protrombiinigeeni, DNA-tutkimus | Blood | DNA test | Prothrombin gene.G20210A mut [Presence] in Blood by Molgen |
| 1639 | b-fii-d |  | 98% | name | 7712 | 100 |  | B -Protrombiinigeeni, DNA-tutkimus | Blood | DNA test | Prothrombin gene.G20210A mut [Presence] in Blood by Molgen |
| 1640 | b-finngen |  | 100% | name | 736 | 100 |  |  | Blood |  |  |
| 1641 | b-fishhem |  | 100% | name | 130 | 100 |  | B -Hematologinen fluoresenssi in situ hybridisaatio, veri | Blood |  | FISH analysis panel for hematologic disorders - Blood |
| 1642 | b-frax-d | form | 1% | name+unit | 5 | 100 |  | B -Fragiili-X,-FMR1-geenin DNA-tutkimus | Blood | DNA test | FMR1 gene repeat analysis [Identifier] in Blood by Molgen |
| 1643 | b-frax-d |  | 99% | name | 347 | 100 |  | B -Fragiili-X,-FMR1-geenin DNA-tutkimus | Blood | DNA test | FMR1 gene repeat analysis [Identifier] in Blood by Molgen |
| 1644 | b-fuus-mr | form | 13% | name+unit | 26 | 100 |  |  | Blood |  |  |
| 1645 | b-fuus-mr |  | 87% | name | 177 | 100 |  |  | Blood |  |  |
| 1646 | b-fv-d | form | 2% | name+unit | 139 | 100 |  | B -Hyytymistekijä V geeni, DNA-tutkimus | Blood | DNA test | Coagulation factor V gene.R506Q mut [Presence] in Blood by Molgen |
| 1647 | b-fv-d |  | 98% | name | 8156 | 100 |  | B -Hyytymistekijä V geeni, DNA-tutkimus | Blood | DNA test | Coagulation factor V gene.R506Q mut [Presence] in Blood by Molgen |
| 1648 | b-fvfii-d | form | 6% | name+unit | 52 | 100 |  |  | Blood | DNA test | Thrombophilia DNA mutation analysis panel - Blood |
| 1649 | b-fvfii-d |  | 94% | name | 765 | 100 |  |  | Blood | DNA test | Thrombophilia DNA mutation analysis panel - Blood |
| 1650 | b-hfe-d |  | 100% | name | 730 | 100 |  | B -Periytyvään hemokromatoosiin liittyvien HFE-geenin valtamutaatioiden tutkimus | Blood | DNA test | HFE gene mutations found [Identifier] in Blood by Molgen |
| 1651 | b-hnpcy-d |  | 100% | name | 175 | 100 |  | B -Periytyvä ei-polypoottinen paksusuolisyöpä (HNPCC), MLH1-, MSH2- tai MSH6-geenin yksittäisen mutaation DNA-tutkimus | Blood | DNA test | MLH1+MSH2+MSH6 gene targeted mutation analysis [Presence] in Blood by Molgen |
| 1652 | b-jak2-d | form | 2% | name+unit | 139 | 100 |  | B -JAK2-geenin mutaatio, DNA-tutkimus | Blood | DNA test | JAK2 gene.V617F mut [Presence] in Blood by Molgen |
| 1653 | b-jak2-d |  | 98% | name | 5494 | 100 |  | B -JAK2-geenin mutaatio, DNA-tutkimus | Blood | DNA test | JAK2 gene.V617F mut [Presence] in Blood by Molgen |
| 1654 | b-kim-d |  | 100% | name | 197 | 100 |  |  | Blood | DNA test | Chimerism analysis [Identifier] in Blood by Molgen |
| 1655 | b-kim-fd |  | 100% | name | 1367 | 100 |  |  | Blood |  | Post-transplant chimerism analysis panel - Blood |
| 1656 | b-kml-qr |  | 100% | name | 1809 | 100 |  |  | Blood |  | BCR gene/ABL1 gene fusion transcript [# Ratio] in Blood by NAA |
| 1657 | b-lakt-d | form | 0% | name+unit | 18 | 77.78 |  | B -Laktoosi-intoleranssi, DNA-tutkimus | Blood | DNA test | Lactase gene genotype [Identifier] in Blood by Molgen |
| 1658 | b-lakt-d |  | 100% | name | 27791 | 100 |  | B -Laktoosi-intoleranssi, DNA-tutkimus | Blood | DNA test | Lactase gene genotype [Identifier] in Blood by Molgen |
| 1659 | b-ldlre-4 | form | 28% | name+unit | 53 | 100 |  |  | Blood |  |  |
| 1660 | b-ldlre-4 |  | 72% | name | 135 | 100 |  |  | Blood |  |  |
| 1661 | b-ldlre-d |  | 100% | name | 1121 | 100 |  | B -LDL-reseptorigeenin mutaatio, DNA-tutkimus | Blood | DNA test | LDLR gene mutation [Presence] in Blood by Molgen |
| 1662 | b-ngs-d |  | 100% | name | 277 | 100 |  |  | Blood | DNA test | Next generation sequencing panel - Blood |
| 1663 | b-nphs1-d |  | 100% | name | 272 | 100 |  | B -Kongenitaali nefroosi (CNF), kahden NPHS1-geenin valtamutaation DNA-tutkimus | Blood | DNA test | NPHS1 gene targeted mutations [Identifier] in Blood by Molgen |
| 1664 | b-pgx-d |  | 100% | name | 2778 | 100 |  |  | Blood | DNA test | Pharmacogenetics panel - Blood |
| 1665 | b-sekvy-d | form | 4% | name+unit | 59 | 100 |  |  | Blood | DNA test |  |
| 1666 | b-sekvy-d |  | 96% | name | 1268 | 100 |  |  | Blood | DNA test |  |
| 1667 | b-tp53-d |  | 100% | name | 211 | 100 |  |  | Blood | DNA test | TP53 gene mutations found [Identifier] in Blood by Molgen |
| 1668 | b-tpmt-d | form | 5% | name+unit | 30 | 100 |  |  | Blood | DNA test | TPMT gene mutations found [Identifier] in Blood by Molgen |
| 1669 | b-tpmt-d |  | 95% | name | 615 | 100 |  |  | Blood | DNA test | TPMT gene mutations found [Identifier] in Blood by Molgen |
| 1670 | b-varfa-d |  | 100% | name | 643 | 100 |  | B -Varfariinin yksilölliseen annostukseen liittyvät VKORC1- ja CYP2C9-geenivariaatiot, DNA-tutkimus verestä | Blood | DNA test | VKORC1 gene and CYP2C9 gene panel - Blood |
| 1671 | b-ykrom-d | form | 5% | name+unit | 7 | 100 |  | B -Y-kromosomin poikkeavuuksia | Blood | DNA test | Y chromosome microdeletions analysis [Presence] in Blood by Molgen |
| 1672 | b-ykrom-d |  | 95% | name | 142 | 100 |  | B -Y-kromosomin poikkeavuuksia | Blood | DNA test | Y chromosome microdeletions analysis [Presence] in Blood by Molgen |
| 1673 | bl-bal |  | 100% | name | 919 | 100 |  | Bl-Bronkoalveolaarinen lavaationäyte sairaalakohtainen ryhmätutkimus, jonka sisältö vaihtelee | Bronchoalveolar lavage |  | Bronchoalveolar lavage fluid analysis panel - Bronchoalveolar lavage fluid |
| 1674 | bl-bal-1 |  | 100% | name | 3636 | 100 |  | Bl-Bronkoalveolaarinen huuhtelunäyte, solututkimus | Bronchoalveolar lavage |  | Leukocyte differential count panel - Bronchoalveolar lavage fluid |
| 1675 | bl-balfc |  | 100% | name | 397 | 100 |  |  | Bronchoalveolar lavage |  | Flow cytometry immunophenotyping panel - Bronchoalveolar lavage fluid |
| 1676 | bm-aso-qd |  | 100% | name | 224 | 100 |  |  | Bone marrow |  |  |
| 1677 | bm-aso2-qd | form | 1% | name+unit | 6 | 100 |  |  | Bone marrow |  |  |
| 1678 | bm-aso2-qd |  | 99% | name | 511 | 100 |  |  | Bone marrow |  |  |
| 1679 | bm-aspir |  | 100% | name | 1994 | 98.65 |  |  | Bone marrow |  | Microscopic observation [Identifier] in Bone marrow aspirate by Light microscopy |
| 1680 | bm-bcr-qr |  | 100% | name | 152 | 100 |  | Bm-BCR-ABL1 -geenien fuusio-RNA: t(9:22), (kvant) | Bone marrow |  | BCR gene/ABL1 gene fusion transcript [# Ratio] in Bone marrow by NAA |
| 1681 | bm-blapcr |  | 100% | name | 753 | 100 |  |  | Bone marrow |  | B-lymphocyte Ig gene rearrangement analysis [Presence] in Bone marrow by PCR |
| 1682 | bm-bpvalm |  | 100% | name | 145 | 100 |  |  | Bone marrow |  |  |
| 1683 | bm-fish | form | 5% | name+unit | 48 | 100 |  |  | Bone marrow |  | FISH analysis [Identifier] in Bone marrow by FISH |
| 1684 | bm-fish |  | 95% | name | 943 | 100 |  |  | Bone marrow |  | FISH analysis [Identifier] in Bone marrow by FISH |
| 1685 | bm-fish-mm |  | 100% | name | 127 | 100 |  |  | Bone marrow |  | Multiple myeloma FISH panel - Bone marrow |
| 1686 | bm-fish2 | form | 26% | name+unit | 29 | 100 |  |  | Bone marrow |  |  |
| 1687 | bm-fish2 |  | 74% | name | 81 | 100 |  |  | Bone marrow |  |  |
| 1688 | bm-fishhem | form | 2% | name+unit | 7 | 100 |  | Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin | Bone marrow |  | FISH analysis panel for hematologic disorders - Bone marrow |
| 1689 | bm-fishhem |  | 98% | name | 414 | 100 |  | Bm-Hematologinen fluoresenssi in situ hybridisaatio, luuydin | Bone marrow |  | FISH analysis panel for hematologic disorders - Bone marrow |
| 1690 | bm-fishmm | form | 16% | name+unit | 28 | 100 |  |  | Bone marrow |  | Multiple myeloma FISH panel - Bone marrow |
| 1691 | bm-fishmm |  | 84% | name | 147 | 100 |  |  | Bone marrow |  | Multiple myeloma FISH panel - Bone marrow |
| 1692 | bm-fishvar |  | 100% | name | 141 | 100 |  |  | Bone marrow |  |  |
| 1693 | bm-flt3-d | form | 6% | name+unit | 9 | 100 |  |  | Bone marrow | DNA test | FLT3 gene mutation analysis [Identifier] in Bone marrow by Molgen |
| 1694 | bm-flt3-d |  | 94% | name | 138 | 100 |  |  | Bone marrow | DNA test | FLT3 gene mutation analysis [Identifier] in Bone marrow by Molgen |
| 1695 | bm-fuus-mr | form | 5% | name+unit | 14 | 100 |  |  | Bone marrow |  |  |
| 1696 | bm-fuus-mr |  | 95% | name | 268 | 100 |  |  | Bone marrow |  |  |
| 1697 | bm-fuus-qr | form | 21% | name+unit | 21 | 100 |  |  | Bone marrow |  |  |
| 1698 | bm-fuus-qr |  | 79% | name | 81 | 100 |  |  | Bone marrow |  |  |
| 1699 | bm-mgg |  | 100% | name | 314 | 100 |  |  | Bone marrow |  | Microscopic observation [Identifier] in Bone marrow aspirate by MGG stain |
| 1700 | bm-mggfe | form | 5% | name+unit | 660 | 100 |  | Bm-Luuydintutkimus, MGG- ja rautavärjäys | Bone marrow |  | Bone marrow aspirate morphology and iron stain panel - Bone marrow |
| 1701 | bm-mggfe |  | 95% | name | 11527 | 100 |  | Bm-Luuydintutkimus, MGG- ja rautavärjäys | Bone marrow |  | Bone marrow aspirate morphology and iron stain panel - Bone marrow |
| 1702 | bm-mm-ift |  | 100% | name | 651 | 100 |  |  | Bone marrow |  | Multiple myeloma immunophenotyping panel - Bone marrow |
| 1703 | bm-mmpcr |  | 100% | name | 128 | 100 |  |  | Bone marrow |  | IgH gene rearrangement analysis [Presence] in Bone marrow by PCR |
| 1704 | bm-morflkl |  | 100% | name | 278 | 100 |  |  | Bone marrow |  |  |
| 1705 | bm-mrd-all |  | 100% | name | 416 | 100 |  |  | Bone marrow |  | Minimal residual disease for ALL panel - Bone marrow |
| 1706 | bm-mrd-vs |  | 100% | name | 666 | 100 |  |  | Bone marrow |  | Minimal residual disease panel - Bone marrow |
| 1707 | bm-mrdmut |  | 100% | name | 198 | 100 |  |  | Bone marrow |  | Minimal residual disease [Presence] in Bone marrow by NAA |
| 1708 | bm-npm1-qd | form | 11% | name+unit | 23 | 100 |  |  | Bone marrow |  | NPM1 gene mutation [Presence] in Bone marrow by Molgen |
| 1709 | bm-npm1-qd |  | 89% | name | 182 | 100 |  |  | Bone marrow |  | NPM1 gene mutation [Presence] in Bone marrow by Molgen |

