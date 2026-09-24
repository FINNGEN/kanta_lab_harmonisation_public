[System Prompt]
You are a LOINC mapping expert with deep knowledge of the Finnish national laboratory coding system (Laboratoriotutkimusnimikkeistö, maintained by Kuntaliitto / Kodistopalvelu) and of the OMOP CDM representation of LOINC.

An earlier pass already inferred the six LOINC axes for each of these local Finnish lab codes. Your task is **not** to redo that work. It is to **correct the axis labels so they are real OMOP vocabulary terms**, using a shortlist of genuine candidates retrieved for each value.

# Why this pass exists

The earlier pass wrote each axis as free text. Measured against curated Finnish mappings, most values were real OMOP terms but the wrong one, and `has_component` in particular drifted off the controlled vocabulary entirely — roughly three quarters of its mismatches were near-miss paraphrases that do not exist anywhere in OMOP, e.g. `Transglutaminase IgA Ab` where OMOP has `Tissue Transglutaminase IgA`, or `gamma-Glutamyl transferase` where OMOP has `Gamma glutamyl transferase`.

A label that is one character off is worthless downstream: the mapping joins on exact axis values, so a near-miss fails just as hard as nonsense. Your job is to land each axis on the exact OMOP string.

# The Finnish laboratory coding system

Each national lab test has a 4-digit running number code and a short mnemonic abbreviation of at most 10 characters, built as:

    <system prefix> - <test abbreviation> [<suffix>]

- The **system prefix** is a 1-2 letter code for the specimen the sample came from, mostly from English words: `S` = serum, `P` = plasma, `B` = blood, `U` = urine, `Li` = cerebrospinal fluid, `F` = feces, `Ts` = tissue, `Pt` = patient (a whole-patient investigation), `fS`/`fP`/`fB` = fasting serum/plasma/blood, `dU` = 24-hour urine, `E` = erythrocyte, `L` = leukocyte.
- The **test abbreviation** is a mnemonic of the test's long Finnish name, occasionally an established international one (`CRP`, `TSH`).
- The optional **suffix** qualifies the result type or method: `-O` (qualitative/semi-quantitative), `-Ab` (antibodies), `-Ag` (antigen), `-Vi` (culture), `-Nh` (nucleic acid), `-Ion` (ionized), `-V` (free/unconjugated).

Finnish compounds run together: "transferriininrautakyllästeisyys" = transferrin iron saturation.

# What you are given

**The group table** — a markdown table, one row per local lab test/unit combination, with the columns:

- `row_id` — unique integer. **Echo it back exactly**; it is the only join key.
- `TEST_NAME` — the local code, lowercased, spaces removed.
- `UNIT` — the recorded unit; may be empty.
- `n` — number of records.
- `p_missing` — percentage (0-100) of records with no numeric value.
- `deciles` — the 9 deciles of observed values, when available. The strongest single evidence for what a test really measures: a "sodium" code whose deciles read 0.32-0.40 is not sodium.
- `LongName`, `prefix_meaning`, `suffix_meaning` — decoded from the national code table, when available.
- `has_component`, `has_property`, `has_method`, `has_system` — the **current, possibly wrong** axis values from the earlier pass.
- `has_scale_type`, `has_time_aspect`, `is_panel` — already drawn from closed lists in the earlier pass. Carry them through unchanged unless a row is plainly contradictory.

**The candidate tables** — one markdown table per free-text axis, listing for each distinct current value in this group the closest real OMOP terms from a semantic search over the LOINC vocabulary. Columns:

- `current` — the value the earlier pass produced. It repeats down the rows: every row with the same `current` is an alternative for that one value.
- `possible fix` — a real OMOP term you may replace it with. `(none scored >= ...)` means the search found nothing close enough, so that value has no suggested replacement.
- `score` — semantic similarity between `current` and `possible fix`, 0 to 1. **A score of 1.000 does NOT mean the two strings are identical** — the search is case-insensitive, so `Mass Fraction` scores 1.000 against the real OMOP term `Mass fraction`. Always compare the two strings character for character yourself.
- `n_codes` / `n_events` — how many curated Finnish lab codes use that term, and how many records they cover. **This is usage in Finland, not correctness.** Use it only to break ties between candidates that fit the evidence equally well; never to override what the row's own evidence says.

# How to decide

For each row and each of the four axes:

1. **If `possible fix` is character-for-character identical to `current`, keep it.** It is already an exact OMOP term; do not "improve" it. But if a row scores 1.000 while the two strings differ in any way — capitalisation, punctuation, spacing — **take the `possible fix`**: that column holds the real OMOP spelling and `current` does not. `Mass Fraction` must become `Mass fraction`.
2. **Otherwise pick the candidate that the row's own evidence supports** — `TEST_NAME`, `LongName`, `UNIT`, `deciles`, the prefix/suffix meanings. Prefer the exact OMOP spelling of the concept the code actually denotes.
3. **Where two candidates fit equally**, prefer the one with higher `n_codes`/`n_events` — Finland's established usage.
4. **If no candidate is right, leave the axis empty.** An empty axis is a correct, useful answer: it says "not knowable". A confidently wrong exact term is worse than nothing, because downstream code cannot tell it from a verified one.
5. **Never invent a value that is not in the candidate list.** The whole point of this pass is that only real OMOP terms survive. The one exception: if an axis is currently empty and the evidence genuinely supports no value, leave it empty.

Specific things to watch:

- **`has_system` was the worst axis in the earlier pass** (about 29% agreement). The recurring error is splitting `Serum or Plasma` into a bare `Serum` or `Plasma`. LOINC uses the combined `Serum or Plasma` for most chemistry, and only a genuinely serum-specific or plasma-specific test takes the narrow term. Let the code decide: an explicit `S` prefix means serum, `P` means plasma, and an ambiguous or absent prefix on a routine chemistry test usually means `Serum or Plasma`. Fasting is not part of the system: `fS` is still serum.
- **`has_component` drifts most.** Take the candidate's exact spelling, including its capitalisation and word order (`Gamma glutamyl transferase`, not `gamma-Glutamyl transferase`).
- **`has_method` is optional by design** and empty for most chemistry. If the earlier pass invented a method the code does not state, clear it.
- **`has_property`** follows the unit and the decile magnitude, not the analyte name: `g/l`, `mg/l`, `ug/l` are `Mass Concentration`; `mol/l`, `mmol/l`, `umol/l`, `nmol/l` are `Substance Concentration`; `U/l` is `Catalytic Concentration`.
- Never use the OMOP placeholder values `-`, `*` or `XXX`; leave the axis empty instead.

# Output

Return one entry per input row, with `row_id` echoed exactly and all seven fields. Return an entry for EVERY row, including ones you change nothing on — carrying a value through unchanged is a valid answer.

Also return a short `reflection` (a few sentences, markdown) on THIS group: which corrections you made and why, where the candidate lists were unhelpful or missing the right term, and anything about the data or this process that should improve. Be concrete about the rows you just saw; do not repeat these instructions back.

[Prompt]
Here is group 20.

## Candidate OMOP terms for the values used in this group

### component

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Campylobacter | Campylobacter sp | 0.798 | 2 | 22,946 |
| Cryptococcus neoformans/gattii | Cryptococcus gattii+neoformans | 0.860 | 0 | 0 |
| Cryptococcus neoformans/gattii | Cryptococcus gattii | 0.828 | 0 | 0 |
| Cryptococcus neoformans/gattii | Cryptococcus neoformans | 0.798 | 0 | 0 |
| Cryptococcus neoformans/gattii | Cryptococcus gattii+neoformans DNA | 0.770 | 0 | 0 |
| Cytomegalovirus | Cytomegalovirus | 1.000 | 0 | 0 |
| Cytomegalovirus | Cytomegalovirus Ab | 0.788 | 1 | 83 |
| Cytomegalovirus | Cytomegalovirus Ag | 0.778 | 0 | 0 |
| Cytomegalovirus | Cytomegalovirus DNA | 0.777 | 8 | 64,352 |
| Cytomegalovirus | Cytomegalovirus IgG | 0.772 | 6 | 29,759 |
| EKG monitoring for atrial fibrillation | (none scored >= 0.75) |  |  |  |
| EKG study | EKG study | 1.000 | 10 | 506,024 |
| EKG study | EEG study | 0.785 | 0 | 0 |
| EKG study | Cardiac stress EKG study | 0.767 | 0 | 0 |
| Escherichia coli enteroaggregative | Escherichia coli enteroaggregative | 1.000 | 0 | 0 |
| Escherichia coli enteroaggregative | Escherichia coli enteroaggregative DNA | 0.858 | 0 | 0 |
| Escherichia coli enteroaggregative | Escherichia coli enteroaggregative pAA plasmid aggR+aatA genes | 0.792 | 0 | 0 |
| Escherichia coli enteroaggregative | Escherichia coli enteropathogenic | 0.783 | 0 | 0 |
| Escherichia coli enteroaggregative | Escherichia coli enteroaggregative astA gene | 0.758 | 0 | 0 |
| Escherichia coli enterohemorrhagic | Escherichia coli enteropathogenic | 0.807 | 0 | 0 |
| Escherichia coli enterohemorrhagic | Escherichia coli enteroinvasive | 0.786 | 0 | 0 |
| Escherichia coli enterohemorrhagic | Escherichia coli enterotoxic | 0.756 | 0 | 0 |
| Escherichia coli enteropathogenic | Escherichia coli enteropathogenic | 1.000 | 0 | 0 |
| Escherichia coli enteropathogenic | Escherichia coli enteroinvasive | 0.835 | 0 | 0 |
| Escherichia coli enteropathogenic | Escherichia coli enteropathogenic DNA | 0.828 | 0 | 0 |
| Escherichia coli enteropathogenic | Escherichia coli enterotoxic | 0.790 | 0 | 0 |
| Escherichia coli enteropathogenic | Escherichia coli enterotoxigenic | 0.786 | 0 | 0 |
| Escherichia coli enterotoxigenic | Escherichia coli enterotoxigenic | 1.000 | 0 | 0 |
| Escherichia coli enterotoxigenic | Escherichia coli enterotoxigenic heat-labile toxin | 0.845 | 0 | 0 |
| Escherichia coli enterotoxigenic | Escherichia coli enterotoxic | 0.830 | 0 | 0 |
| Escherichia coli enterotoxigenic | Escherichia coli enterotoxigenic DNA | 0.826 | 0 | 0 |
| Escherichia coli enterotoxigenic | Escherichia coli enteropathogenic | 0.786 | 0 | 0 |
| Escherichia coli K1 | Escherichia coli K1 | 1.000 | 0 | 0 |
| Escherichia coli K1 | Escherichia coli K1 Ag | 0.796 | 0 | 0 |
| Herpes simplex virus 1 | Herpes simplex virus 1 | 1.000 | 0 | 0 |
| Herpes simplex virus 1 | Herpes simplex virus | 0.867 | 1 | 1,154 |
| Herpes simplex virus 1 | Herpes simplex virus 1 and 2 | 0.843 | 0 | 0 |
| Herpes simplex virus 1 | Herpes simplex virus 1+2 | 0.810 | 0 | 0 |
| Herpes simplex virus 1 | Herpes simplex virus 2 | 0.798 | 0 | 0 |
| Herpes simplex virus 2 | Herpes simplex virus 2 | 1.000 | 0 | 0 |
| Herpes simplex virus 2 | Herpes simplex virus | 0.784 | 1 | 1,154 |
| Herpes simplex virus 2 | Herpes simplex virus 2 Ab | 0.777 | 0 | 0 |
| Herpes simplex virus 2 | Herpes simplex virus 2 Ag | 0.770 | 0 | 0 |
| Herpes simplex virus 2 | Herpes simplex virus 1 and 2 | 0.766 | 0 | 0 |
| Listeria monocytogenes | Listeria monocytogenes | 1.000 | 0 | 0 |
| Neisseria meningitidis | Neisseria meningitidis | 1.000 | 0 | 0 |
| Neisseria meningitidis | Neisseria meningitidis type | 0.815 | 0 | 0 |
| Neisseria meningitidis | Neisseria meningitidis serogroup | 0.810 | 0 | 0 |
| Neisseria meningitidis | Neisseria meningitdis B | 0.808 | 0 | 0 |
| Neisseria meningitidis | Neisseria meningitidis serogroup A | 0.806 | 0 | 0 |
| Plesiomonas shigelloides | Plesiomonas shigelloides | 1.000 | 0 | 0 |
| Salmonella | Salmonella sp | 0.781 | 3 | 41,500 |
| Salmonella | Salmonella spp | 0.778 | 0 | 0 |
| Shigella/Escherichia coli enteroinvasive | Escherichia coli enteroinvasive | 0.824 | 0 | 0 |
| Streptococcus agalactiae | Streptococcus agalactiae | 1.000 | 1 | 22,188 |
| Streptococcus agalactiae | Streptococcus agalactiae Ag | 0.799 | 1 | 10,143 |
| Streptococcus agalactiae | Mycoplasma agalactiae | 0.785 | 0 | 0 |
| Streptococcus agalactiae | Streptococcus agalactiae DNA | 0.753 | 0 | 0 |
| Streptococcus pneumoniae | Streptococcus pneumoniae | 1.000 | 0 | 0 |
| Varicella zoster virus | Varicella zoster virus | 1.000 | 0 | 0 |
| Varicella zoster virus | Varicella zoster virus strain | 0.857 | 0 | 0 |
| Varicella zoster virus | Varicella zoster virus DNA | 0.830 | 2 | 5,511 |
| Varicella zoster virus | Varicella zoster virus identified | 0.819 | 0 | 0 |
| Varicella zoster virus | Varicella zoster virus status | 0.810 | 0 | 0 |
| Yersinia enterocolitica | Yersinia enterocolitica | 1.000 | 0 | 0 |
| Yersinia enterocolitica | Yersinia enterocolitica Ab | 0.831 | 0 | 0 |
| Yersinia enterocolitica | Yersinia enterocolitica biotype | 0.809 | 0 | 0 |
| Yersinia enterocolitica | Yersinia enterocolitica O:9 | 0.807 | 0 | 0 |
| Yersinia enterocolitica | Yersinia pseudotuberculosis | 0.798 | 0 | 0 |

### property

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| Finding | Finding | 1.000 | 52 | 1,337,646 |
| Presence or Identity | Presence or Identity | 1.000 | 79 | 1,946,967 |

### method

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| 12 lead | (none scored >= 0.75) |  |  |  |
| 12 lead with interpretation | (none scored >= 0.75) |  |  |  |
| Monitor | (none scored >= 0.75) |  |  |  |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with probe detection | 1.000 | 115 | 2,413,483 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification with non-probe detection | 0.864 | 1 | 7,786 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5a | 0.770 | 0 | 0 |
| Nucleic acid amplification with probe detection | Probe with amplification | 0.759 | 2 | 14,699 |
| Nucleic acid amplification with probe detection | Nucleic acid amplification using primer-probe set H5b | 0.754 | 0 | 0 |

### system

| current | possible fix | score | n_codes | n_events |
|---|---|---|---|---|
| ^Patient | ^Patient | 1.000 | 20 | 396,517 |
| Cerebral spinal fluid | Cerebral spinal fluid | 1.000 | 150 | 183,922 |
| Stool | Stool | 1.000 | 42 | 537,967 |
| Stool | Stool.wet | 0.760 | 0 | 0 |
| Stool | Stool^Patient.gastrointestinal | 0.756 | 0 | 0 |

## The rows

| row_id | TEST_NAME | UNIT | n | p_missing | deciles | LongName | prefix_meaning | suffix_meaning | has_component | has_property | has_method | has_system | has_scale_type | has_time_aspect | is_panel |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 109 | ehec(enterohemorraaginene.coli) |  | 1317 | 100 |  |  |  |  | Escherichia coli enterohemorrhagic | Presence or Identity |  |  | Nom | Point in time (spot) | FALSE |
| 110 | ekg,12kytkentäälevossa |  | 6937 | 99.99 |  |  |  |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 111 | ekg,12kytkentäälevossa(asi |  | 8872 | 100 |  |  |  |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 112 | ekg,12kytkentäälevossa(asiakkaanottama) |  | 2232 | 100 |  |  |  |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 113 | ekg,12kytkentäälevossa(asiakkanottama) |  | 1287 | 100 |  |  |  |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 114 | ekg-12kytkentäälevossa |  | 2227 | 100 |  |  |  |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 115 | enteroaggregatiivinene.colinho |  | 229 | 100 |  |  |  |  | Escherichia coli enteroaggregative | Presence or Identity | Nucleic acid amplification with probe detection |  | Nom | Point in time (spot) | FALSE |
| 116 | enterohemorraginene.colinho |  | 383 | 100 |  |  |  |  | Escherichia coli enterohemorrhagic | Presence or Identity | Nucleic acid amplification with probe detection |  | Nom | Point in time (spot) | FALSE |
| 117 | enteropatogeeninene.colinho |  | 229 | 100 |  |  |  |  | Escherichia coli enteropathogenic | Presence or Identity | Nucleic acid amplification with probe detection |  | Nom | Point in time (spot) | FALSE |
| 118 | enterotoksigeeninene.colinho |  | 383 | 100 |  |  |  |  | Escherichia coli enterotoxigenic | Presence or Identity | Nucleic acid amplification with probe detection |  | Nom | Point in time (spot) | FALSE |
| 119 | etec(enterotoksigeeninene.coli) |  | 1317 | 100 |  |  |  |  | Escherichia coli enterotoxigenic | Presence or Identity |  |  | Nom | Point in time (spot) | FALSE |
| 120 | f-campylobacterspp.(jejuni&coli)nukl.haponos |  | 607 | 100 |  |  | Feces |  | Campylobacter | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 121 | f-ehec(enterohemorraaginene.coli)nukl.haponos |  | 607 | 100 |  |  | Feces |  | Escherichia coli enterohemorrhagic | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 122 | f-etec(enterotoksigeeninene.coli)nukl.haponos |  | 607 | 100 |  |  | Feces |  | Escherichia coli enterotoxigenic | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 123 | f-plesiomonasshigelloidesnukl.haponos. |  | 607 | 100 |  |  | Feces |  | Plesiomonas shigelloides | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 124 | f-salmonellaspp.nukl.haponos |  | 607 | 100 |  |  | Feces |  | Salmonella | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 125 | f-shigellaspp./eiec(enteroinvasiivinene.coli)nukl.haponos |  | 616 | 100 |  |  | Feces |  | Shigella/Escherichia coli enteroinvasive | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 126 | f-yersiniaenterocoliticanukl.haponos. |  | 607 | 100 |  |  | Feces |  | Yersinia enterocolitica | Presence or Identity | Nucleic acid amplification with probe detection | Stool | Nom | Point in time (spot) | FALSE |
| 127 | li-cryptococcusneoformans,nukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Cryptococcus neoformans/gattii | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 128 | li-cytomegalovirusnukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Cytomegalovirus | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 129 | li-escherichiacolik1nukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Escherichia coli K1 | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 130 | li-herpessimplex1,nukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Herpes simplex virus 1 | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 131 | li-herpessimplex2,nukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Herpes simplex virus 2 | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 132 | li-l.monocytogenesnukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Listeria monocytogenes | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 133 | li-neisseriameningitidisnukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Neisseria meningitidis | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 134 | li-streptococcusagalactiaenukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Streptococcus agalactiae | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 135 | li-streptococcuspneumoniaenukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Streptococcus pneumoniae | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 136 | li-varicella-zosternukl.haponos. |  | 129 | 100 |  |  | Cerebrospinal fluid |  | Varicella zoster virus | Presence or Identity | Nucleic acid amplification with probe detection | Cerebral spinal fluid | Nom | Point in time (spot) | FALSE |
| 137 | pt-ekg,12kytkentälevossa |  | 243 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 138 | pt-ekg,12kytkentää6tk |  | 368 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 139 | pt-ekg,12kytkentääep-terveyskeskus |  | 206 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 140 | pt-ekg,12kytkentäälevossa | 1 | 55 | 0 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Nom | Procedure | FALSE |
| 141 | pt-ekg,12kytkentäälevossa |  | 54957 | 99.91 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 142 | pt-ekg,12kytkentäälevossa(k-pks:n)(ko) |  | 272 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 143 | pt-ekg,12kytkentäälevossa(ot.tk:ssa) |  | 210 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 144 | pt-ekg,12kytkentäälevossa,omarekisteröintimuseen |  | 2847 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 145 | pt-ekg,12kytkentäälevossaosastolla |  | 193 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 146 | pt-ekg,12kytkentäälevossa␤ |  | 2419 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead | ^Patient | Doc | Study | FALSE |
| 147 | pt-ekg,eteisvärinänseulonta,valvontamonitori-ekg |  | 477 | 100 |  |  | Patient |  | EKG monitoring for atrial fibrillation | Finding | Monitor | ^Patient | Doc | Study | FALSE |
| 148 | pt-ekg,eteisvärinänseulonta,valvontamonitori-ekg,lisätallenne |  | 625 | 100 |  |  | Patient |  | EKG monitoring for atrial fibrillation | Finding | Monitor | ^Patient | Doc | Study | FALSE |
| 149 | pt-ekg,sisältäentietokoneanalyysin |  | 8257 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead with interpretation | ^Patient | Doc | Study | FALSE |
| 150 | pt-ekg,sisältäentietokoneanalyysin(malmin)(pi) |  | 226 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead with interpretation | ^Patient | Doc | Study | FALSE |
| 151 | pt-ekg,sisältäätietokoneanalyysin |  | 4178 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead with interpretation | ^Patient | Doc | Study | FALSE |
| 152 | pt-ekgsis[lt[entietokoneanalyysin |  | 305 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead with interpretation | ^Patient | Doc | Study | FALSE |
| 153 | pt-ekgsisältäentietokoneanalyysin |  | 347 | 100 |  |  | Patient |  | EKG study | Finding | 12 lead with interpretation | ^Patient | Doc | Study | FALSE |
| 154 | shigella/eiec(enteroinvasiivinene.coli) |  | 1318 | 100 |  |  |  |  | Shigella/Escherichia coli enteroinvasive | Presence or Identity |  |  | Nom | Point in time (spot) | FALSE |

