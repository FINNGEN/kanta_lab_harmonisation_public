# FindLOINCDimensions

Guesses the **LOINC Long Common Name** of every local Finnish lab code.

## Inputs

- `DATA/GroupKnownInformationTable/knownInformationGrouped.tsv` — one row per
  local `TEST_NAME`/`UNIT`, with `n`, `value_missing_p`, `value_deciles`, `LongName`,
  `prefix_meaning`, `suffix_meaning`, clustered into similarity groups by
  `group_id` / `group_path`.
- `scripts/systemPrompt.md` — the system prompt: the LOINC-expert role, the
  Finnish lab coding system, how it maps onto the table's columns, the caveats
  about this data, and the rules for building a LOINC Long Common Name. It is
  read verbatim: **nothing derived from the curated reference mappings is
  injected into it**, since those mappings are what the pipeline is measured
  against — showing the model their concepts would make the evaluation
  circular and hand it whatever errors the reference itself carries.

## Outputs

- `DATA/FindLOINCDimensions/codesWithLoincNames.tsv` — every processed row of
  the input table, unchanged, with four columns appended. Two are **computed
  evidence**, not model output — they are facts about the table, so deriving
  them in R costs no tokens and leaves nothing for the model to misreport, and
  `FixLOINCDimensions` and the reports read them too:
  - `unit_share` — what percentage of this `TEST_NAME`'s records carry this
    row's `UNIT`, computed over the whole input table. A unit holding a sliver
    of a code's records while another unit holds the rest is far more likely a
    data-entry error than a second real test.
  - `evidence_level` — `name+unit+values`, `name+unit`, `name+values`, or
    `name`, from whether the row has a `UNIT` and a `value_deciles`
    distribution. This is what bounds how far a row may be pushed: a
    `name` row has nothing to fix the quantity with, and the prompt
    requires it to be left unnamed unless the name alone settles the concept.
    It also splits the reports, since a `name`-only row is where this
    pipeline's target and the reference's differ by construction.
  - `loinc_name_guess` — the LOINC Long Common Name the model believes this
    code maps to, spelled as LOINC spells it:
    `<Component> [<Property>] in <System> by <Method>`, e.g.
    `Creatinine [Moles/volume] in Serum or Plasma`. Empty **only** when the
    code text carries no usable hint at all — a bare running number, an
    administrative label, a string too garbled to read an analyte out of.

    The name is a search query, not a verdict, and the prompt is written
    around that: it is fed to a semantic search and `FixLOINCDimensions`
    chooses from the real concepts that come back. A near-miss still retrieves
    the right neighbourhood of concepts, so being wrong here is cheap, while
    an empty name retrieves nothing and drops the code from consideration
    entirely. Abstaining is the next step's job — it is the one that can hold
    a guess up against real concepts and conclude none of them fits.
  There is no `is_panel` column. LOINC names panels *as panels* — the word
  `panel` appears in 81% of its panel concepts, only 6% carry a `[Property]`
  (a bundle has no single quantity), and the system follows a dash rather than
  `in`, as in `CBC panel - Blood by Automated count`. So a bundle is expressed
  in the guessed name itself, and the prompt explains that form along with the
  Finnish cues for it (`-seula`/`-seulonta`, `-paketti`, a `LongName` listing
  several analytes, and `B-PVK` vs `B-TVK`).
- `DATA/FindLOINCDimensions/reflections.md` — one `# Group <id>` section per
  group, holding that group's reflection from the model: ideas to improve the
  process, gotchas, ambiguities and data problems it hit on those rows.
- `DATA/FindLOINCDimensions/loincNamesStats.md` — a stats report over
  `codesWithLoincNames.tsv`: how many codes could be named, how closely the
  guesses follow the LOINC name template, the most frequently guessed names and
  the `[Property]` / `in <System>` / `by <Method>` parts they carry, and a
  **Findings** section in which the per-group reflections are sent back to the
  model and distilled into recurring key findings, suggested improvements, and
  systematic data problems.
- `DATA/FindLOINCDimensions/groupsCache/<group_id>.json` — the model's raw
  structured answer for one group, and `<group_id>_prompt.md` the exact prompt
  that produced it, examples and all. The `.json` files are a **cache**: a
  re-run only calls the LLM for groups that have none, so the step is resumable
  and re-running it after a partial failure costs nothing for groups already
  done.
- `DATA/FindLOINCDimensions/log.txt` — run log: `run.sh`'s `tee` capturing both
  its own output and the R script's `ParallelLogger` console output, per
  `development/STYLE.md`.

## Action

`scripts/findLoincNames.R` sends **one LLM call per similarity group**, in
parallel across workers, and joins the answers back into one table.

The model is asked for a **name**, not for the six LOINC axes. The axes are
still how it reasons — component, property, time, system, scale, method — but
it returns the single string they compose into. That string is not expected to
be a real LOINC name: it is a **search query**. `FixLOINCDimensions` feeds it
to a semantic search over the LOINC vocabulary and asks a second pass to pick
the real concept it was aiming at.

This is why the step changed shape. An earlier version returned the six axes
and the mapping joined all of them, plus `is_panel`, against the OMOP
vocabulary's own columns. That join fires only when all seven land exactly
right, and on a 30-group sample it matched 287 of 1,940 rows while agreeing
with the curated Finnish mapping on 11.3% of the overlap. Guessing one string
well is a far easier target than guessing seven labels that must *all* be
exactly right.

### Reading the evidence

The prompt carries an explicit hierarchy for combining `TEST_NAME`, `UNIT` and
`value_deciles`, because the obvious readings of this data are wrong:

- **A row is a `TEST_NAME` + `UNIT` pair, and that pair is what gets named.**
  Two rows of the same code with different units are two observations and may
  belong to two different LOINC concepts. Each is decided on its own.
- **The name is the source of truth.** `prefix_meaning` and `suffix_meaning`
  are *derived from the name string* by an upstream step, so a misspelled or
  locally-invented name yields a wrong prefix. They confirm what the name says;
  they never outrank it. The specimen is frequently a Finnish word rather than
  a prefix — `veri`, `seerumi`, `virtsa` — and
  `c-reaktiivinenproteiini,pikatesti,veri` names blood with no decoded prefix
  at all, its leading `c-` being the start of "C-reactive".
- **Missing values say nothing about the test.** `value_missing_p` is a fact about
  this extract, not about the laboratory test, so an empty `value_deciles` column is
  never grounds for a `[Presence]` (qualitative) name. Scale comes from the
  code — the `-O` suffix, the `LongName` — never from how much was recorded.
- **Nothing is borrowed between rows.** The group is a string-similarity
  cluster, so a neighbour's unit is not evidence about this row, and the same
  code may also sit in another group carrying units invisible here. A sibling
  row may help *read* a run-together name; it may never supply a unit, a
  quantity or an answer.
- **What a row may conclude is bounded by its `evidence_level`.** With a unit
  and values, the strongest case — and if they contradict each other the
  **unit** is the part to distrust, especially at a low `unit_share`. With a
  a unit but no values, trust the unit. With values but no unit, read the
  quantity off the magnitudes. With **neither**, the quantity cannot be fixed
  at all — but the search can still be aimed: the row is named from the
  analyte and specimen that can be read, taking the analyte's plainest
  ordinary property, or no brackets where there is no basis for one. Retrieval
  runs mostly on component and system, so such a name still returns the right
  family of concepts and lets the next step settle the quantity against real
  candidates.
- **Some units are ratios, not concentrations** — `mmol/mol` (HbA1c IFCC),
  `mg/mmol` (albumin/creatinine), `ml/min/173m2` (eGFR), and `%`, which may be
  a cell fraction, a mass fraction, or activity as a percentage of normal.
- **The specimen is often a Finnish word, not a prefix.** `prefix_meaning` is
  filled only for codes opening with a recognised prefix and a hyphen, so
  `c-reaktiivinenproteiini,pikatesti,veri` has none — yet `veri` says blood,
  and its leading `c-` is the start of "C-reactive", not a specimen.
- **A repeated lowest decile is a detection limit.** `[5, 5, 6.2, ...]` means
  the assay was censored at 5 and everything below reported as "<5"; that
  floor is the assay's sensitivity, not the population's low end.

### Naming

The prompt therefore spends its length on how LOINC actually writes names: the
`<Component> [<Property>] in <System> by <Method>` template, the property
display forms (`[Moles/volume]`, not OMOP's `Substance Concentration`), the
fact that a plain point-in-time sample is written nowhere and a 24-hour
collection folds into the system slot (`in 24 hour Urine`), that nominal and
fraction terms drop the brackets entirely (`Bacteria identified in Urine by
Culture`, `Lymphocytes/Leukocytes in Blood`), and that Method is omitted for
most chemistry. The head of `loinc_names_frequency.tsv` is appended as worked
examples, so the model sees the exact current spelling of the concepts this
data really contains.

Each call is that system prompt plus the group's rows as a markdown table. The
group is the unit of work because the clustering puts near-identical codes
together: sibling rows disambiguate a truncated or misspelled code, and show
whether two similar codes are genuinely the same test or deliberately differ
(specimen, fasting state, unit).

The model returns **only the two new fields per row**, keyed by a `row_id` the
script assigns before prompting — not the whole table back. This keeps the
payload small, makes it impossible for the model to silently alter source
values (`n`, `value_deciles`, ...), and gives an unambiguous integer join key;
`TEST_NAME` alone would not work, since the same code recurs within a group
with different `UNIT`s. The join is guarded: `row_id`s that were never sent, or
returned twice, are dropped with a warning, and rows the model skipped keep an
empty name rather than silently shifting the table.

Each call also returns a short reflection on that group, collected into
`reflections.md`.

`scripts/summariseLoincNamesStats.R` then reports on the result: coverage and
name-shape statistics computed locally from the table, plus one further LLM
call — over the concatenated reflections, not per group — that distils them
into the report's **Findings** section. That call degrades gracefully: if it
fails, the statistics are still written and the Findings section says so.

## Choosing the model

The step runs the same prompts through either of two backends, selected with
`--llm`:

- **`--llm ellmer`** (default) — [ellmer](https://ellmer.tidyverse.org) talking
  to an HTTP provider, `LLM_PROVIDER` deciding which (default `google_vertex`,
  i.e. Gemini on Vertex AI). This is what `DATA/` was produced with.
- **`--llm claude`** — the `claude` command-line tool (Claude Code), wrapped by
  `scripts/R/claudeClient.R` to look like an ellmer client. This is what
  `DATA_sonnet/` and `DATA_opus/` were produced with.

`--model <MODEL>` sets the model on whichever backend is selected, so its
spelling is the backend's own: `gemini-2.5-pro` or `gemini-2.5-flash` for
ellmer/Vertex; `sonnet`, `opus`, or a full name like `claude-opus-5` for
claude. Left out, each backend uses its own default — `gemini-2.5-pro` for
ellmer, `sonnet` for claude.

Nothing else changes between the two: the same `systemPrompt.md`, the same
group tables, the same output schema, the same per-group cache. That is the
point — it makes a model comparison a matter of running the step twice into two
data folders.

The `claude` CLI is an agent, not a bare model endpoint, so the wrapper strips
it back to a single model turn: `--tools ""` (no tool use — this is a data task,
and a run that could read files would not be reproducible), `--system-prompt`
(**replaces** Claude Code's own agent system prompt with this step's, so the
model is given the same instructions ellmer gives it and nothing else),
`--safe-mode` (ignores `CLAUDE.md`, skills, plugins, hooks and MCP servers, so
the answer does not depend on the checkout's agent configuration), and
`--no-session-persistence`. Structured output comes from `--json-schema`, fed
the very same `ellmer::type_object()` declaration the ellmer path uses —
`ellmerTypeToJsonSchema()` translates it, so there is no second copy of the
schema to drift.

Because each step's answer cache is keyed on `group_id` alone and lives inside
the data folder, **run a different model into a different data folder**
(`DATA_sonnet`, `DATA_opus`) rather than into `DATA` with `--clean`. That keeps
every run on disk and comparable.

## Env vars

- `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION`, `GOOGLE_APPLICATION_CREDENTIALS` —
  the Vertex AI project, region and service-account key, from the
  `ENVIRONMENTS/<ENV_NAME>.env` file selected by `--env`. Required by the
  ellmer/Vertex backend only; a `--llm claude` run needs none of them, and
  `run.sh` checks for the `claude` CLI instead.
- `LLM_PROVIDER` — backend, default `google_vertex`. `--llm claude` sets it to
  `claude_code`.
- `LLM_MODEL` — model; `--model` sets it. Default `gemini-2.5-pro` on ellmer,
  `sonnet` on claude.
- `LLM_PARALLEL_WORKERS` — number of parallel workers; defaults to
  `detectCores() - 2` on ellmer and to `4` on claude, where one worker is a
  whole CLI process rather than an HTTP call.
- `CLAUDE_TIMEOUT_SECONDS` — how long to wait for one `claude` call before
  giving up on it, default `900`. Claude backend only.

## How to run

```
./STEPS/FindLOINCDimensions/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME> \
    [--llm <ellmer|claude>] [--model <MODEL>] [--ngroups <N>] [--seed <N>] [--clean]
```

`--llm` and `--model` pick the backend and the model — see
[Choosing the model](#choosing-the-model). Both are applied after the `--env`
file is sourced, so a flag always beats the environment file.

`--ngroups <N>` processes a **random sample** of `N` groups — used during
development to keep runs small and cheap. Omit it to process all groups. The
sample is random rather than the first `N` because groups come out of the
clustering in dendrogram order, so the first `N` are all neighbours in the tree
and cover only one corner of the data (the first 50 were all microbiology).

`--seed <N>` seeds that sample (default `1`), so a given `--seed`/`--ngroups`
pair always selects the same groups.

`--clean` deletes the per-group answer cache before running, forcing every
selected group to be asked again. **Use it after editing `systemPrompt.md` or
the output schema**: the cache is keyed on `group_id` alone, so without it a
re-run silently returns answers produced by the old prompt. It costs a full
re-run, so it is off by default.

```
./STEPS/FindLOINCDimensions/run.sh DATA --env build --ngroups 30 --clean
./STEPS/FindLOINCDimensions/run.sh DATA_sonnet --env build --llm claude --model sonnet --ngroups 30 --seed 1
./STEPS/FindLOINCDimensions/run.sh DATA_opus   --env build --llm claude --model opus   --ngroups 30 --seed 1
```
