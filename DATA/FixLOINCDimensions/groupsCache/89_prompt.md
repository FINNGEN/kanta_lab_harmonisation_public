[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass looked at each of these local Finnish lab codes and **guessed** the LOINC Long Common Name it thought the code should have. Those guesses are not real LOINC concepts — they are what a reader of the Finnish code would expect LOINC to call the test.

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
- `n_codes` / `n_events` — how many curated Finnish lab codes already map to this concept, and how many records those codes cover. This is usage in Finland.

**The rows table** — one row per local lab test/unit combination:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available. The strongest single piece of evidence for what a test really measures and in which units: a "sodium" code whose deciles read 0.32-0.40 is not sodium in mmol/l.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `loinc_name_guess` — the earlier pass's guess. A hypothesis to test against the row's own evidence, not an instruction.
- `is_panel` — whether the earlier pass judged the code to order a bundle of tests rather than report one result.

# How to decide

For each row:

1. **Re-read the row's own evidence first** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix and suffix meanings. Decide what the test measures, in what specimen, reported as what kind of quantity. Do this before you look at the guess, so a wrong guess cannot anchor you.
2. **Pick the candidate that matches that reading**, and return its `omop_concept_id`. The unit and the deciles decide between candidates that differ only in property: `mmol/l` takes `[Moles/volume]`, `g/l` takes `[Mass/volume]`, `U/l` takes `[Enzymatic activity/volume]`. The prefix decides the specimen; remember that LOINC's `Serum or Plasma` is the right term for most routine chemistry, and that fasting is not part of the specimen (`fS` is still serum).
3. **When two or more candidates fit the evidence equally well**, break the tie in this order:
   1. **Prefer a candidate with a `top2000` rank.** That list is LOINC's own recommendation for what laboratories should map to, so a concept on it is the intended target and a near-duplicate off it usually is not.
   2. **Then prefer the higher `n_codes` / `n_events`.** Finland already maps real codes to that concept; matching established national usage keeps this data joinable with what exists.

   These break ties. They never override the row's own evidence: a top-2000 concept in the wrong specimen or the wrong units is still the wrong answer.
4. **Leave `omop_concept_id` empty when no candidate is right.** That is a correct, useful answer — it says "this code has no match in what the search returned", which is a fact the next iteration can act on. Common reasons: the code is too truncated or garbled to identify; it is a local administrative or non-laboratory code; or the search simply did not return the concept you know is right.
5. **Never return an id that is not in the candidate table.** Not one you remember, not one you derive from a LOINC code, not a plausible-looking number. Ids that are not in the table are discarded and the row is logged as unanswered, so inventing one only loses the row.

Specific things to watch:

- **A panel is not its components.** If the code orders a bundle (`B-PVK` = full blood count, `U-KemSeul` = urine dipstick screen), the answer is the panel concept (`CBC panel - Blood by Automated count`), not hemoglobin. Conversely, do not map a single reported result to a panel concept just because a panel candidate scored well.
- **Deprecated near-duplicates are already filtered out** of the candidate list — every candidate is a standard, current concept — so you never need to judge validity, only fit.
- **The same local code recurs in a group with different `UNIT`s**, and those rows are often genuinely different LOINC concepts. Answer each row from its own unit and deciles; do not give every row of a group the same id out of consistency.
- **Rows whose guess was empty still deserve an answer.** The earlier pass could not name them, but the group's pooled candidates may still contain the right concept.

# Output

Return one entry per input row, with `row_id` echoed exactly, and:

- `omop_concept_id` — the chosen concept's id, copied from the candidate table. Empty if no candidate is right.
- `omop_concept_name` — that candidate's `omop_concept_name`, copied verbatim. Used only to cross-check that the id you copied is the concept you meant; leave it empty when the id is empty.
- `is_panel` — carried through from the input row unless the row is plainly contradictory.

Return an entry for EVERY row, including ones you leave unmapped.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which rows you could map and which you could not, where the candidate list was missing the concept you knew was right, where the earlier pass's guess sent the search astray, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 89.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3029075 | Extractable nuclear Ab panel - Serum | 1.000 |  | 4 |     3,253 |
| 3037467 | Urinalysis macro (dipstick) panel - Urine | 1.000 |  | 6 | 1,393,084 |
| 37019579 | Human papilloma virus DNA [Presence] in Genital specimen by NAA with probe detection | 0.940 |  | 0 |         0 |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 0.911 |  | 0 |         0 |
| 3029511 | Human papilloma virus DNA [Presence] in Specimen by NAA with probe detection | 0.910 |  | 1 |    23,809 |
| 37020661 | Human papilloma virus 16 DNA [Presence] in Genital specimen by NAA with probe detection | 0.909 |  | 0 |         0 |
| 3021257 | Drugs of abuse 5 panel - Urine | 0.899 |  | 0 |         0 |
| 37020511 | Human papilloma virus 18 DNA [Presence] in Genital specimen by NAA with probe detection | 0.893 |  | 0 |         0 |
| 40759269 | Smith extractable nuclear Ab and Ribonucleoprotein extractable nuclear Ab panel - Serum | 0.885 |  | 0 |         0 |
| 40764136 | Human papilloma virus 31 DNA [Presence] in Specimen by NAA with probe detection | 0.884 |  | 0 |         0 |
| 40764157 | Human papilloma virus 56 DNA [Presence] in Specimen by NAA with probe detection | 0.883 |  | 0 |         0 |
| 1176189 | Extractable nuclear antigen Ab.IgG panel - Serum | 0.883 |  | 0 |         0 |
| 40764133 | Human papilloma virus 16 DNA [Presence] in Specimen by NAA with probe detection | 0.882 |  | 0 |         0 |
| 40764156 | Human papilloma virus 42 DNA [Presence] in Specimen by NAA with probe detection | 0.879 |  | 0 |         0 |
| 3043496 | Extractable nuclear Ab [Interpretation] in Serum | 0.877 |  | 0 |         0 |
| 40764144 | Human papilloma virus 53 DNA [Presence] in Specimen by NAA with probe detection | 0.877 |  | 0 |         0 |
| 3027341 | Human papilloma virus rRNA [Presence] in Genital specimen by NAA with probe detection | 0.877 |  | 0 |         0 |
| 3013293 | Extractable nuclear Ab [Presence] in Serum | 0.876 |  | 1 |        20 |
| 40768439 | Drugs of abuse 5 panel - Urine by Screen method | 0.875 |  | 0 |         0 |
| 3005135 | Extractable nuclear Ab [Identifier] in Serum | 0.869 |  | 0 |         0 |
| 646451 | Extractable nuclear Ab [Measurement] in Serum | 0.866 |  | 0 |         0 |
| 40760543 | Extractable nuclear Ab [Presence] in Serum by Immunoblot | 0.861 |  | 3 |     2,898 |
| 40766122 | Extractable nuclear Ab [Presence] in Serum by Immunoassay | 0.858 |  | 0 |         0 |
| 3050129 | First trimester maternal screen panel - Serum or Plasma | 0.839 |  | 1 |    26,783 |
| 43533384 | Drugs of abuse panel - Blood by Screen method | 0.838 |  | 0 |         0 |
| 3023428 | Smith extractable nuclear Ab [Presence] in Serum | 0.836 |  | 0 |         0 |
| 36305828 | Drugs of abuse screen W Reflex confirm panel - Urine | 0.835 |  | 0 |         0 |
| 3029318 | Maternal screen for fetal abnormalities such as Open Neural Tube Defects, Trisomy 21 or Trisomy 18 panel - Serum or Plasma | 0.835 |  | 0 |         0 |
| 1175703 | Drugs of abuse panel - Body fluid | 0.833 |  | 0 |         0 |
| 40758548 | Home drug screening panel - Urine | 0.825 |  | 0 |         0 |
| 3032628 | Second trimester triple maternal screen panel - Serum or Plasma | 0.824 |  | 0 |         0 |
| 1175629 | Drugs of abuse panel - Hair | 0.816 |  | 0 |         0 |
| 3049518 | Second trimester penta maternal screen panel - Serum or Plasma | 0.813 |  | 0 |         0 |
| 3053322 | Second trimester quad maternal screen panel - Serum or Plasma | 0.812 |  | 0 |         0 |
| 3966606 | Prenatal hepatitis B and C panel - Serum or Plasma | 0.808 |  | 0 |         0 |
| 3039059 | Drugs of abuse 7 and Alcohol and Tricyclics panel - Urine by Screen method | 0.804 |  | 0 |         0 |
| 3029361 | Urinalysis dipstick panel - Urine by Automated test strip | 0.800 |  | 0 |         0 |
| 3052990 | Drugs of abuse panel - Meconium | 0.798 |  | 0 |         0 |
| 3048886 | First and Second trimester integrated maternal screen panel | 0.794 |  | 0 |         0 |
| 3033521 | Obstetric 1996 panel - Serum and Blood | 0.793 |  | 0 |         0 |
| 3036941 | Urinalysis complete panel - Urine | 0.792 |  | 0 |         0 |
| 3050402 | First trimester maternal screen with nuchal translucency panel | 0.790 |  | 0 |         0 |
| 3048596 | Maternal screen clinical predictors panel | 0.789 |  | 0 |         0 |
| 3020263 | G Ag [Presence] on Red Blood Cells | 0.785 |  | 0 |         0 |
| 3004588 | Protein electrophoresis panel - Serum or Plasma | 0.782 |  | 1 |    68,293 |
| 3017645 | D Ag [Presence] on Red Blood Cells | 0.781 |  | 0 |         0 |
| 40760139 | Urinalysis dipstick W Reflex Microscopic panel - Urine | 0.780 |  | 0 |         0 |
| 40771499 | Rg Ag [Presence] on Red Blood Cells | 0.780 |  | 0 |         0 |
| 36305936 | Inhibin A and B panel - Serum or Plasma | 0.779 |  | 0 |         0 |
| 43533765 | Newborn hearing screen panel of Ear - left | 0.776 |  | 0 |         0 |
| 36304260 | Rh group Ag [Type] on Red Blood Cells | 0.775 |  | 0 |         0 |
| 3032166 | Volatiles panel - Serum or Plasma | 0.775 |  | 0 |         0 |
| 3033840 | Weak D Ag [Presence] on Red Blood Cells | 0.774 |  | 0 |         0 |
| 43533768 | Newborn hearing screen panel of Ear - right | 0.774 |  | 0 |         0 |
| 3050943 | Newborn hearing screening panel | 0.773 |  | 0 |         0 |
| 3965527 | Cardiovascular risk panel - Serum or Plasma | 0.772 |  | 0 |         0 |
| 1001665 | D variant Ag [Presence] on Red Blood Cells | 0.766 |  | 0 |         0 |
| 3022113 | Urinalysis microscopic panel - Urine sediment | 0.766 |  | 0 |         0 |
| 3005902 | A,B Ag [Presence] on Red Blood Cells | 0.764 |  | 0 |         0 |
| 3035001 | G Ag [Presence] on Red Blood Cells from Donor | 0.764 |  | 0 |         0 |
| 3029396 | Erythrocyte agglutination [Presence] in Blood | 0.763 |  | 2 |     5,038 |
| 3007188 | P1 Ag [Presence] on Red Blood Cells | 0.761 |  | 0 |         0 |
| 3039353 | Urinalysis microscopic panel - Urine Qualitative by Automated | 0.758 |  | 0 |         0 |
| 3049557 | Second trimester penta maternal screen [Interpretation] in Serum or Plasma | 0.755 |  | 0 |         0 |
| 3030688 | Urinalysis panel - Urine by Auto | 0.755 |  | 0 |         0 |
| 3032802 | Second trimester triple maternal screen [Interpretation] in Serum or Plasma Narrative | 0.755 | 1554 | 0 |         0 |
| 1989068 | Visual acuity panel | 0.742 |  | 0 |         0 |
| 646145 | Sexually transmitted blood borne infections panel - Serum by Immunoassay | 0.741 |  | 0 |         0 |
| 3049229 | Second trimester quad maternal screen [Interpretation] in Serum or Plasma Narrative | 0.736 | 644 | 0 |         0 |
| 40760138 | Urinalysis dipstick W Reflex Culture panel - Urine | 0.734 |  | 0 |         0 |
| 1761394 | Routine prenatal assessment panel | 0.717 |  | 0 |         0 |
| 1989469 | Color vision panel | 0.709 |  | 0 |         0 |
| 36305393 | Pure tone air conduction threshold audiometry panel | 0.695 |  | 0 |         0 |
| 3050957 | Infectious diseases newborn screening panel | 0.695 |  | 0 |         0 |
| 1617160 | Diagnostic audiology results panel | 0.692 |  | 0 |         0 |
| 3016782 | Immunoelectrophoresis panel - Serum | 0.691 |  | 0 |         0 |
| 3043821 | Protein and Glucose panel - Urine by Test strip | 0.684 |  | 0 |         0 |
| 3030572 | Parvovirus B19 IgG and IgM panel - Serum | 0.678 |  | 0 |         0 |
| 1001796 | Transfusion reaction panel | 0.678 |  | 0 |         0 |
| 1616467 | Auditory brainstem response panel | 0.678 |  | 0 |         0 |
| 40758292 | HTLV I+II Ab panel - Serum | 0.677 |  | 1 |     1,208 |
| 3043277 | Bacterial Ag panel - Serum | 0.675 |  | 0 |         0 |
| 1988471 | Phoropter panel | 0.669 |  | 0 |         0 |
| 46235952 | HTLV I and II panel - Serum or Plasma by Immunoblot | 0.667 |  | 0 |         0 |
| 1259690 | Tick-borne Ab panel - Serum | 0.666 |  | 0 |         0 |
| 3051564 | Newborn hearing screen of Ear - left | 0.665 | 3000 | 0 |         0 |
| 3030893 | Treponema pallidum IgG and IgM panel - Serum | 0.665 |  | 0 |         0 |
| 1761861 | Pure tone bone conduction threshold audiometry panel | 0.664 |  | 0 |         0 |
| 21491761 | Eye Physical findings panel | 0.662 |  | 0 |         0 |
| 44787052 | MICA IgG panel - Serum | 0.662 |  | 0 |         0 |
| 1002036 | Epstein Barr virus Ab panel - Serum from Donor | 0.661 |  | 0 |         0 |
| 3039460 | Newborn hearing screen method | 0.656 | 3000 | 0 |         0 |
| 3051582 | Newborn hearing screen of Ear - right | 0.654 | 3000 | 0 |         0 |
| 46235673 | Hepatitis A virus RNA and Parvovirus B19 DNA panel - Plasma from Donor by NAA with probe detection | 0.644 |  | 0 |         0 |
| 21491759 | Subjective refraction panel | 0.644 |  | 0 |         0 |
| 1259656 | HLA-DPB1+DPA1 Typing panel - Blood or Tissue from Donor | 0.634 |  | 0 |         0 |
| 1175857 | Donor blood study | 0.630 |  | 0 |         0 |
| 21491762 | Objective refraction panel | 0.630 |  | 0 |         0 |
| 36031790 | HIV 1 RNA+HIV 2 RNA+Hepatitis C virus RNA+Hepatitis B virus DNA [Presence] in Serum, Plasma or Blood from Donor by NAA with probe detection | 0.628 |  | 0 |         0 |
| 1002448 | ABO and Rh group panel - Blood from Blood product unit | 0.626 |  | 0 |         0 |
| 1002100 | ABO and Rh group post hematopoietic stem cell transplant panel - Blood | 0.626 |  | 0 |         0 |
| 1259800 | HLA-ABDR typing panel - Blood or Tissue from Donor | 0.624 |  | 0 |         0 |
| 1259463 | Views screening for diabetic retinopathy of Eyes | 0.612 |  | 0 |         0 |
| 1259934 | Views screening for diabetic retinopathy of Left eye | 0.598 |  | 0 |         0 |
| 1989426 | Specular microscopy panel | 0.588 |  | 0 |         0 |
| 1259699 | Views screening for diabetic retinopathy of Right eye | 0.586 |  | 0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1277 | -hpvseul |  | 3483 | 100 |  | -Papilloomavirus, seulonta |  |  | Human papillomavirus High Risk DNA [Presence] in Genital specimen by NAA with probe detection | FALSE |
| 1278 | hoikemseul |  | 526 | 100 |  |  |  |  |  | FALSE |
| 1279 | hpvseul |  | 402 | 100 |  |  |  |  | Human papillomavirus High Risk DNA [Presence] in Genital specimen by NAA with probe detection | FALSE |
| 1280 | hörsel |  | 112 | 100 |  |  |  |  | Hearing screen panel | TRUE |
| 1281 | luov.seul. |  | 114 | 100 |  |  |  |  | Blood donor screening panel | TRUE |
| 1282 | näköseula |  | 207 | 3.86 | [1, 1, 1, 1, 1, 1, 1, 1, 1] |  |  |  | Vision screen panel | TRUE |
| 1283 | oma-kemseu |  | 242 | 100 |  |  |  |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1284 | oma-kemseula |  | 108 | 100 |  |  |  |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1285 | oma-u-kems |  | 761 | 100 |  |  |  |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1286 | oma-u-kemseul |  | 230 | 100 |  |  |  |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1287 | rhdnegseul |  | 161 | 100 |  |  |  |  | RhD Ag [Presence] in Blood | FALSE |
| 1288 | s-enaseul |  | 1344 | 99.78 |  |  | Serum |  | Extractable nuclear Ab panel - Serum | TRUE |
| 1289 | s-ivfseul |  | 168 | 100 |  |  | Serum |  | Infectious agent screening panel - Serum | TRUE |
| 1290 | s-tr1seul |  | 26880 | 100 |  | S -Sikiön kehityshäiriöiden seulonta, ensimmäinen trimesteri | Serum |  | Maternal screening 1st trimester panel - Serum | TRUE |
| 1291 | s-tr2seul |  | 527 | 100 |  | S -Sikiön kehityshäiriöiden seulonta, toinen trimesteri | Serum |  | Maternal screening 2nd trimester panel - Serum | TRUE |
| 1292 | s-trseul |  | 125 | 100 |  |  | Serum |  | Maternal screening panel - Serum | TRUE |
| 1293 | s-äit-seul |  | 7521 | 100 |  |  | Serum |  | Obstetric panel - Serum or Plasma | TRUE |
| 1294 | s-äit-seula |  | 117 | 100 |  |  | Serum |  | Obstetric panel - Serum or Plasma | TRUE |
| 1295 | s-äitseul |  | 24752 | 100 |  |  | Serum |  | Obstetric panel - Serum or Plasma | TRUE |
| 1296 | u-huseula |  | 2519 | 100 |  |  | Urine |  | Drugs of abuse screen panel - Urine | TRUE |
| 1297 | u-kemseu |  | 15207 | 99.98 |  |  | Urine |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1298 | u-kemseul | form | 1298 | 0 |  | U -Kemiallinen seulonta | Urine |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1299 | u-kemseul | h | 100 | 0 |  | U -Kemiallinen seulonta | Urine |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1300 | u-kemseul |  | 1336031 | 100 | [0, 1.01, 1.01, 1.02, 1.02, 1.02, 4.17, 5.87, 6.26] | U -Kemiallinen seulonta | Urine |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1301 | u-kemseul, |  | 257 | 100 |  |  | Urine |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1302 | u-kemseula |  | 124 | 100 |  |  | Urine |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1303 | u-kemseup |  | 5478 | 99.91 |  |  | Urine |  | Urinalysis macro (dipstick) panel - Urine | TRUE |
| 1304 | äit-seula |  | 210 | 100 |  |  |  |  | Obstetric panel - Serum or Plasma | TRUE |

