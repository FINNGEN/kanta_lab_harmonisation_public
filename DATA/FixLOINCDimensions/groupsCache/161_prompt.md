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
Here is group 161.

## Candidate OMOP concepts for this group

| omop_concept_id | omop_concept_name | score | top2000 | n_codes | n_events |
|---|---|---|---|---|---|
| 1988720 | Haemophilus influenzae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | 1.000 |  |  0 |         0 |
| 3012413 | Glucose [Moles/volume] in Serum or Plasma --2 hours post meal | 1.000 | 1141 |  7 |     6,457 |
| 3015024 | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 1.000 | 928 | 25 |     6,546 |
| 3016701 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 1.000 | 884 | 37 |     8,302 |
| 3018251 | Fasting glucose [Moles/volume] in Serum or Plasma | 1.000 | 332 | 42 | 1,996,657 |
| 3024117 | Large unstained cells/Leukocytes in Blood by Automated count | 1.000 | 1894 |  0 |         0 |
| 3024944 | Large unstained cells [#/volume] in Blood by Automated count | 1.000 |  |  0 |         0 |
| 37019853 | Mycoplasma pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  |  0 |         0 |
| 37020338 | Haemophilus influenzae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  |  0 |         0 |
| 37020808 | Human metapneumovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  |  0 |         0 |
| 37020902 | Legionella pneumophila DNA [Presence] in Respiratory system specimen by NAA with probe detection | 1.000 |  |  0 |         0 |
| 46236367 | Glucose [Moles/volume] in Serum, Plasma or Blood --2 hours post meal | 0.987 |  |  0 |         0 |
| 37020101 | Chlamydophila pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | 0.981 |  |  0 |         0 |
| 3001501 | Glucose [Moles/volume] in Capillary blood by Glucometer | 0.977 |  |  3 |     1,900 |
| 21493349 | Haemophilus influenzae DNA [Presence] in Cerebral spinal fluid by NAA with non-probe detection | 0.974 |  |  0 |         0 |
| 3019047 | Glucose [Moles/volume] in Serum or Plasma --2.5 hours post dose glucose | 0.971 |  |  0 |         0 |
| 40759040 | C peptide [Moles/volume] in Serum or Plasma --post meal | 0.971 |  | 13 |     6,005 |
| 3034101 | Glucose [Moles/volume] in Serum or Plasma --2.6 hours post dose glucose | 0.970 |  |  0 |         0 |
| 3036895 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post dose glucose | 0.969 |  |  0 |         0 |
| 46236950 | Fasting glucose [Moles/volume] in Serum, Plasma or Blood | 0.965 |  |  0 |         0 |
| 3006520 | Glucose [Moles/volume] in Serum or Plasma --2.3 hours post dose glucose | 0.965 |  |  0 |         0 |
| 3007619 | Glucose [Moles/volume] in Serum or Plasma --1.6 hours post dose glucose | 0.963 |  |  0 |         0 |
| 3003912 | Glucose [Moles/volume] in Serum or Plasma --1.3 hours post dose glucose | 0.962 |  |  0 |         0 |
| 3040659 | Glucose [Moles/volume] in Serum or Plasma --1 hour post meal | 0.960 | 1362 |  0 |         0 |
| 3042194 | Human metapneumovirus RNA [Presence] in Specimen by NAA with probe detection | 0.959 |  |  2 |    18,405 |
| 3002482 | Mycoplasma pneumoniae DNA [Presence] in Specimen by NAA with probe detection | 0.955 |  |  1 |    14,832 |
| 37019690 | Mycoplasma pneumoniae DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.955 |  |  0 |         0 |
| 3009154 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 100 g glucose PO | 0.955 | 896 |  0 |         0 |
| 3042995 | Glucose [Moles/volume] in Serum or Plasma --1.5 hours post meal | 0.953 |  |  0 |         0 |
| 36304237 | Mycoplasma pneumoniae DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.952 |  |  0 |         0 |
| 40770421 | Human metapneumovirus A RNA [Presence] in Specimen by NAA with probe detection | 0.951 |  |  0 |         0 |
| 36303340 | Legionella pneumophila DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.951 |  |  0 |         0 |
| 3016103 | Fatty acids [Moles/volume] in Serum or Plasma | 0.950 |  |  0 |         0 |
| 3020565 | Legionella pneumophila DNA [Presence] in Specimen by NAA with probe detection | 0.950 |  |  1 |     9,507 |
| 3037432 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 100 g glucose PO | 0.950 | 872 |  0 |         0 |
| 40757389 | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose insulin IV | 0.948 |  |  0 |         0 |
| 3032897 | Saturated fatty acids [Moles/volume] in Serum or Plasma | 0.948 |  |  0 |         0 |
| 3017538 | Glucose [Moles/volume] in Serum or Plasma --2 hours post 75 g glucose PO | 0.948 | 835 |  0 |         0 |
| 40764127 | Haemophilus influenzae DNA [Presence] in Specimen by NAA with probe detection | 0.948 |  |  1 |     3,610 |
| 37020057 | Human metapneumovirus RNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.948 |  |  0 |         0 |
| 3021737 | Glucose [Mass/volume] in Serum or Plasma --2 hours post meal | 0.948 |  |  0 |         0 |
| 3039422 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 75 g glucose PO | 0.947 | 876 |  0 |         0 |
| 3032911 | Monounsaturated fatty acids [Moles/volume] in Serum or Plasma | 0.947 |  |  0 |         0 |
| 3026300 | Glucose [Mass/volume] in Serum or Plasma --2 hours post dose glucose | 0.947 |  |  0 |         0 |
| 3010300 | Glucose [Mass/volume] in Serum or Plasma --1 hour post dose glucose | 0.947 |  |  0 |         0 |
| 3041930 | Glucose [Moles/volume] in Serum or Plasma --post meal | 0.947 |  |  0 |         0 |
| 3020869 | Glucose [Moles/volume] in Serum or Plasma --1 hour post 50 g glucose PO | 0.946 | 338 |  0 |         0 |
| 1469833 | Legionella pneumophila DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.945 |  |  0 |         0 |
| 1469765 | Mycoplasma pneumoniae DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.944 |  |  0 |         0 |
| 1469884 | Haemophilus influenzae DNA [Presence] in Bronchial specimen by NAA with probe detection | 0.944 |  |  0 |         0 |
| 36660466 | Haemophilus influenzae DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.944 |  |  0 |         0 |
| 1259858 | Legionella pneumophila DNA [Presence] in Upper respiratory specimen by NAA with non-probe detection | 0.938 |  |  0 |         0 |
| 40770422 | Human metapneumovirus B RNA [Presence] in Specimen by NAA with probe detection | 0.938 |  |  0 |         0 |
| 1091752 | Human metapneumovirus RNA [Presence] in Bronchial specimen by NAA with probe detection | 0.937 |  |  0 |         0 |
| 3024270 | Haemophilus influenzae A DNA [Presence] in Specimen by NAA with probe detection | 0.937 |  |  0 |         0 |
| 37019632 | Legionella pneumophila DNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.937 |  |  0 |         0 |
| 1176113 | Human metapneumovirus RNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.935 |  |  0 |         0 |
| 647029 | Human metapneumovirus RNA [Presence] in Specimen by NAA with non-probe detection | 0.934 |  |  0 |         0 |
| 37020896 | Mycoplasma pneumoniae DNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.933 |  |  0 |         0 |
| 40758510 | Glucose [Moles/volume] in Serum or Plasma --2.5 hours post 75 g glucose PO | 0.933 |  |  0 |         0 |
| 37020392 | Chlamydophila pneumoniae DNA [Presence] in Upper respiratory specimen by NAA with probe detection | 0.933 |  |  0 |         0 |
| 3966625 | Legionella sp DNA [Presence] in Specimen by NAA with probe detection | 0.933 |  |  0 |         0 |
| 36306047 | Chlamydophila pneumoniae DNA [Presence] in Lower respiratory specimen by NAA with probe detection | 0.933 |  |  0 |         0 |
| 36659861 | C peptide [Mass/volume] in Serum or Plasma --1 hour post meal | 0.932 |  |  0 |         0 |
| 3031478 | Chlamydophila pneumoniae DNA [Presence] in Specimen by NAA with probe detection | 0.932 |  |  1 |    12,165 |
| 3048845 | C peptide [Moles/volume] in Serum or Plasma --1 hour post dose glucose | 0.932 |  |  0 |         0 |
| 3023993 | Large unstained cells [#/volume] in Blood | 0.931 |  |  0 |         0 |
| 44816559 | Phosphatidylethanol [Mass/volume] in Blood | 0.930 |  |  3 |    36,977 |
| 647393 | Mycoplasma pneumoniae DNA [Presence] in Specimen by NAA with non-probe detection | 0.929 |  |  0 |         0 |
| 3032924 | Polyunsaturated fatty acids [Moles/volume] in Serum or Plasma | 0.928 |  |  0 |         0 |
| 648164 | Haemophilus influenzae E DNA [Presence] in Specimen by NAA with probe detection | 0.927 |  |  0 |         0 |
| 645732 | Haemophilus influenzae D DNA [Presence] in Specimen by NAA with probe detection | 0.927 |  |  0 |         0 |
| 37020565 | Human metapneumovirus RNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.926 |  |  0 |         0 |
| 3037110 | Fasting glucose [Mass/volume] in Serum or Plasma | 0.926 |  |  0 |         0 |
| 40759039 | C peptide [Mass/volume] in Serum or Plasma --post meal | 0.925 |  |  0 |         0 |
| 1091652 | Human metapneumovirus RNA [Presence] in Sputum by NAA with probe detection | 0.925 |  |  0 |         0 |
| 649183 | Haemophilus influenzae F DNA [Presence] in Specimen by NAA with probe detection | 0.924 |  |  0 |         0 |
| 1091209 | Haemophilus influenzae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.921 |  |  0 |         0 |
| 3051746 | C peptide [Moles/volume] in Serum or Plasma --1.5 hours post dose glucose | 0.919 |  |  0 |         0 |
| 1091344 | Haemophilus parainfluenzae DNA [Presence] in Specimen by NAA with probe detection | 0.916 |  |  0 |         0 |
| 37019511 | Chlamydophila pneumoniae DNA [Presence] in Lower respiratory specimen by NAA with non-probe detection | 0.916 |  |  0 |         0 |
| 40763480 | Human metapneumovirus Ag [Presence] in Specimen | 0.915 |  |  1 |       301 |
| 36305584 | Mycoplasma pneumoniae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.915 |  |  0 |         0 |
| 1091945 | Legionella pneumophila DNA [Presence] in Nasopharynx by NAA with probe detection | 0.914 |  |  0 |         0 |
| 36305704 | Legionella pneumophila DNA [Presence] in Tissue by NAA with probe detection | 0.912 |  |  0 |         0 |
| 36660331 | C peptide [Mass/volume] in Serum or Plasma --1.5 hours post meal | 0.910 |  |  0 |         0 |
| 3047586 | C peptide [Moles/volume] in Serum or Plasma --1 hour post XXX challenge | 0.909 |  |  0 |         0 |
| 3049810 | C peptide [Moles/volume] in Serum or Plasma --1 minute post dose glucose | 0.908 |  |  0 |         0 |
| 3027467 | Mycoplasma sp DNA [Presence] in Specimen by NAA with probe detection | 0.907 | 1555 |  0 |         0 |
| 646649 | Chlamydophila pneumoniae DNA [Presence] in Specimen by NAA with non-probe detection | 0.906 |  |  0 |         0 |
| 1761538 | Legionella spp [Presence] in Specimen by NAA with probe detection | 0.906 |  |  0 |         0 |
| 37021263 | Human metapneumovirus Ag [Presence] in Upper respiratory specimen by Immunofluorescence | 0.905 |  |  0 |         0 |
| 3017703 | Fasting glucose [Moles/volume] in Capillary blood by Glucometer | 0.905 |  |  0 |         0 |
| 3052723 | C peptide [Moles/volume] in Serum or Plasma --1.5 hours post XXX challenge | 0.905 |  |  0 |         0 |
| 3049479 | C peptide [Moles/volume] in Serum or Plasma --2 hours post dose glucose | 0.905 |  |  0 |         0 |
| 3039848 | Human metapneumovirus Ag [Presence] in Specimen by Immunofluorescence | 0.900 |  |  0 |         0 |
| 3040151 | Glucose [Moles/volume] in Capillary blood | 0.900 |  | 16 |    37,386 |
| 40761619 | C peptide [Moles/volume] in Serum or Plasma --5 hours post dose glucose | 0.900 |  |  0 |         0 |
| 3009471 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma | 0.898 |  |  1 |       518 |
| 3039777 | Haemophilus influenzae B DNA [Presence] in Blood by NAA with probe detection | 0.897 |  |  0 |         0 |
| 36304484 | Chlamydophila pneumoniae DNA [Presence] in Aspirate by NAA with probe detection | 0.896 |  |  0 |         0 |
| 3050109 | C peptide [Moles/volume] in Serum or Plasma --5 minutes post dose glucose | 0.896 |  |  0 |         0 |
| 36660342 | C peptide [Mass/volume] in Serum or Plasma --2 hours post meal | 0.896 |  |  0 |         0 |
| 3053233 | C peptide [Moles/volume] in Serum or Plasma --10 minutes post dose glucose | 0.894 |  |  0 |         0 |
| 46235168 | Fasting glucose [Moles/volume] in Blood | 0.893 |  |  6 |     1,021 |
| 1616586 | Haemophilus influenzae DNA [Presence] in Synovial fluid by NAA with non-probe detection | 0.893 |  |  0 |         0 |
| 36660548 | C peptide [Mass/volume] in Serum or Plasma --5 hours post meal | 0.893 |  |  0 |         0 |
| 3034962 | Glucose [Mass/volume] in Capillary blood by Glucometer | 0.892 |  |  0 |         0 |
| 1091219 | Chlamydophila pneumoniae DNA [Presence] in Bronchoalveolar lavage by NAA with probe detection | 0.891 |  |  0 |         0 |
| 36303621 | Chlamydophila pneumoniae DNA [Presence] in Nasopharynx by NAA with probe detection | 0.890 |  |  0 |         0 |
| 3002225 | Fatty acids [Mass/volume] in Serum or Plasma | 0.889 |  |  0 |         0 |
| 37021514 | Human metapneumovirus Ag [Presence] in Lower respiratory specimen by Immunofluorescence | 0.888 |  |  0 |         0 |
| 1091284 | Glucose [Moles/volume] in Interstitial fluid | 0.886 |  |  0 |         0 |
| 1469787 | Haemophilus influenzae DNA [Presence] in Body fluid by NAA with non-probe detection | 0.886 |  |  0 |         0 |
| 3036505 | Phosphoethanolamine [Moles/volume] in Blood | 0.886 |  |  0 |         0 |
| 44787039 | Large unstained cells/Leukocytes in Cord blood by Automated count | 0.885 |  |  0 |         0 |
| 648705 | Haemophilus influenzae C DNA [Presence] in Specimen by NAA with probe detection | 0.885 |  |  0 |         0 |
| 3023122 | Fatty acids.very long chain [Moles/volume] in Serum or Plasma | 0.884 | 1826 |  0 |         0 |
| 1091501 | Haemophilus influenzae DNA [Presence] in Bronchoalveolar lavage by NAA with probe detection | 0.883 |  |  0 |         0 |
| 3023323 | Follitropin [Units/volume] in Serum or Plasma | 0.883 | 230 | 11 |    37,598 |
| 3966401 | Fasting glucose [Moles/volume] in Venous blood | 0.877 |  |  0 |         0 |
| 44787101 | Large unstained cells/Leukocytes in Blood from Fetus by Automated count | 0.876 |  |  0 |         0 |
| 3013826 | Glucose [Moles/volume] in Serum or Plasma | 0.872 | 4 | 53 | 1,339,897 |
| 3010224 | Large unstained cells/Leukocytes in Blood | 0.869 |  |  0 |         0 |
| 3006669 | Glucose [Moles/volume] in Serum or Plasma --pre 12 hour fast | 0.869 |  |  0 |         0 |
| 3009214 | Lutropin [Units/volume] in Serum or Plasma | 0.867 | 271 |  7 |    23,616 |
| 3044398 | Haemophilus influenzae B Ag [Presence] in Serum | 0.864 |  |  0 |         0 |
| 36305650 | Human metapneumovirus Ag [Presence] in Nasopharynx by Immunofluorescence | 0.856 |  |  0 |         0 |
| 3025226 | Haemophilus influenzae A Ag [Presence] in Specimen | 0.853 |  |  0 |         0 |
| 3024576 | Haemophilus influenzae B Ag [Presence] in Specimen | 0.849 |  |  0 |         0 |
| 42529215 | Follitropin [Units/volume] in Serum or Plasma by Immunoassay | 0.848 |  |  3 |    10,461 |
| 3002924 | Fatty acids.nonesterified [Mass/volume] in Serum or Plasma | 0.848 |  |  0 |         0 |
| 3039249 | Haemophilus influenzae Ag [Presence] in Urine | 0.848 |  |  0 |         0 |
| 3045692 | Fatty acids.very long chain C26:1 (Hexacosenoate) [Moles/volume] in Serum or Plasma | 0.847 |  |  0 |         0 |
| 3016014 | Fatty acids.esterified [Mass/volume] in Serum or Plasma | 0.847 |  |  0 |         0 |
| 3006467 | Fatty acids.very long chain C24:0 (Tetracosanoate) [Moles/volume] in Serum or Plasma | 0.846 |  |  0 |         0 |
| 3025178 | Haemophilus influenzae E Ag [Presence] in Specimen | 0.846 |  |  0 |         0 |
| 3025461 | Fatty acids.very long chain C26:0 (Hexacosanoate) [Moles/volume] in Serum or Plasma | 0.843 |  |  0 |         0 |
| 3031088 | Haemophilus influenzae B Ag [Presence] in Body fluid | 0.843 |  |  0 |         0 |
| 40762874 | Glucose [Moles/volume] in Capillary blood by Glucometer --7 AM specimen | 0.842 |  |  0 |         0 |
| 3002727 | Haemophilus influenzae B Ag [Presence] in Urine | 0.841 |  |  0 |         0 |
| 3009848 | Haemophilus influenzae A Ag [Presence] in Urine | 0.840 |  |  0 |         0 |
| 40761580 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --6th specimen fasting | 0.839 |  |  0 |         0 |
| 3029054 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --5th specimen fasting | 0.839 |  |  0 |         0 |
| 648169 | Glucose [Measurement] in Interstitial fluid | 0.838 |  |  0 |         0 |
| 46236948 | Glucose [Moles/volume] in Serum, Plasma or Blood | 0.837 |  |  0 |         0 |
| 3026840 | Haemophilus influenzae F Ag [Presence] in Specimen | 0.837 |  |  0 |         0 |
| 42529220 | Lutropin [Units/volume] in Serum or Plasma by Immunoassay | 0.837 |  |  0 |         0 |
| 3041651 | Fasting glucose [Moles/volume] in Urine | 0.832 |  |  0 |         0 |
| 3011562 | Phosphoethanolamine [Moles/volume] in Serum or Plasma | 0.831 |  |  0 |         0 |
| 37021229 | Gastrointestinal viral pathogens panel - Stool by NAA with probe detection | 0.827 |  |  0 |         0 |
| 3037523 | Haemophilus influenzae Ag [Presence] in Cerebral spinal fluid | 0.827 |  |  0 |         0 |
| 3044002 | Follitropin and Lutropin panel [Units/volume] - Serum or Plasma | 0.826 |  |  0 |         0 |
| 1989265 | Glucose [Mass/volume] in Interstitial fluid | 0.826 |  |  0 |         0 |
| 3044775 | Unidentified cells/Leukocytes in Blood by Automated count | 0.825 |  |  0 |         0 |
| 43055143 | Glucose [Moles/volume] in Blood by Automated test strip | 0.825 |  |  0 |         0 |
| 3031429 | Oleate (C18:1w9) [Moles/volume] in Serum or Plasma | 0.825 |  |  0 |         0 |
| 647347 | Glucose [Measurement] in Capillary blood | 0.823 |  |  0 |         0 |
| 3037187 | Fasting glucose [Mass/volume] in Venous blood | 0.822 |  |  0 |         0 |
| 3004077 | Glucose [Mass/volume] in Capillary blood | 0.821 |  |  0 |         0 |
| 3035250 | Fasting glucose [Mass/volume] in Capillary blood by Glucometer | 0.820 |  |  0 |         0 |
| 1091681 | Glucose [Moles/volume] in Reporting Period mean Interstitial fluid by calculation | 0.819 |  |  0 |         0 |
| 3025484 | Inhibin [Units/volume] in Serum or Plasma | 0.819 |  |  0 |         0 |
| 3029555 | Fatty acids.nonesterified [Moles/volume] in Serum or Plasma --1st specimen fasting | 0.818 |  |  0 |         0 |
| 3018171 | Choriogonadotropin [Units/volume] in Serum or Plasma | 0.815 | 252 | 12 |    54,905 |
| 3020491 | Glucose [Moles/volume] in Blood | 0.815 | 13 | 11 |     5,703 |
| 3004198 | Follitropin [Units/volume] in Serum or Plasma --baseline | 0.815 |  |  0 |         0 |
| 3006361 | Follitropin [Units/volume] in Serum or Plasma by 2nd IRP | 0.815 |  |  0 |         0 |
| 3031028 | Follitropin [Units/volume] in Serum or Plasma --1st specimen | 0.815 |  |  0 |         0 |
| 3029896 | Follitropin [Units/volume] in Serum or Plasma --5th specimen | 0.814 |  |  0 |         0 |
| 3009201 | Thyrotropin [Units/volume] in Serum or Plasma | 0.810 | 105 | 44 | 2,173,821 |
| 3029656 | Follitropin [Units/volume] in Serum or Plasma --7th specimen | 0.810 |  |  0 |         0 |
| 46235199 | Phosphatidylethanol [Presence] in Blood by Screen method | 0.806 |  |  0 |         0 |
| 3964626 | Phosphatidylethanol panel - Blood | 0.806 |  |  0 |         0 |
| 3051732 | Lutropin [Units/volume] in Serum or Plasma --pre 100 ug luteinizing releasing hormone IV | 0.806 |  |  0 |         0 |
| 3031024 | Follitropin [Units/volume] in Serum or Plasma --8th specimen | 0.804 |  |  0 |         0 |
| 3030288 | Follitropin [Units/volume] in Serum or Plasma --6th specimen | 0.803 |  |  0 |         0 |
| 3036078 | Lutropin [Moles/volume] in Serum or Plasma | 0.801 |  |  0 |         0 |
| 3025119 | Lutropin [Units/volume] in Serum or Plasma --baseline | 0.801 |  |  0 |         0 |
| 3021387 | Prolactin [Units/volume] in Serum or Plasma | 0.800 |  |  4 |    33,582 |
| 3027241 | Phosphoethanolamine [Moles/volume] in Urine | 0.796 |  |  0 |         0 |
| 3005019 | Lutropin [Units/volume] in Serum or Plasma --30 minutes post 100 ug luteinizing releasing hormone IV | 0.795 |  |  0 |         0 |
| 3024897 | Lutropin [Units/volume] in Serum or Plasma --1 hour post 100 ug luteinizing releasing hormone IV | 0.795 |  |  0 |         0 |
| 36305767 | Norovirus genogroups I and II RNA panel - Stool by NAA with probe detection | 0.788 |  |  0 |         0 |
| 40757457 | Phosphoethanolamine [Moles/volume] in DBS | 0.781 |  |  0 |         0 |
| 3021077 | Phosphoethanolamine [Mass/volume] in Serum or Plasma | 0.781 |  |  0 |         0 |
| 21492659 | Gastrointestinal pathogens panel - Stool by NAA with probe detection | 0.780 |  |  0 |         0 |
| 3000905 | Leukocytes [#/volume] in Blood by Automated count | 0.778 | 15 |  0 |         0 |
| 21493361 | Gastrointestinal pathogens DNA and RNA panel - Stool by NAA with non-probe detection | 0.778 |  |  0 |         0 |
| 42529121 | Adenovirus and Norovirus and Rotavirus Ag panel - Stool by Rapid immunoassay | 0.775 |  |  0 |         0 |
| 3001574 | Phosphoethanolamine [Moles/volume] in Amniotic fluid | 0.774 |  |  0 |         0 |
| 3044584 | Phosphoethanolamine [Moles/volume] in 24 hour Urine | 0.771 |  |  0 |         0 |
| 3035729 | Glucose [Moles/volume] in Body fluid | 0.753 | 788 |  0 |         0 |
| 1092353 | Enteric parasite panel - Stool by NAA with probe detection | 0.753 |  |  0 |         0 |
| 37021149 | Gastrointestinal parasitic pathogens panel - Stool by NAA with probe detection | 0.752 |  |  0 |         0 |
| 1617169 | Average glucose [Mass/volume] in Interstitial fluid during Reporting Period | 0.749 |  |  0 |         0 |
| 21492862 | Rotavirus and Adenovirus Ag panel - Stool by Rapid immunoassay | 0.743 |  |  0 |         0 |
| 21492668 | Gastrointestinal pathogens identified in Stool by NAA with probe detection | 0.740 |  |  0 |         0 |
| 37019628 | Gastrointestinal bacterial pathogens panel - Stool by NAA with probe detection | 0.735 |  |  1 |    17,394 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | loinc_name_guess | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|
| 1790 | b-fosfatidyylietanoli | umol/l | 4792 | 0 | [0.06, 0.1, 0.15, 0.22, 0.3, 0.44, 0.64, 0.94, 1.57] |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1791 | b-fosfatidyylietanoli |  | 4963 | 89.32 | [0.09, 0.13, 0.17, 0.29, 0.43, 0.63, 0.85, 1.22, 1.87] |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1792 | b-fosfatidyylietanoli,verestä | umol/l | 1555 | 0 | [0.06, 0.1, 0.15, 0.22, 0.29, 0.41, 0.59, 0.87, 1.44] |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1793 | b-fosfatidyylietanoli,verestä |  | 1534 | 97.07 |  |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1794 | b-fosfatidyylietanolivita | umol/l | 43 | 0 |  |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1795 | b-fosfatidyylietanolivita |  | 69 | 100 |  |  | Blood |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1796 | b-haemophilusinfluenzae |  | 144 | 100 |  |  | Blood |  | Haemophilus influenzae [Presence] in Blood | FALSE |
| 1797 | b-suuretvärjäytymättömätsolut | e9/l | 171 | 0 | [0.07, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.18] |  | Blood |  | Large unstained cells [#/volume] in Blood by Automated count | FALSE |
| 1798 | chlamydiapneumoniae,nukleiin |  | 109 | 100 |  |  |  |  | Chlamydia pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1799 | follikkeliastimuloivahormoni | u/l | 138 | 0 | [3, 4.75, 6.19, 8.24, 10, 19.35, 36.42, 56.82, 73.33] |  |  |  | Follicle-stimulating hormone [Units/volume] in Serum or Plasma | FALSE |
| 1800 | fosfatidyylietanoli | umol/l | 1540 | 0 | [0.05, 0.09, 0.14, 0.2, 0.29, 0.43, 0.63, 0.98, 1.62] |  |  |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1801 | fosfatidyylietanoli |  | 1635 | 92.35 | [0.09, 0.19, 0.32, 0.43, 0.64, 0.89, 1.16, 1.43, 1.78] |  |  |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1802 | fosfatidyylietanoli,verestä | umol/l | 3284 | 0 | [0.06, 0.08, 0.12, 0.16, 0.22, 0.3, 0.44, 0.66, 1.2] |  |  |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1803 | fosfatidyylietanoli,verestä |  | 3273 | 98.93 |  |  |  |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1804 | fosfatidyylietanoli,verestätth | umol/l | 35 | 0 |  |  |  |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1805 | fosfatidyylietanoli,verestätth |  | 66 | 100 |  |  |  |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1806 | fosfatidyylietanoli,veri | umol/l | 335 | 0 | [0.06, 0.1, 0.15, 0.2, 0.28, 0.39, 0.6, 0.91, 1.55] |  |  |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1807 | fosfatidyylietanoli,veri |  | 333 | 91.89 |  |  |  |  | Phosphatidylethanol [Moles/volume] in Blood | FALSE |
| 1808 | haemophilusinfluenzaenukleii |  | 459 | 100 |  |  |  |  | Haemophilus influenzae DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1809 | humaanimetapneumovirus,nukle |  | 109 | 100 |  |  |  |  | Human metapneumovirus RNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1810 | humanmetapneumovirus,ag |  | 102 | 100 |  |  |  |  | Human metapneumovirus Ag [Presence] in Respiratory system specimen by Immunoassay | FALSE |
| 1811 | l-suuretvärjääntymättömätsolut | % | 171 | 0 | [1.19, 1.35, 1.5, 1.62, 1.83, 1.97, 2.16, 2.45, 2.85] |  | Leukocyte |  | Large unstained cells/Leukocytes in Blood by Automated count | FALSE |
| 1812 | legionellapneumoniaenukleiin |  | 109 | 100 |  |  |  |  | Legionella pneumophila DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1813 | li-haemophilusinfluenzaenukl.haponos. |  | 119 | 100 |  |  | Cerebrospinal fluid |  | Haemophilus influenzae DNA [Presence] in Cerebral spinal fluid by NAA with probe detection | FALSE |
| 1814 | mycoplasmapneumoniae,nukleii |  | 141 | 100 |  |  |  |  | Mycoplasma pneumoniae DNA [Presence] in Respiratory system specimen by NAA with probe detection | FALSE |
| 1815 | p-follikkeliastimuloivahormoni | u/l | 511 | 0 | [2.89, 4.55, 5.71, 7.4, 9.51, 16.11, 32.21, 53.45, 77.25] |  | Plasma |  | Follicle-stimulating hormone [Units/volume] in Serum or Plasma | FALSE |
| 1816 | p-glukoosi,2tuntiaaterianjälkeen | mmol/l | 125 | 0 | [6.3, 7.71, 9.12, 10.17, 11.1, 12.22, 14.28, 15.89, 18.81] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post meal | FALSE |
| 1817 | p-glukoosi,toimintakokeissa,1h | mmol/l | 126 | 0 | [5.54, 6.18, 6.52, 7.01, 7.43, 7.82, 8.23, 9.1, 9.88] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --1 hour post dose glucose | FALSE |
| 1818 | p-glukoosi,toimintakokeissa,2h | mmol/l | 240 | 0 | [4.47, 5.01, 5.34, 5.8, 6.31, 7.03, 7.79, 8.75, 11.07] |  | Plasma |  | Glucose [Moles/volume] in Serum or Plasma --2 hours post dose glucose | FALSE |
| 1819 | p-glukoosi,toimntakokeissa0m | mmol/l | 242 | 0 | [4.3, 4.6, 4.8, 5.01, 5.22, 5.42, 5.83, 6.26, 6.93] |  | Plasma |  | Fasting glucose [Moles/volume] in Serum or Plasma | FALSE |
| 1820 | p-luteinisoivahormoni | u/l | 198 | 0 | [2.79, 3.77, 4.73, 5.42, 6.66, 8.63, 10.71, 14.48, 27.26] |  | Plasma |  | Luteinizing hormone [Units/volume] in Serum or Plasma | FALSE |
| 1821 | p-luteinisoivahormoni |  | 10 | 100 |  |  | Plasma |  | Luteinizing hormone [Units/volume] in Serum or Plasma | FALSE |
| 1822 | p-omagluk,,potilasmittaringlukoosi |  | 1376 | 100 |  |  | Plasma |  | Glucose [Moles/volume] in Capillary blood by Glucose meter | FALSE |
| 1823 | potilasmittaringlukoosi,ihopisto | mmol/l | 749 | 0 | [5.9, 6.36, 6.79, 7.19, 7.51, 7.86, 8.26, 8.85, 9.69] |  |  |  | Glucose [Moles/volume] in Capillary blood by Glucose meter | FALSE |
| 1824 | potilasmittaringlukoosi,ihopisto |  | 638 | 100 |  |  |  |  | Glucose [Moles/volume] in Capillary blood by Glucose meter | FALSE |
| 1825 | potilasmittaringlukoosi,sensori | mmol/l | 201 | 0 | [5.55, 6.53, 7.01, 7.7, 8.35, 9.14, 10.02, 11.7, 13.49] |  |  |  | Glucose [Moles/volume] in Interstitial fluid by Glucose monitoring device | FALSE |
| 1826 | potilasmittaringlukoosi,sensori |  | 568 | 100 |  |  |  |  | Glucose [Moles/volume] in Interstitial fluid by Glucose monitoring device | FALSE |
| 1827 | s-c-peptidi1haterianjälkeen | nmol/l | 275 | 0 | [0.5, 0.75, 0.96, 1.2, 1.4, 1.62, 1.92, 2.33, 3.08] |  | Serum |  | C-peptide [Moles/volume] in Serum or Plasma --1 hour post meal | FALSE |
| 1828 | s-c-peptidi1haterianjälkeen |  | 10 | 90 |  |  | Serum |  | C-peptide [Moles/volume] in Serum or Plasma --1 hour post meal | FALSE |
| 1829 | s-c-peptidiaterianjälkeen | nmol/l | 150 | 0 | [0.4, 0.65, 0.9, 1.07, 1.22, 1.49, 2.03, 2.41, 2.88] |  | Serum |  | C-peptide [Moles/volume] in Serum or Plasma --post meal | FALSE |
| 1830 | s-follikkeliastimuloivahormoni | iu/l | 416 | 0 | [3.31, 4.85, 6.04, 7.33, 10.33, 18.46, 32.36, 54.77, 76.02] |  | Serum |  | Follicle-stimulating hormone [Units/volume] in Serum or Plasma | FALSE |
| 1831 | s-follikkeliastimuloivahormoni | u/l | 80 | 0 | [3.2, 4.8, 5.65, 6.55, 7.78, 10.22, 16.95, 45.35, 68.7] |  | Serum |  | Follicle--stimulating hormone [Units/volume] in Serum or Plasma | FALSE |
| 1832 | s-follikkeliastimuloivahormoni |  | 7 | 100 |  |  | Serum |  | Follicle-stimulating hormone [Units/volume] in Serum or Plasma | FALSE |
| 1833 | s-kertatyydyttymättömätrasvahapot | mmol/l | 263 | 0 | [2.43, 2.7, 2.8, 2.99, 3.17, 3.35, 3.54, 3.9, 4.36] |  | Serum |  | Fatty acids.monounsaturated [Moles/volume] in Serum or Plasma | FALSE |
| 1834 | s-luteinisoivahormoni | iu/l | 178 | 0 | [1.51, 2.37, 3.11, 3.71, 4.6, 5.61, 7.56, 11.94, 22.46] |  | Serum |  | Luteinizing hormone [Units/volume] in Serum or Plasma | FALSE |
| 1835 | s-luteinisoivahormoni | u/l | 26 | 0 |  |  | Serum |  | Luteinizing hormone [Units/volume] in Serum or Plasma | FALSE |
| 1836 | s-luteinisoivahormoni |  | 14 | 100 |  |  | Serum |  | Luteinizing hormone [Units/volume] in Serum or Plasma | FALSE |
| 1837 | s-monityydyttymättömätrasvahapot | mmol/l | 255 | 0 | [4.74, 4.99, 5.23, 5.48, 5.58, 5.7, 5.92, 6.18, 6.55] |  | Serum |  | Fatty acids.polyunsaturated [Moles/volume] in Serum or Plasma | FALSE |
| 1838 | s-monityydyttymättömätrasvahapot |  | 11 | 100 |  |  | Serum |  | Fatty acids.polyunsaturated [Moles/volume] in Serum or Plasma | FALSE |
| 1839 | s-tyydyttyneetrasvahapot | mmol/l | 265 | 0 | [3.09, 3.37, 3.58, 3.77, 3.9, 4.15, 4.36, 4.73, 5.26] |  | Serum |  | Fatty acids.saturated [Moles/volume] in Serum or Plasma | FALSE |
| 1840 | ulosteenripulivirukset,nukle |  | 109 | 100 |  |  |  |  | Viral agents causing diarrhea panel - Stool by NAA | TRUE |

