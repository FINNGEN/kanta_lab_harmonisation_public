# InitialIdeas — Kanta lab harmonisation deck

[Marp](https://marp.app) deck walking the pipeline from a local `TEST_NAME` +
`UNIT` to an OMOP concept, scored against the curated reference mapping.

| file | what it is |
|---|---|
| `kantaLabHarmonisation.md` | the deck — **the only file to edit** |
| `kantaLabHarmonisation.html` | rendered, self-contained; open in a browser |
| `kantaLabHarmonisation.pdf` | rendered for printing / sharing |
| `draft.md` | the original outline the deck was built from |

## Rebuild

```bash
cd PRESENTATIONS/InitialIdeas
npx @marp-team/marp-cli@latest kantaLabHarmonisation.md --html -o kantaLabHarmonisation.html
npx @marp-team/marp-cli@latest kantaLabHarmonisation.md --pdf  -o kantaLabHarmonisation.pdf
```

Live preview while editing: `npx @marp-team/marp-cli@latest -s .`, or the
*Marp for VS Code* extension.

## Where the numbers come from

Every figure in the deck is read out of a committed `DATA_v4` artifact — nothing
is typed by hand. If the pipeline is re-run, re-read these and update the deck:

| slide | source |
|---|---|
| v3 -> v4 coverage | `DATA_v3/1_GetSummaryData/labSummaryStats.md`, `DATA_v4/1_GetSummaryData/labSummaryStats.md` |
| initial data | `DATA_v4/1_GetSummaryData/labSummary.tsv` |
| appended information | `DATA_v4/2_AppendKnownInformation/knownInformation.tsv` |
| grouping | `DATA_v4/3_GroupCodesByStringDistance/knownInformationGroupedStats.md`, that step's `log.txt` |
| guessed LOINC names | `DATA_v4/4_FindLOINC/codesWithLoincNames.tsv`, `groupsCache/<group_id>_prompt.md` |
| candidates and picks | `DATA_v4/5_FixLOINC/hecateCandidates.tsv`, `codesWithOmopConcepts.tsv`, `groupsCache/` |
| all results tables | `DATA_v4/6_EvaluateMapping/loincToOmopMappingStats.md` |
| LOINC Group background | `RESEARCH/UnderstandingGroups.md` |

## The five running examples

One set of five codes is traced through every step, chosen to cover all four
outcomes and both failure modes:

| code | unit | why it is in the deck |
|---|---|---|
| `p-na` | `mmol/l` | full evidence -> exact agreement; the happy path |
| `p-na` | *(none)* | **same code, no unit** -> declined; the main loss mechanism |
| `u-gluk-o` | *(none)* | name only, but `(kval)` + suffix `-o` settle it -> exact agreement |
| `ab-ca-ion` | `mmol/l` | prefix read literally -> `Arterial blood` vs reference's `Serum or Plasma`; recovered at LOINC Group level |
| `b-hba1c` | `mmol/mol` | full evidence, still declined — the IFCC concept was missing from the shortlist; a retrieval failure |

The deck is scoped, like the pipeline run it describes, to **30 of the 164
groups** (random sample, seed 1) resolved with `gemini-2.5-pro`.
