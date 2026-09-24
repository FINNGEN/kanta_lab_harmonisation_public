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
Here is group 33.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 3021257 | Drugs of abuse 5 panel - Urine | 1.000 |  |  0 |         0 |
| 3039355 | Methicillin resistant Staphylococcus aureus [Presence] in Nose by Organism specific culture | 0.979 |  |  1 |     1,512 |
| 3019902 | Methicillin resistant Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.965 | 146 |  2 |   145,674 |
| 46235760 | Methicillin resistant Staphylococcus aureus [Presence] in Pharynx by Organism specific culture | 0.935 |  |  1 |     1,445 |
| 40768439 | Drugs of abuse 5 panel - Urine by Screen method | 0.925 |  |  0 |         0 |
| 1761890 | Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.899 |  |  0 |         0 |
| 1091581 | Methicillin resistant Staphylococcus aureus [Presence] in Skin by Organism specific culture | 0.892 |  |  0 |         0 |
| 3050898 | Methicillin resistant Staphylococcus aureus [Presence] in Genital specimen by Organism specific culture | 0.880 |  |  2 |     4,590 |
| 42870589 | Drugs of abuse panel - Urine by Screen method | 0.858 |  |  0 |         0 |
| 1091253 | Methicillin resistant Staphylococcus aureus [Presence] in Axilla by Organism specific culture | 0.841 |  |  0 |         0 |
| 3000924 | Streptococcus pyogenes [Presence] in Throat by Organism specific culture | 0.833 |  |  1 |     8,058 |
| 645112 | Stenotrophomonas maltophilia.multidrug resistant [Presence] in Specimen by Organism specific culture | 0.826 |  |  0 |         0 |
| 1175703 | Drugs of abuse panel - Body fluid | 0.825 |  |  0 |         0 |
| 36305005 | Neisseria meningitidis [Presence] in Throat by Organism specific culture | 0.820 |  |  0 |         0 |
| 43534061 | Staphylococcus aureus methicillin resistance SCCmec [Presence] in Nose by NAA with probe detection | 0.815 |  |  0 |         0 |
| 1175629 | Drugs of abuse panel - Hair | 0.814 |  |  0 |         0 |
| 1761466 | Staph aureus and MRSA screening panel - Specimen by Organism specific culture | 0.803 |  |  0 |         0 |
| 3036007 | Streptococcus agalactiae [Presence] in Throat by Organism specific culture | 0.802 |  |  0 |         0 |
| 1175793 | Methicillin resistant Staphylococcus aureus (MRSA) DNA [Presence] in Nose by NAA with probe detection | 0.799 |  |  0 |         0 |
| 3023601 | Vancomycin resistant enterococcus [Presence] in Specimen by Organism specific culture | 0.794 |  |  1 |    10,730 |
| 40758548 | Home drug screening panel - Urine | 0.794 |  |  0 |         0 |
| 40766210 | Pseudomonas aeruginosa.multidrug resistant isolate [Presence] in Specimen by Organism specific culture | 0.793 |  |  0 |         0 |
| 43533384 | Drugs of abuse panel - Blood by Screen method | 0.787 |  |  0 |         0 |
| 46236372 | Staphylococcus aureus methicillin resistance SCCmec+orfX junction [Presence] in Nose by NAA with probe detection | 0.786 |  |  0 |         0 |
| 36305828 | Drugs of abuse screen W Reflex confirm panel - Urine | 0.785 |  |  0 |         0 |
| 3052990 | Drugs of abuse panel - Meconium | 0.783 |  |  0 |         0 |
| 1175815 | Drugs of abuse panel - Tissue | 0.777 |  |  0 |         0 |
| 3049172 | Sequence variation panel - Blood or Tissue by Molecular genetics method | 0.776 |  |  0 |         0 |
| 21493868 | CYP3A4 and CYP3A5 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.773 |  |  0 |         0 |
| 3044889 | 12 lead EKG panel | 0.769 |  |  2 | 1,163,408 |
| 3049122 | Sequencing methodology panel - Blood or Tissue by Molecular genetics method | 0.765 |  |  0 |         0 |
| 3039059 | Drugs of abuse 7 and Alcohol and Tricyclics panel - Urine by Screen method | 0.763 |  |  0 |         0 |
| 43534060 | CYP2D6 gene and CYP2C19 gene targeted mutation analysis panel - Blood or Tissue by Molecular genetics method | 0.761 |  |  0 |         0 |
| 40762243 | Vancomycin resistant enterococcus [Presence] in Anal by Organism specific culture | 0.755 |  |  0 |         0 |
| 3040040 | HTT gene mutation panel - Blood or Tissue by Molecular genetics method | 0.751 |  |  0 |         0 |
| 46236285 | Enterobacteriaceae.carbapenem resistant [Presence] in Anorectal or stool specimen by Organism specific culture | 0.749 |  |  0 |         0 |
| 3035792 | Gene XXX targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.749 |  |  0 |         0 |
| 3051704 | Genechip kit panel - Blood or Tissue by Molecular genetics method | 0.746 |  |  0 |         0 |
| 36306064 | KIT gene exon 17 targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.737 |  |  0 |         0 |
| 42528663 | IVD gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.737 |  |  0 |         0 |
| 40758330 | KIT gene targeted mutation analysis in Blood or Tissue by Molecular genetics method | 0.737 |  |  0 |         0 |
| 21492856 | Neisseria gonorrhoeae [Presence] in Anorectal by Organism specific culture | 0.737 | 3000 |  0 |         0 |
| 3043216 | Cardiovascular physiologic and EKG assessment panel | 0.734 |  |  0 |         0 |
| 21492812 | Staphylococcus aureus and Methicillin-resistant Staphylococcus aureus panel - Nose by NAA with probe detection | 0.727 |  |  0 |         0 |
| 36203841 | MRSA SCCmec and mecA+mecC genes panel - Nose | 0.709 |  |  0 |         0 |
| 42527877 | Staphylococcus aureus glycopeptide resistance panel | 0.705 |  |  0 |         0 |
| 1616902 | Staphylococcus aureus identification and resistance panel by Molecular genetics method | 0.700 |  |  0 |         0 |
| 3013512 | EKG study | 0.696 |  | 10 |   506,024 |
| 3010479 | Ambulatory cardiac rhythm monitor (Holter) study | 0.696 |  |  0 |         0 |
| 43534066 | MRSA SCCmec and mecA genes panel - Nose by NAA with probe detection | 0.690 |  |  0 |         0 |
| 3001473 | Type of EKG device | 0.688 |  |  0 |         0 |
| 1988318 | Temporary pacemaker panel | 0.680 |  |  0 |         0 |
| 1988411 | Permanent pacemaker panel | 0.676 |  |  0 |         0 |
| 1616739 | Blood pressure panel 24 hour mean | 0.667 |  |  0 |         0 |
| 1002224 | Polysomnography panel | 0.663 |  |  1 |    25,006 |
| 1988764 | Electromyography panel | 0.662 |  |  0 |         0 |
| 40771965 | Cardiology monitoring | 0.643 |  |  0 |         0 |
| 3004182 | Recording duration by EKG | 0.642 |  |  0 |         0 |
| 1259654 | Diagnostic multisection transesophageal and cardioversion panel Heart | 0.638 |  |  0 |         0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 183 | -metisilliiniresistentinstaphylococcusaureus(mrsa),viljely |  | 161 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Specimen by Organism specific culture | FALSE |
| 184 | -metisilliiniresistenttistaph.aureus,viljelynenästä |  | 578 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Nose by Organism specific culture | FALSE |
| 185 | -metisilliiniresistenttistaph.aureus,viljelynielusta |  | 578 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Throat by Organism specific culture | FALSE |
| 186 | -metisilliiniresistenttistaph.aureus,viljelyperineumista |  | 576 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Perineum by Organism specific culture | FALSE |
| 187 | ennaltamääritellyngeenineksonienemäsmuutostenjapientenkopiolukumuutostentutkimusngs-menetelmällä |  | 160 | 100 |  |  |  |  | Targeted gene variant analysis panel - Blood or Tissue by NGS | TRUE |
| 188 | huumeseula(amfet,bents,opiaat,kannab,koka) |  | 129 | 100 |  |  |  |  | Drugs of abuse 5 panel - Urine | TRUE |
| 189 | huumeseulonta(amfet.,bents.,opiaatit,kannabis,kokaiini,buprenorfiini) |  | 544 | 100 |  |  |  |  | Drugs of abuse 6 panel - Urine | TRUE |
| 190 | metisilliiniresistentinstaphylococcusaureus(mrs |  | 166 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Specimen by Organism specific culture | FALSE |
| 191 | metisilliiniresistenttistaph.aureus,viljelyne |  | 294 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Nose by Organism specific culture | FALSE |
| 192 | metisilliiniresistenttistaph.aureus,viljelynenästä |  | 436 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Nose by Organism specific culture | FALSE |
| 193 | metisilliiniresistenttistaph.aureus,viljelyni |  | 295 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Throat by Organism specific culture | FALSE |
| 194 | metisilliiniresistenttistaph.aureus,viljelynielusta |  | 442 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Throat by Organism specific culture | FALSE |
| 195 | metisilliiniresistenttistaph.aureus,viljelype |  | 296 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Perineum by Organism specific culture | FALSE |
| 196 | metisilliiniresistenttistaph.aureus,viljelyperineumista |  | 433 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant [Presence] in Perineum by Organism specific culture | FALSE |
| 197 | metisilliiniresistenttistaphylococcusaureus(mrsa),seulontaviljely␤ |  | 111 | 100 |  |  |  |  | Staphylococcus aureus.methicillin resistant screen panel by Culture | TRUE |
| 198 | pt-ekg,pitkäaikaisrekisteröinti(24h),kytkentä,analys,lausunto |  | 322 | 100 |  |  | Patient |  | EKG 24 hour ambulatory panel | TRUE |
| 199 | pt-ekg,pitkäaikaisrekisteröinti(24h),kytkentä,analysointi,lausunto |  | 138 | 100 |  |  | Patient |  | EKG 24 hour ambulatory panel | TRUE |
| 200 | pt-ekg,pitkäaikaisrekisteröinti(48h),kytkentä,analysointi,lausunto |  | 136 | 100 |  |  | Patient |  | EKG 48 hour ambulatory panel | TRUE |
| 201 | työpaikanhuumetutkimus6a(amfetamiini,bentsodiatsepiinit,buprenorfiini,kannabis,kokaiini,opi |  | 108 | 100 |  |  |  |  | Drugs of abuse 6 panel - Urine | TRUE |
| 202 | u-huum6a:amfetamiinit,bentsodiatsepiinit,buprenorfiini,kannabis,kokaiinijaopiaatit.vainsop. |  | 113 | 100 |  |  | Urine |  | Drugs of abuse 6 panel - Urine | TRUE |
| 203 | u-huumeseulonta(amfet.,bents.,opiaatit,kannabis,kokaiini,buprenorfiini) |  | 731 | 100 |  |  | Urine |  | Drugs of abuse 6 panel - Urine | TRUE |

