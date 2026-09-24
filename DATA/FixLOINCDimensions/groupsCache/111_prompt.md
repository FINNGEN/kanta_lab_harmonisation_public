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
Here is group 111.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 706163 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  | 2 | 961,920 |
| 723477 | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 1.000 |  | 0 |       0 |
| 723473 | SARS-CoV-2 (COVID-19) IgA Ab [Presence] in Serum or Plasma by Immunoassay | 0.973 |  | 1 |     270 |
| 36031238 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with non-probe detection | 0.970 |  | 0 |       0 |
| 757685 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | 0.964 |  | 0 |       0 |
| 723474 | SARS-CoV-2 (COVID-19) IgG Ab [Presence] in Serum or Plasma by Immunoassay | 0.961 |  | 1 |   1,259 |
| 723475 | SARS-CoV-2 (COVID-19) IgM Ab [Presence] in Serum or Plasma by Immunoassay | 0.959 |  | 0 |       0 |
| 586515 | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum or Plasma by Immunoassay | 0.955 |  | 0 |       0 |
| 3041700 | Complement C1q Ab [Presence] in Serum | 0.946 |  | 0 |       0 |
| 3042951 | Complement C1q Ab [Units/volume] in Serum | 0.946 |  | 3 |     282 |
| 723479 | SARS-CoV-2 (COVID-19) IgG+IgM Ab [Presence] in Serum or Plasma by Immunoassay | 0.943 |  | 0 |       0 |
| 36033641 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay | 0.940 |  | 1 |  15,478 |
| 36031861 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and Respiratory syncytial virus RNA panel - Respiratory system specimen by NAA with probe detection | 0.940 |  | 2 |  45,357 |
| 706170 | SARS-CoV-2 (COVID-19) RNA [Presence] in Specimen by NAA with probe detection | 0.936 |  | 0 |       0 |
| 1988202 | SARS-CoV-2 (COVID-19) S protein IgG Ab [Presence] in Serum or Plasma by Immunoassay | 0.934 |  | 0 |       0 |
| 586521 | SARS-CoV-2 (COVID-19) IgA Ab [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.933 |  | 0 |       0 |
| 1259611 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen | 0.932 |  | 0 |       0 |
| 757686 | SARS-CoV-2 (COVID-19) IgA+IgM [Presence] in Serum or Plasma by Immunoassay | 0.930 |  | 0 |       0 |
| 706161 | SARS-CoV-2 (COVID-19) N gene [Presence] in Respiratory system specimen by NAA with probe detection | 0.929 |  | 0 |       0 |
| 1091424 | SARS-CoV-2 (COVID-19) IgG Ab [Presence] in Specimen | 0.929 |  | 0 |       0 |
| 706160 | SARS-CoV-2 (COVID-19) RdRp gene [Presence] in Respiratory system specimen by NAA with probe detection | 0.929 |  | 0 |       0 |
| 36661376 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.926 |  | 0 |       0 |
| 36661384 | Influenza virus A and B and SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.923 |  | 0 |       0 |
| 706165 | SARS-related coronavirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.923 |  | 0 |       0 |
| 706158 | SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA with probe detection | 0.922 |  | 0 |       0 |
| 706180 | SARS-CoV-2 (COVID-19) IgM Ab [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.920 |  | 0 |       0 |
| 723465 | SARS-CoV-2 (COVID-19) S gene [Presence] in Respiratory system specimen by NAA with probe detection | 0.920 |  | 0 |       0 |
| 36661377 | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by Sequencing | 0.920 |  | 0 |       0 |
| 648299 | SARS-CoV-2 (COVID-19) IgA Ab [Measurement] in Serum or Plasma | 0.919 |  | 0 |       0 |
| 706181 | SARS-CoV-2 (COVID-19) IgG Ab [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.913 |  | 0 |       0 |
| 36032419 | SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Immunoassay | 0.912 |  | 3 |  32,724 |
| 36661369 | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum, Plasma or Blood by Rapid immunoassay | 0.906 |  | 0 |       0 |
| 645263 | SARS-CoV-2 (COVID-19) IgM Ab [Measurement] in Serum or Plasma | 0.904 |  | 0 |       0 |
| 1988397 | SARS-CoV-2 (COVID-19) N protein IgG Ab [Presence] in Serum or Plasma by Immunoassay | 0.903 |  | 0 |       0 |
| 3020378 | Complement C1q Ag [Units/volume] in Serum | 0.901 |  | 0 |       0 |
| 648157 | SARS-CoV-2 (COVID-19) IgG Ab [Measurement] in Serum or Plasma | 0.899 |  | 0 |       0 |
| 36661372 | SARS-CoV-2 (COVID-19) IgA Ab [Titer] in Serum or Plasma by Immunofluorescence | 0.885 |  | 0 |       0 |
| 723480 | SARS-CoV-2 (COVID-19) Ab [Interpretation] in Serum or Plasma | 0.881 |  | 0 |       0 |
| 3031372 | SARS coronavirus IgM Ab [Presence] in Serum | 0.879 |  | 0 |       0 |
| 586522 | SARS-CoV-2 (COVID-19) Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.876 |  | 0 |       0 |
| 1761840 | Influenza virus A and B and SARS-CoV-2 (COVID-19) RNA panel - Specimen by NAA with probe detection | 0.875 |  | 0 |       0 |
| 3033147 | SARS coronavirus IgG Ab [Presence] in Serum | 0.870 |  | 0 |       0 |
| 36031213 | SARS-CoV-2 (COVID-19) S gene [Presence] in Respiratory system specimen by Sequencing | 0.864 |  | 0 |       0 |
| 36203320 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Upper respiratory specimen by NAA with probe detection | 0.863 |  | 0 |       0 |
| 36031949 | Influenza virus A and B and SARS-CoV+SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.862 |  | 0 |       0 |
| 3002140 | Complement C1q [Mass/volume] in Serum or Plasma | 0.860 |  | 0 |       0 |
| 648704 | Influenza virus A and B and Respiratory syncytial virus RNA panel - Specimen by NAA with probe detection | 0.857 |  | 0 |       0 |
| 706177 | SARS-CoV-2 (COVID-19) IgG Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.856 |  | 0 |       0 |
| 36033643 | Influenza virus A and B and SARS-CoV-2 (COVID-19) Ag panel - Upper respiratory specimen by Rapid immunoassay | 0.855 |  | 0 |       0 |
| 3034613 | SARS coronavirus IgM Ab [Presence] in Serum by Immunoassay | 0.854 |  | 0 |       0 |
| 36661375 | Influenza virus A and B and SARS-CoV-2 (COVID-19) identified in Respiratory system specimen by NAA with probe detection | 0.854 |  | 0 |       0 |
| 3020999 | Complement C1q Ag [Moles/volume] in Serum or Plasma | 0.848 |  | 0 |       0 |
| 36304336 | Complement C1q.functional [Units/volume] in Serum or Plasma | 0.848 |  | 0 |       0 |
| 36031197 | SARS-CoV-2 (COVID-19) Ab [Presence] in DBS by Immunoassay | 0.844 |  | 0 |       0 |
| 1092298 | SARS-CoV-2 (COVID-19) IgG Ab [Units/volume] in Specimen | 0.842 |  | 0 |       0 |
| 723459 | SARS-CoV-2 (COVID-19) IgA Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.834 |  | 0 |       0 |
| 706178 | SARS-CoV-2 (COVID-19) IgM Ab [Units/volume] in Serum or Plasma by Immunoassay | 0.834 |  | 0 |       0 |
| 1091110 | SARS-CoV+SARS-CoV-2 (COVID-19) Ag [Presence] in Specimen | 0.832 |  | 0 |       0 |
| 3022870 | Complement C1q Ag [Units/volume] in Serum or Plasma by Raji cell assay | 0.831 |  | 0 |       0 |
| 3049668 | Complement C3 [Presence] in Serum or Plasma | 0.830 |  | 0 |       0 |
| 1619029 | SARS-CoV-2 (COVID-19) S protein RBD neutralizing antibody [Units/volume] in Serum or Plasma by Immunoassay | 0.827 |  | 0 |       0 |
| 3052973 | Complement C4 [Presence] in Serum or Plasma | 0.826 |  | 0 |       0 |
| 3025552 | Complement C1 esterase inhibitor free IgG Ab [Mass/volume] in Serum or Plasma | 0.824 |  | 0 |       0 |
| 3038588 | Complement C2 [Presence] in Serum or Plasma | 0.821 |  | 0 |       0 |
| 3046458 | Immune complex [Presence] in Serum or Plasma by C1q binding assay | 0.818 |  | 0 |       0 |
| 40761783 | Complement C5 [Presence] in Serum or Plasma | 0.818 |  | 0 |       0 |
| 36033652 | SARS-CoV-2 (COVID-19) lineage [Identifier] in Specimen by Molecular genetics method | 0.818 |  | 0 |       0 |
| 36031734 | SARS-CoV-2 (COVID-19) S protein RBD neutralizing antibody [Presence] in Serum or Plasma by sVNT | 0.817 |  | 0 |       0 |
| 3032256 | Immune complex.IgG [Units/volume] in Serum or Plasma by C1q binding assay | 0.817 |  | 0 |       0 |
| 21493397 | A IgG Ab [Presence] in Serum or Plasma | 0.815 |  | 0 |       0 |
| 21493399 | B IgG Ab [Presence] in Serum or Plasma | 0.814 |  | 0 |       0 |
| 3006448 | Complement C1 esterase inhibitor bound IgG Ab [Mass/volume] in Serum or Plasma | 0.813 |  | 0 |       0 |
| 36033666 | SARS-CoV-2 (COVID-19) IgG Ab [Mass/volume] in Serum or Plasma by Immunoassay | 0.812 |  | 0 |       0 |
| 3012827 | Coronavirus Ab [Units/volume] in Serum | 0.810 |  | 0 |       0 |
| 36032352 | SARS-CoV-2 (COVID-19) and SARS-related CoV RNA panel - Respiratory system specimen by NAA with probe detection | 0.806 |  | 0 |       0 |
| 3051607 | IgM Ab [Presence] in Serum or Plasma | 0.803 |  | 0 |       0 |
| 647666 | SARS-CoV-2 (COVID-19) RNA [Measurement] in Respiratory system specimen | 0.800 |  | 0 |       0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1564 | -c19agvt |  | 139 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1565 | -covidjt |  | 396 | 100 |  |  |  |  |  | FALSE |
| 1566 | -cv19ag | % | 13 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1567 | -cv19ag | e12/l | 7 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1568 | -cv19ag | e9/l | 19 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1569 | -cv19ag | fl | 8 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1570 | -cv19ag | g/l | 15 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1571 | -cv19ag | mmol/l | 25 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1572 | -cv19ag | pg | 8 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1573 | -cv19ag | u/l | 5 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1574 | -cv19ag | ug/l | 6 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1575 | -cv19ag | umol/l | 6 | 0 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1576 | -cv19ag |  | 11991 | 99.09 |  | COVID-19-koronavirustauti, antigeeni |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1577 | -cv19ag0 |  | 3845 | 100 |  | Panbio COVID-19 Ag Rapid Test, Abbott Rapid Diagnostics |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1578 | -cv19ag1 |  | 504 | 100 |  | Flowflex SARS-CoV-2 Antigen rapid test, ACON Laboratories, Inc |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1579 | -cv19ag2 |  | 204 | 100 |  | mariPOC SARS-CoV-2, ArcDia International Ltd |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1580 | -cv19ag3 |  | 270 | 100 |  | mariPOC Quick Flu+ , ArcDia International Ltd |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1581 | -cv19ag4 |  | 20852 | 100 |  | STANDARD Q COVID-19 Ag, SD BIONSENSOR Inc |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1582 | -cv19ag5 |  | 15481 | 100 |  | SARS-CoV-2 Antigen Rapid Test, Roche (SD BIOSENSOR) |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1583 | -cv19agj |  | 1370 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1584 | -cv19agl |  | 391 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1585 | -cv19nho |  | 891531 | 100 |  | -COVID-19-koronavirustauti, nukleiinihappo (kval) |  |  | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1586 | -cv19pika |  | 8349 | 99.95 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1587 | -cv19vt |  | 1271 | 100 |  |  |  |  |  | FALSE |
| 1588 | b-cv19ab-o |  | 325 | 100 |  |  | Blood | Qualitative test (also semi-quantitative) | SARS-CoV-2 (COVID-19) Ab [Presence] in Blood | FALSE |
| 1589 | b-cv19abg |  | 232 | 100 |  | B -COVID-19 -koronavirustauti, IgG-vasta-aineet | Blood |  | SARS-CoV-2 (COVID-19) IgG Ab [Presence] in Blood | FALSE |
| 1590 | b-cv19abm |  | 233 | 100 |  | B -COVID-19 -koronavirustauti, IgM-vasta-aineet | Blood |  | SARS-CoV-2 (COVID-19) IgM Ab [Presence] in Blood | FALSE |
| 1591 | cldinho |  | 111 | 100 |  |  |  |  |  | FALSE |
| 1592 | covid-19aghoi |  | 476 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1593 | cv19ag |  | 985 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1594 | cv19infrs |  | 7932 | 100 |  |  |  |  | Influenza virus A+B+Respiratory syncytial virus+SARS-CoV-2 (COVID-19) RNA panel - Respiratory system specimen by NAA | TRUE |
| 1595 | cv19nho |  | 71412 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1596 | cv19nhopth |  | 159 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1597 | cv19sekv |  | 120 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) [Identifier] in Respiratory system specimen by Sequencing | FALSE |
| 1598 | oma-covid-o |  | 1391 | 100 |  |  |  | Qualitative test (also semi-quantitative) | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1599 | p-c1qabg | u/ml | 88 | 0 |  | P-Komplementti C1q, IgG-vasta-aineet | Plasma |  | Complement C1q IgG Ab [Units/volume] in Serum or Plasma | FALSE |
| 1600 | p-c1qabg |  | 195 | 95.38 |  | P-Komplementti C1q, IgG-vasta-aineet | Plasma |  | Complement C1q IgG Ab [Presence] in Serum or Plasma | FALSE |
| 1601 | pika-covid-19ag |  | 290 | 100 |  |  |  |  | SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory system specimen by Rapid immunoassay | FALSE |
| 1602 | s-cv19ab | au/ml | 36 | 100 |  | S -COVID-19 -koronavirustauti, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum or Plasma | FALSE |
| 1603 | s-cv19ab |  | 3692 | 100 |  | S -COVID-19 -koronavirustauti, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum or Plasma | FALSE |
| 1604 | s-cv19aba |  | 270 | 100 |  | S -COVID-19 -koronavirustauti, IgA-vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) IgA Ab [Presence] in Serum or Plasma | FALSE |
| 1605 | s-cv19abg |  | 1259 | 100 |  | S -COVID-19 -koronavirustauti, IgG-vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) IgG Ab [Presence] in Serum or Plasma | FALSE |
| 1606 | s-cv19abm |  | 101 | 100 |  | S -COVID-19 -koronavirustauti, IgM- vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) IgM Ab [Presence] in Serum or Plasma | FALSE |
| 1607 | s-cv19abp |  | 153 | 100 |  |  | Serum |  | SARS-CoV-2 (COVID-19) Ab [Presence] in Serum or Plasma | FALSE |
| 1608 | s-cv19sab | au/ml | 149 | 0 | [1.48, 3.94, 139.34, 691.66, 1561.95, 3317.2, 5543.63, 12999.61, 20746] | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) spike protein Ab [Units/volume] in Serum or Plasma | FALSE |
| 1609 | s-cv19sab | u/ml | 15 | 0 |  | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) spike protein Ab [Units/volume] in Serum or Plasma | FALSE |
| 1610 | s-cv19sab |  | 106 | 100 |  | S -COVID-19-koronavirustauti, piikkiproteiini, vasta-aineet | Serum |  | SARS-CoV-2 (COVID-19) spike protein Ab [Presence] in Serum or Plasma | FALSE |

