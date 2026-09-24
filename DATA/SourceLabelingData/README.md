


source : https://yhteistyotilat.fi/wiki08/spaces/JULKUNI/pages/141431291/Laboratoriotutkimusnimikkeist%C3%B6

## How lab codes are encoded in Finland

Per `Laboratoriotutkimusnimikkeistö-2021-ohjeistus.pdf` (the national lab test
nomenclature guide maintained by Kuntaliitto's Kodistopalvelu):

- Each test has a 4-digit running `CodeId` (national codes start at 1001).
- Its `Abbreviation` is up to 10 characters, built as **`<prefix><ShortName>[-<suffix>]`**:
  - a 1-2 letter **prefix** naming the specimen/system the sample is from
    (e.g. `S` = serum, `B` = blood, `U` = urine, `Pt` = patient), see
    `code_prefixes.tsv`;
  - a mnemonic Finnish (occasionally international) abbreviation of the test's
    long name;
  - an optional **suffix**, attached directly or after a hyphen, qualifying
    the result type or method (e.g. `-O` = qualitative/semi-quantitative,
    `-Ab` = antibodies), see `code_suffixes.tsv`.
- Example: `S -Bil-O` = S (serum) - Bil (bilirubiini/bilirubin) - O
  (qualitative).

`code_prefixes.tsv` and `code_suffixes.tsv` list every prefix/suffix from the
guide's abbreviation tables, with columns `id` (the code, lowercased),
`code` (the code as printed in the guide, case-sensitive), `name` (English —
taken from the guide's own English gloss where given, otherwise translated
from the Finnish/Swedish), `name_fi` (Finnish). Note: prefixes `fB`
(paastoveri/fasting blood) and `Fb` (vierasesine tai implantti/foreign body)
both lowercase to the same `id` (`fb`) — a genuine collision in the source,
not a transcription error.

