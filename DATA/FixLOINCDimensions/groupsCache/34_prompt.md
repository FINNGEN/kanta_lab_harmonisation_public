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
Here is group 34.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1175573 | Streptococcus agalactiae DNA [Presence] in Vaginal fluid by NAA with probe detection | 1.000 |  | 0 |       0 |
| 1260031 | Streptococcus pyogenes DNA [Presence] in Specimen by NAA with probe detection | 1.000 |  | 0 |       0 |
| 3024135 | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | 1.000 | 521 | 1 | 159,335 |
| 3024740 | Streptococcus.beta-hemolytic [Presence] in Specimen by Organism specific culture | 1.000 | 334 | 0 |       0 |
| 3048882 | Streptococcus agalactiae DNA [Presence] in Specimen by NAA with probe detection | 1.000 | 1156 | 0 |       0 |
| 40763543 | Streptococcus pyogenes DNA [Presence] in Throat by NAA with probe detection | 1.000 |  | 0 |       0 |
| 3964796 | Streptococcus pyogenes DNA [Presence] in Throat by NAA with non-probe detection | 0.975 |  | 0 |       0 |
| 37020939 | Streptococcus agalactiae DNA [Presence] in Genital specimen by NAA with probe detection | 0.964 |  | 0 |       0 |
| 21491660 | Streptococcus pyogenes Ag [Presence] in Throat by Rapid immunoassay | 0.961 | 1051 | 0 |       0 |
| 1092209 | Streptococcus sp DNA [Presence] in Specimen by NAA with probe detection | 0.939 |  | 0 |       0 |
| 3032732 | Streptococcus pyogenes DNA [Identifier] in Specimen by NAA with probe detection | 0.931 |  | 0 |       0 |
| 37019817 | Streptococcus agalactiae DNA [Presence] in Vag+Rectum by NAA with probe detection | 0.930 |  | 0 |       0 |
| 3017906 | Streptococcus pyogenes Ag [Presence] in Specimen by Immunoassay | 0.929 |  | 0 |       0 |
| 36660467 | Streptococcus pyogenes DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.925 |  | 0 |       0 |
| 37021509 | Streptococcus agalactiae DNA [Presence] by NAA with probe detection in Positive blood culture | 0.922 |  | 0 |       0 |
| 36659688 | Streptococcus agalactiae DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.921 |  | 0 |       0 |
| 1988536 | Streptococcus agalactiae DNA [Presence] in Urine by NAA with probe detection | 0.920 |  | 0 |       0 |
| 37020473 | Streptococcus pyogenes DNA [Presence] by NAA with probe detection in Positive blood culture | 0.914 |  | 0 |       0 |
| 3966418 | Streptococcus pyogenes DNA [Presence] in Wound by NAA with probe detection | 0.912 |  | 0 |       0 |
| 1091604 | Streptococcus agalactiae DNA [Presence] in Specimen by Molecular genetics method | 0.909 |  | 0 |       0 |
| 3002281 | Mycoplasma agalactiae DNA [Presence] in Specimen by NAA with probe detection | 0.907 |  | 0 |       0 |
| 36203570 | Streptococcus agalactiae DNA [Presence] by NAA with non-probe detection in Positive blood culture | 0.907 |  | 0 |       0 |
| 1091027 | Streptococcus pyogenes DNA [Presence] in Specimen | 0.904 |  | 0 |       0 |
| 1091240 | Streptococcus dysgalactiae DNA [Presence] in Specimen by NAA with probe detection | 0.899 |  | 0 |       0 |
| 1091594 | Streptococcus.beta-hemolytic [Presence] in Specimen | 0.899 |  | 0 |       0 |
| 3005214 | Streptococcus.beta-hemolytic [Presence] in Genital specimen by Organism specific culture | 0.897 |  | 0 |       0 |
| 1469780 | Streptococcus agalactiae DNA [Presence] in Body fluid by NAA with non-probe detection | 0.894 |  | 0 |       0 |
| 1469570 | Streptococcus pyogenes DNA [Presence] in Body fluid by NAA with non-probe detection | 0.892 |  | 0 |       0 |
| 1988894 | Streptococcus agalactiae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 0.887 |  | 0 |       0 |
| 1092202 | Streptococcus pyogenes [Presence] in Specimen | 0.884 |  | 0 |       0 |
| 1469941 | Gardnerella vaginalis DNA [Presence] in Vaginal fluid by NAA with probe detection | 0.879 |  | 0 |       0 |
| 1616546 | Streptococcus agalactiae DNA [Presence] in Synovial fluid by NAA with non-probe detection | 0.879 |  | 0 |       0 |
| 3964996 | Streptococcus dysgalactiae subspecies equisimilis DNA [Presence] in Throat by NAA with non-probe detection | 0.878 |  | 0 |       0 |
| 36203572 | Streptococcus pyogenes DNA [Presence] by NAA with non-probe detection in Positive blood culture | 0.872 |  | 0 |       0 |
| 3033319 | Streptococcus pyogenes Ag [Presence] in Throat | 0.866 | 337 | 4 |  86,750 |
| 3008051 | Streptococcus pyogenes Ag [Presence] in Specimen | 0.862 |  | 0 |       0 |
| 3000924 | Streptococcus pyogenes [Presence] in Throat by Organism specific culture | 0.861 |  | 1 |   8,058 |
| 3018201 | Streptococcus pyogenes Ag [Presence] in Specimen by Immunofluorescence | 0.853 |  | 0 |       0 |
| 3017364 | Streptococcus pyogenes Ag [Presence] in Throat by Immunofluorescence | 0.849 |  | 0 |       0 |
| 3036007 | Streptococcus agalactiae [Presence] in Throat by Organism specific culture | 0.834 |  | 0 |       0 |
| 3022562 | Streptococcus pyogenes [Presence] in Specimen by Organism specific culture | 0.829 |  | 0 |       0 |
| 40771489 | Streptococcus pyogenes rRNA [Presence] in Throat by Probe | 0.820 |  | 0 |       0 |
| 3009769 | Streptococcus pyogenes rRNA [Presence] in Specimen by Probe | 0.805 | 1470 | 0 |       0 |
| 43055233 | Streptococcus pyogenes exotoxin B speB gene [Presence] in Specimen by NAA with probe detection | 0.802 |  | 0 |       0 |
| 647010 | Streptococcus pyogenes Ag [Measurement] in Throat | 0.799 |  | 0 |       0 |
| 3011263 | Bordetella pertussis [Presence] in Throat by Organism specific culture | 0.776 |  | 0 |       0 |
| 3036000 | Streptococcus agalactiae [Presence] in Specimen by Organism specific culture | 0.775 |  | 0 |       0 |
| 1761890 | Staphylococcus aureus [Presence] in Specimen by Organism specific culture | 0.774 |  | 0 |       0 |
| 36305005 | Neisseria meningitidis [Presence] in Throat by Organism specific culture | 0.766 |  | 0 |       0 |
| 3026966 | Neisseria gonorrhoeae [Presence] in Throat by Organism specific culture | 0.764 |  | 0 |       0 |
| 46236183 | Bacillus cereus [Presence] in Specimen by Organism specific culture | 0.751 |  | 0 |       0 |
| 3028450 | Bacillus anthracis [Presence] in Specimen by Organism specific culture | 0.744 |  | 0 |       0 |
| 3053028 | Streptococcus sp identified in Specimen by Organism specific culture | 0.741 |  | 1 |   3,206 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 204 | -streptococcusagalactie(str.ryhmäb,gbs),nukleiinihaponosoitus |  | 140 | 100 |  |  |  |  | Streptococcus agalactiae DNA [Presence] in Specimen by NAA with probe detection | FALSE |
| 205 | fl-streptococcusagalactie(b),nukleiinihaponosoitus |  | 354 | 100 |  |  | Vaginal discharge |  | Streptococcus agalactiae DNA [Presence] in Vaginal fluid by NAA with probe detection | FALSE |
| 206 | ps-streptococcus,viljely(-hemolyyttisetstrepto |  | 151 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | FALSE |
| 207 | ps-streptococcus,viljely(beeta-hemolyyttisetstr |  | 110 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | FALSE |
| 208 | ps-streptococcus,viljely(hemolyytt.streptokokit) |  | 327 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | FALSE |
| 209 | ps-streptococcus,viljely(hemolyytt.streptokokitnielusta) |  | 414 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | FALSE |
| 210 | ps-streptococcus,viljely(hemolyyttisetstreptok) |  | 162 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | FALSE |
| 211 | ps-streptococcus,viljely(hemolyyttisetstreptokokit) |  | 339 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | FALSE |
| 212 | ps-streptococcus,viljelynielusta(hemolyytt) |  | 238 | 100 |  |  | Pharyngeal secretion |  | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | FALSE |
| 213 | ps-streptococcuspyogenes(a),antigeeni |  | 735 | 100 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes [Presence] in Throat by Rapid immunoassay | FALSE |
| 214 | ps-streptococcuspyogenes(a),nukleiinihappo(kval) |  | 150 | 99.33 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes DNA [Presence] in Throat by NAA with probe detection | FALSE |
| 215 | ps-streptococcuspyogenis(a)antig,vierithoitoy |  | 124 | 100 |  |  | Pharyngeal secretion |  | Streptococcus pyogenes [Presence] in Throat by Rapid immunoassay | FALSE |
| 216 | streptococcus,viljely(hemolyyt.streptokokitnielusta) |  | 333 | 100 |  |  |  |  | Streptococcus.beta-hemolytic [Presence] in Throat by Organism specific culture | FALSE |
| 217 | streptococcus,viljely(hemolyytt.streptokokit) |  | 454 | 100 |  |  |  |  | Streptococcus.beta-hemolytic [Presence] in Specimen by Organism specific culture | FALSE |
| 218 | streptococcusagalactiae(b),nukleiinihaponosoitus,fluori,vieritesti |  | 304 | 100 |  |  |  |  | Streptococcus agalactiae DNA [Presence] in Vaginal fluid by NAA with probe detection | FALSE |
| 219 | streptococcusagalactie(b),nukleiinihaponosoitus |  | 242 | 100 |  |  |  |  | Streptococcus agalactiae DNA [Presence] in Specimen by NAA with probe detection | FALSE |
| 220 | streptococcuspyogenes(a),nukleiinihappo-osoitus |  | 228 | 100 |  |  |  |  | Streptococcus pyogenes DNA [Presence] in Specimen by NAA with probe detection | FALSE |
| 221 | streptococcuspyogenes(a),osoituskoe |  | 396 | 100 |  |  |  |  | Streptococcus pyogenes [Presence] in Specimen by Rapid immunoassay | FALSE |

