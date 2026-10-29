# Group 7

This group was consistently about tissue transglutaminase antibodies, a marker for celiac disease. The main variations were IgA vs. IgG, and whether the specimen (Serum) was specified via the `S-` prefix or the word `seerumista`.

The most significant ambiguity was in rows 383-384 (`s-transglutaminaasivasta-aineet`), where the immunoglobulin class was not specified. I inferred this to mean IgA, as it's the primary screening test. This is a strong clinical assumption but an assumption nonetheless. A less specific component like `Tissue transglutaminase Ab` might be an alternative, but LOINC is usually specific about the immunoglobulin class.

Data quality issues included many rows without units or values, which required guessing the property based on sibling rows. The `u/ml` unit consistently pointed to a `[Units/volume]` property, making this a safe guess. Variations in spelling (`iga-vasta-aineet` vs. `igavasta-aineet`) and the inclusion of contextual hints like `(keliakia)` were common but did not change the core interpretation of the test.

# Group 14

This group was entirely focused on C-reactive protein (CRP) but presented several interesting challenges. The most significant was distinguishing between standard CRP and high-sensitivity CRP (hs-CRP). While some names included the Finnish word for 'sensitive' (`herkkä`), several did not but had value deciles clearly in the hs-CRP range (first decile < 1.0 mg/L). Following the instruction to 'work out what the test actually measures', I used these value distributions as strong evidence to assign the `C reactive protein.high sensitivity` component even when the local name was ambiguous (e.g., rows 1034, 1040). This should provide a much better search query than sticking to the literal name alone.

Another gotcha was the contradiction between local names and the data. Rows with `(kval)` or `osoitus` (detection) suggested a qualitative test, but the `mg/l` unit and quantitative deciles proved otherwise. I consistently prioritized the quantitative data over these likely erroneous name qualifiers.

Finally, the data contained many synonyms for point-of-care testing (`pika`, `vieritesti`, `hoitoyksikössä`, `tehdään itse`). Since LOINC often handles this via Method (which is best omitted from a general query) or by having specific 'Point of care' terms, I chose to generate the base `C reactive protein` name for all of them. This creates a robust query that will retrieve the parent concept and its POC children, allowing the next step to select the best fit.

# Group 20

This group was dominated by two categories: microbiology nucleic acid tests and ECGs. For the microbiology tests, the abbreviation `nukl. hapon os.` or `-nho` was a clear indicator for a nucleic acid test, which I mapped to `DNA [Presence] ... by NAA`. The specimen prefixes `F-` (Feces) and `Li-` (CSF) were very helpful. For codes lacking a specimen prefix, I defaulted to Stool, as it's the most common sample for enteric pathogens. The identical `n` counts for many of the `F-` prefixed tests (e.g., 607) strongly suggest they are components of a single multiplex panel, but per instructions, I've mapped them as individual tests.

The ECG codes were repetitive, with many variations containing administrative metadata (location, performer) in parentheses or appended. I mapped all standard `ekg, 12 kytkentää levossa` (12-lead ECG at rest) variants to `12 lead EKG panel`. A subset explicitly mentioned computer analysis (`sisältäen tietokoneanalyysin`), for which `12 lead EKG with interpretation panel` is a better fit. A specific screening test for atrial fibrillation using a monitor (`eteisvärinän seulonta, valvontamonitori-ekg`) was mapped to a more specific `Atrial fibrillation` concept.

# Group 21

This group primarily contained tests for transferrin saturation and soluble transferrin receptor, which were generally clear to identify. A key point of ambiguity was how to handle transferrin saturation results reported as percentages (e.g., 25%) versus those reported as fractions (e.g., 0.25). I concluded that both should map to a LOINC concept with the property `[Molar ratio]`, as this property covers the underlying quantity, and the difference is merely in the display unit. LOINC generally does not create separate concepts for such presentational variations.

A specific challenge was row 1308, where the unit was `paketti` (package). Since transferrin saturation is a calculated value, this unit strongly suggests an orderable panel that includes the primary measurements (iron and either transferrin or TIBC). I proposed the name for a standard LOINC panel, `Iron and iron binding capacity and transferrin saturation panel - Serum`, which is a plausible match for what a 'package' for transferrin saturation would contain.

The prefixes (`p-`, `s-`, `fp-`, `fs-`) and explicit text (`seerumista`) were useful for determining the system (`Plasma`, `Serum`), and `Serum or Plasma` was used as a default where no system was specified. The fasting status indicated by `f-` prefixes or `paastotilassa` text was correctly treated as a pre-analytical condition and not included in the LOINC name.

# Group 33

This group contained a mixture of microbiology cultures, drug screening panels, a complex genetic test, and cardiology procedures. The grouping by string similarity was essential for interpreting the many truncated names for MRSA cultures (e.g., `viljelyne` for 'viljely nenästä'). The Finnish names for the MRSA cultures were very clear about the sample site (nose, throat, perineum), which mapped directly to the LOINC System.

The drug screen panels were identifiable by the keywords `huumeseula` or `huumeseulonta` and the lists of drugs. I opted for a generic panel name like `Drugs of abuse 6 screen panel` which is a more robust search query than trying to construct a very long component listing all drugs. The `U-` prefix clearly indicated urine, and I inferred urine for the others as it's the standard for such screens.

The genetic test name (row 1786) was exceptionally long and descriptive. A direct translation isn't feasible; instead, I had to abstract the core meaning ('study of base changes and small copy number variations... by NGS') into a plausible LOINC-style panel name to aim the search, `Genetic variants and Copy number variations panel - Blood or Tissue by NGS`.

The EKG tests (`pitkäaikaisrekisteröinti`) were clearly Holter monitor studies, and the duration (24h/48h) was explicit, allowing for specific panel names.

# Group 34

This group covered Streptococcus tests, mainly for S. pyogenes (Group A) and S. agalactiae (Group B). The Finnish names were quite specific about the method, allowing for a clear distinction between culture (`viljely`), antigen (`antigeeni`), and nucleic acid (`nukleiinihaponosoitus`) tests, which map well to LOINC methods like `Organism specific culture`, `Immunoassay`, and `NAA with probe detection`.

A recurring challenge was the absence of a specified specimen in many `TEST_NAME` strings (e.g., rows 1816-1820). To generate a useful search query, I had to infer the most common specimen based on the analyte: `Throat` for S. pyogenes and beta-hemolytic strep, and `Vagina` for S. agalactiae (GBS) screening. This is a necessary guess, as a query without a system is often too broad. The `ps-` prefix (Pharyngeal secretion) and `nielusta` (from throat) were very helpful confirmations when present. Similarly, `fl-` (Vaginal discharge) for GBS was a key piece of evidence.

# Group 37

This group was diverse, covering everything from billing codes to advanced molecular diagnostics and point-of-care testing. The main challenges were:

1.  **Administrative/Procedural Codes**: Many codes (e.g., `1868`, `1869`, `1961`) were clearly for billing or administrative purposes ("additional fee", "additional request", "0 fee sample collection"). These are unmappable to clinical LOINC terms and were correctly left blank.
2.  **Point-of-Care (POCT) Tests**: Numerous codes included "vieritesti" (POCT), "pikatesti" (rapid test), or "hoitoyksikön" (ward test). For most chemistry analytes (e.g., glucose, creatinine, electrolytes, CRP), LOINC does not distinguish POCT from central lab testing in the Long Common Name unless a specific method like `Test strip` is implied. I've generally mapped these to the standard lab term, which is correct LOINC practice. The `INR` test (`1922`) was an exception where `in Capillary blood` is often used for POCT.
3.  **Ambiguous Systems**: For microbiology screens (MRSA, MDR GNR) and some molecular tests (HPV), the specimen type was not specified in the local code. I defaulted to a generic `in Specimen` or the most common system (e.g., `in Cervix` for HPV) to provide a useful search query.
4.  **Panel Identification**: Several codes clearly indicated panels: `happoemästasejahappi` (acid-base and oxygen) became a blood gas panel, `täydellinenverenkuva` became a CBC w/ diff panel, and various urine dipstick codes were mapped to the `Urinalysis macro (dipstick) panel`. The combined respiratory virus test (`1938`) was also straightforward to map to a multiplex panel.
5.  **Confusing Prefixes**: The prefix `T-` was used for T-cell subsets (`1953`, `1954`), which is confusing as `T` usually means Thrombocytes. The long name was essential to resolve this.

# Group 42

This group demonstrated the high variability of local codes, especially in system prefixes and panel naming conventions. Non-standard prefixes like `ap-` (Arterial plasma?), `cp-` (Capillary plasma?), and `vp-` (Venous plasma?) required educated guesses based on the analyte and clinical context. The frequent use of different separators (`+`, `,`, `-`, `/`) in panel names like `p-k-na` highlights the challenge of robustly identifying panels.

Several codes were highly ambiguous, necessitating speculative guesses. For instance, `p-laite` was interpreted as a typo for `P-Lamot` (Lamotrigine), and `pneag` as `Pneumococcal antigen`. The `happi` (oxygen) codes, lacking a clear system, were particularly challenging to differentiate between saturation, flow rate, and inspired fraction.

A useful pattern observed was the use of `ed`/`jd` suffixes (e.g., `p-ked.`, `p-naed.`), which plausibly stand for 'ennen dialyysiä' (pre-dialysis) and 'jälkeen dialyysin' (post-dialysis), allowing for the creation of more specific pre/post challenge test names. The code `pt-ivfal`, however, seemed purely administrative, naming a procedure (IVF initiation) rather than a measurement, and was consequently left blank as per the guidelines.

# Group 43

This group was relatively straightforward, with many common chemistry analytes. The main challenge was the systematic misinterpretation of the abbreviation `Cl` for Chloride as the suffix for 'Clearance' by the upstream suffix decoder. This was easy to spot and ignore, as the component name and typical units/values for Chloride were clear. 

Another ambiguity was the handling of non-standard prefixes like `ap-` (Arterial plasma), `vp-` (Venous plasma), and `mb-` (Mixed blood?). I chose to use the specific system when confident (e.g., `Arterial plasma`) but defaulted to a more general system like `Blood` or `Serum or Plasma` when the prefix was less certain or when LOINC typically doesn't make that distinction. For example, I used `Venous plasma` for `vp-` but just `Blood` for `mb-`.

The code `ts-cc` (row 2559) was impossible to decipher. 'Ts' is tissue, but 'cc' is too ambiguous without any other context, so I correctly left it empty. The `form` unit for some urine tests (e.g., 2662, 2669) was interpreted as a signal for a qualitative test, leading to a `[Presence]` property, which is a reasonable heuristic in the absence of other information.

# Group 44

This group contained many standard abbreviations that were straightforward to map with the help of the `LongName` (e.g., `ACE`, `AFP`, `HCG`, `SHBG`). The main challenges were:

1.  **Ambiguous Abbreviations**: Codes like `p-hae`, `p-hepg`, `p-hok`, and `s-kem` were difficult. I made educated guesses for the first three (Hereditary angioedema panel, Heparin, Homocysteine) but had to leave `s-kem` empty due to its generic nature. More context or a clearer long name would be needed for these.
2.  **Multiple Properties for One Analyte**: Tests like `s-afp` and `s-tati` appeared with different units (`U/ml` vs `ug/l`, `nmol/l` vs `ug/l`), correctly leading to different LOINC names with `[Units/volume]`, `[Mass/volume]`, and `[Moles/volume]` properties. This highlights the importance of not assuming a single LOINC concept per local code.
3.  **Qualitative vs. Quantitative**: For antibody tests (`s-ana`, `s-ema`) and the urine HCG test (`u-hcg`), the absence of a unit strongly suggests a qualitative (`[Presence]`) or titer test. The presence of a `titre` unit on a sibling row confirms this pattern. Making this distinction is crucial for accurate mapping.
4.  **Local Modifiers**: The `/d` in `s-afp/d` is an uninterpretable local modifier. The safest approach was to map it to the base analyte (AFP), as the modifier's meaning is lost.
5.  **Specialized Tests**: Platelet function tests like `b-adp`, `b-aspi`, and `b-vasp` required specific knowledge. `b-vasp` in `%` maps well to the Platelet Reactivity Index `[Ratio]`. For `b-adp` and `b-aspi`, recognizing the platelet aggregation inducers and the `auc` unit was key.

# Group 51

This group was dominated by qualitative nucleic acid tests, identifiable by the `-nho` suffix and confirmed by several `LongName` entries containing `nukleiinihappo (kval)`. This allowed for a consistent mapping strategy using the `[Presence]` property and `by NAA with probe detection` method.

The main challenges were interpreting abbreviations where a `LongName` was missing:
1.  **Inferring components from related codes:** `bopanho` was inferred to be *Bordetella parapertussis* based on the nearby `bopenho` for *B. pertussis*. Similarly, `boppnho` was interpreted as a combined test for both.
2.  **Decoding prefixes:** Prefixes like `r-` (`-rbaktnho`) and `res-` (`resbaktnho`) were interpreted as `Respiratory specimen`, and `b-` (`-bparnho`, `bparanho`) as `Blood`. This was an educated guess based on common lab practice and comparison with codes that had explicit system prefixes like `f-` (Feces) and `li-` (CSF).
3.  **Ambiguity:** For the majority of codes without a system prefix (e.g., `-aspenho`, `kv229enho`), the generic `Specimen` system was used. While this creates a useful search query, it's a significant ambiguity.

Data quality issues included leading hyphens (`-baktnho`) and trailing punctuation (`-bopenho.`), which appear to be artifacts. The `kv...nho` codes were very specific about the coronavirus strain but gave no clue about the specimen type.

# Group 68

This group was divided into two distinct sets of tests. The first set, prefixed with `Ps-Str...`, dealt with Streptococcus detection in throat swabs. The challenge here was the high number of garbled or locally suffixed codes (`ps-str1vrk`, `ps-straag␤`, `ps-stragho`). The strategy was to identify the core test (e.g., Strep A antigen) and apply it to the variants. The `LongName` on a few key codes (`ps-strvi`, `ps-straag`, `ps-stranho`) was crucial for interpreting the entire family, including the distinction between general Streptococcus culture and specific Strep A tests.

The second set, `S-Stpn...`, was a systematic list of pneumococcal serotype antibody tests. The main difficulty was the presence of multiple, different units for the same analyte (e.g., `mg/l`, `ug/mlgmc`, `fmiau/ml`). This required creating different name guesses with `[Mass/volume]` and `[Units/volume]` properties. The `ug/mlgmc` unit was interpreted as a standard mass concentration (`ug/ml`), and I made an educated guess that these were all IgG antibody tests, which is typical for post-vaccination serology. Preserving the serotype as written in the code (e.g., `20A`) was a deliberate choice to ensure the search query is faithful to the source data, even if the serotype nomenclature is ambiguous.

# Group 70

This group contained several interesting patterns. The `talt` or `talteen` codes (e.g., `b-talt.kn`, `s-talteen`) are clearly administrative codes for sample storage and not actual tests; it was correct to leave them blank. The `i-stat` codes were straightforward to interpret as results from the i-STAT point-of-care device, with the system consistently being `Blood`.

The testosterone tests (`s-testo...`) showed significant local variation in naming (`-v`, `-vl`, `-vlik`, `ov`, `ovi`, `ovl`) to distinguish total, free, and calculated free testosterone, as well as methods like mass spectrometry (`ms`) and high sensitivity (`hs`). Correctly parsing these local conventions was key. For example, `lik` and `vl` were consistently associated with calculated results.

A key ambiguity was the `lateksi` code. While it can refer to the latex agglutination test for Rheumatoid Factor, the presence of `s-latekse` with a `LongName` for Latex IgE antibodies in the same group strongly suggests that all `lateksi` codes in this context are for allergy testing. I opted for this interpretation. Similarly, some abbreviations like `s-statrae` and `s-pisto1`/`s-pisto2` were not fully decipherable, requiring more generic guesses (e.g., 'Allergen specific IgE Ab' or 'Insect venom IgE Ab panel').

# Group 73

This group contained a mixture of clearly defined chemical analytes, serological tests, panel tests, and ambiguous or administrative codes.

* **Strengths in the data**: The `LongName` column was invaluable for confirming analytes like the various forms of Vitamin D, Creatine vs. Creatinine, and Cystatin C. The presence of a whole family of related tests (e.g., Vitamin D total, D2, D3, 1,25-OH) increased confidence in the interpretation of each individual code.

* **Challenges**: 
    1.  **Ambiguous abbreviations**: Codes like `s-kipa` or `s-ctdscr` are difficult. For `s-ctdscr`, I made an educated guess ("Connective Tissue Disease Screen") based on the letters, but `s-kipa` was too vague to guess, despite its high frequency. 
    2.  **Administrative codes**: Many codes (`-kskäynt`, `-selvtyö`, `sjukhus`, `s-käsmak`) clearly referred to administrative concepts (visits, reports, fees) rather than clinical measurements and were unmappable.
    3.  **Fragmented codes**: Several codes starting with a hyphen (`-kskäynt`, `-s.yht.`) appear to be fragments of longer codes, making them impossible to interpret on their own.
    4.  **Serology knowledge**: Deciphering the Widal test codes (`s-w-h:a`, `s-w-o9.12`, etc.) required specific knowledge of Salmonella serotyping. The pattern was consistent, but not immediately obvious without that domain expertise.

* **Suggestions**: Providing context for highly frequent but ambiguous codes like `s-kipa` would be very helpful. For instance, knowing which hospital department orders it most often could provide a strong clue (e.g., endocrinology -> thyroid). Similarly, if fragmented codes could be linked back to a more complete original string, their mappability would increase dramatically.

# Group 74

This group demonstrated significant variation in local abbreviations for the same analyte. For example, Adalimumab appeared as `s-adali`, `s-adalimu`, `s-adalip`, and `s-adalipa`. Similarly, alkaline phosphatase isoenzymes were represented by a variety of codes (`s-afluu`, `s-afluust`, `s-afosluu`, `s-afsuoli`) that required interpreting Finnish words (`luu` for bone, `suoli` for intestine) to differentiate them.

Several `Aldosterone` tests (`s-oaldos`, `s-valdos`) had extremely high values, orders of magnitude above the physiological range. While I named them as Aldosterone, these are likely data errors, tests on non-human samples, or measurements of a different substance entirely (e.g., a metabolite or a drug that cross-reacts). It's a reminder that values, while helpful, can be misleading.

Some codes were too generic or garbled to interpret, such as `s-kudosab` (tissue antibody), `s-ngmuut` (??-other), and `sp-suld`. For these, I correctly returned an empty name. The administrative code `saline` also fell into this category.

Finally, for tests ordering multiple components like isoenzymes (`s-afos-is`, `s-amyl-is`), I chose to create a `panel` name, which is a better fit than guessing which single isoenzyme was reported.

# Group 79

This large group was almost entirely about glucose (`gluk`), with one glucagon (`glkg`) test. The main challenges were interpreting the numerous local suffixes and prefixes and handling inconsistencies between test codes, units, and values.

**Prefixes and Suffixes**: The standard prefixes (`B-`, `P-`, `fP-`, `cB-`, `U-`, `Pt-`) were clear, but many local variants like `cp-`, `cfp-`, and `vp-` required interpretation. I assumed they all referred to plasma, which I mapped to the standard LOINC `Serum or Plasma` system. The `Pt-` (Patient) prefix was particularly interesting. When combined with `-r` (challenge) and a descriptive `LongName`, it clearly indicated a glucose tolerance test (GTT) panel. However, many `Pt-` codes were for individual timed results (e.g., `Pt-Gluk-2h`). I interpreted these as individual results belonging to a GTT, where the lab chose to use the `Pt-` prefix, rather than as separate panel orders.

**Inconsistencies**: 
- Several `-O` (qualitative) tests had quantitative values (e.g., `b-gluk-o`, `p-gluk-o`). I prioritized the `-O` suffix, a strong signal from the national coding system, and named them as `[Presence]` tests. This assumes the values are either from semi-quantitative scales or are data errors.
- Row 6106 (`fp-gluk-2h`) had the unit `mmol/mol`, which is standard for HbA1c, not a timed glucose test. I ignored this clearly erroneous unit and based the name on the test code.
- Row 6216 (`u-gluk-de`) had high numeric values without a unit. The magnitude strongly suggested `mg/day`, which would imply a 24-hour urine collection. I made an educated guess of `Glucose [Mass/time] in 24 hour Urine`, despite the code not explicitly indicating a 24h collection. This is a risk, but it provides a much more specific search query.

**Panel vs. Individual Test**: Differentiating between orderable panels and individual results within those panels was key. The `Pt-...-R...` codes, especially with confirmatory `LongName`s like `Pt-Glukoosi-koe, oraalinen...`, were mapped to panel names (e.g., `Glucose oral tolerance test panel`). The numerous timed results (`...-1h`, `...-2h`, etc.) were mapped as individual challenge results with the appropriate timing in the LOINC name.

# Group 84

This group was dominated by `Pt-` (Patient) codes, which are challenging because they rarely map to a simple analyte-in-specimen test. They represent a wide variety of concepts: functional/challenge tests (`pt-acth-r1`, `pt-lakt-r1`), imaging procedures (`pt-fdg-pet`), calculated scores (`pt-fib-4`), physical measurements (`pt-paino`), administrative actions (`pt-erist`, `pt-meeting`), and other procedures (`pt-aktig`).

The presence of a `LongName` was crucial for interpreting these `Pt-` codes (e.g., `Pt-Deksametasoni-koe, lyhyt` for `pt-dxm-r1`). Without it, many codes would have been unmappable. For some `Pt-` codes, it was important to distinguish between the panel code for ordering the entire test (e.g., `pt-dxm-r1` with no unit/values) and the code for a specific result within that test (e.g., `pt-dxm-r1` with `nmol/l` for the post-dexamethasone cortisol level).

A significant portion of the `Pt-` codes were too generic or ambiguous to confidently map (e.g., `pt-abiras`, `pt-miesl`, `pt-selvit`). These appear to be local administrative codes where the abbreviation doesn't carry enough clinical meaning. For future work, having access to a dictionary of these local or proprietary codes (like 'Hertta' for the cardiovascular risk score) would be immensely helpful.

# Group 85

This group was dominated by whole-patient (`Pt-`) investigations, including imaging, physiological tests, and questionnaires, rather than traditional laboratory tests. This required knowledge of Finnish abbreviations for procedures like bone densitometry (`luutih`), stress echo (`rasukg`), and bone scintigraphy (`luustog`). Several codes (`pt-lisälau`, `patlislaus`) were clearly administrative placeholders for "additional reports" and were left empty as they do not represent a specific clinical test.

Several gotchas were present:
1.  **Ambiguity**: `p-pbmcbio` was too ambiguous to guess, combining Plasma, PBMC, and an unclear suffix `bio`.
2.  **Genericity**: `ps-nieluag` clearly means "throat antigen test", but without a specified antigen. I named it generically (`Antigen [Presence] in Throat`) to provide a useful search query.
3.  **Typos**: `pt-luutil` was interpreted as a likely typo for `pt-luutih` (bone density), as `luutil` has no obvious medical meaning while being graphically similar to a common abbreviation.
4.  **Specialized knowledge**: Distinguishing `puheaudio` (speech audiometry) from `äänesaudio` (guessed as pure tone audiometry) requires specific audiology domain knowledge.

# Group 87

This group was overwhelmingly composed of histopathology tests, identifiable by the `Ts-PAD` structure. `PAD` (Patologian Anatomian Diagnoosi) consistently means histopathology. The key challenge was to differentiate the generic tests from those with specific sites or methods.

The strategy was to use `Microscopic observation [Identifier] in Tissue by Light microscopy` as the default for any `Ts-PAD` code, and then specialize it based on suffixes:
- Site-specific suffixes (`gast`, `colo`, `brea`, `pros`, etc.) were used to refine the `<System>` from `Tissue` to e.g., `Stomach tissue`.
- Method-specific suffixes (`-ih`, `-if`, `-em`, `-ish`, `-fish`) were used to refine the `<Method>`, e.g., `by Immunohistochemistry`.
- Specific test types like `pika` (frozen section) and `makr` (gross observation) were mapped to their corresponding LOINC concepts.

The numbered suffixes (`-1`, `-2`, `-3`, etc.) and their `LongName`s clearly indicate they are billing or sample complexity/size modifiers (e.g., '1-3 small samples', 'large specimen'). These do not change the underlying nature of the test, so they were correctly mapped to the same general LOINC concept.

A few codes like `ts-pad-1co` and `ts-pad-3co` were ambiguous. 'co' could mean 'colonoscopy', but since the base code `ts-pad-1` is generic, I specialized the system to `Colon tissue` with some confidence that this is the most likely meaning in context. Similarly for `ts-padgyn` I chose `Female genital tract tissue` as a reasonable guess for a gynecological sample.

The `pt-papa-1` code was unique, being `Pt-` (patient) based. Recognizing `papa` as Papanicolaou test was crucial. I mapped it to the cytology result concept, treating `Pt-` as an indication of the overall procedure but mapping the specific lab result component.

# Group 89

This group predominantly featured ionized calcium tests, with a high degree of string variation for the same underlying concept. The main challenges were:

1.  **Non-standard prefixes**: Codes like `ap-`, `cp-`, `mb-`, and `vp-` are not part of the standard Finnish set. I interpreted them as Arterial Plasma, Capillary Plasma, Mixed Blood, and Venous Plasma, respectively. This is a reasonable guess but remains an assumption.
2.  **pH Adjustment**: The frequent appearance of `7.4` or `pH7.4` was a crucial clue that these were not just ionized calcium, but results adjusted to a standard pH. LOINC has specific concepts for this, so correctly identifying this feature (`...adjusted to pH 7.4`) is important for accurate mapping.
3.  **Component Synonyms**: `Ca++`, `Ca-i`, and `Ca-ion` were all interpreted as `Calcium.ionized`.
4.  **Hidden Component**: One code, `fs-ph(ca-ion)` (row 6727), was actually a pH measurement performed in serum, identifiable from the `ph` in the name and the value range `7.3-7.4`. This highlights the importance of not just looking at the main analyte (`Ca`) but the entire string and the values.
5.  **Data Noise**: Incorrect units (`nmol/l` for values around 1.2, `unit_share`=0%, row 6747) and meaningless suffixes (`a`, `ac`, `vt`, `.`, `:`) were common and had to be filtered out.

# Group 105

This group was dominated by coagulation tests, mostly from plasma, which were generally well-defined by their long names. The primary challenge was interpreting local or ambiguous abbreviations. For instance, `p-apot` was too vague to identify an analyte. Similarly, `p-sit3.1` and `p-sitr3.8` were left empty as they likely refer to the collection tube's citrate concentration rather than the measured analyte, making the actual test unknowable.

Suffixes like `-hoi` (likely point-of-care), `-ses`, and `-paiv` (emergency) were interpreted as context not usually encoded in the main LOINC name and were therefore omitted in favor of the plain test name. This seems like the correct strategy to avoid over-specifying the search query.

The codes for lupus anticoagulant testing (`p-la...` series and possibly the `p-fs...` series) were a good example of educated guessing. While `p-la1/la2` clearly pointed to a screen/confirm ratio, the underlying test (dRVVT, aPTT-based, etc.) was not specified. I chose `dRVVT` as it is a common method, but this is an assumption. Better documentation on what these local codes represent would be invaluable.

# Group 106

This group contained a large number of coagulation tests, particularly for Lupus Anticoagulant (`P-LA...`, `P-LuAk...`). Distinguishing between screening tests and confirmation tests, and between the ratio (`[Ratio]`) and qualitative (`[Presence]`) results, was key. The `LongName` and units like `ratio` and `form` were crucial clues. The presence of both aPTT-based and dRVVT-based tests was clear from the abbreviations.

There were several ambiguous or non-standard codes. `veka` appeared in multiple codes (`mb-k-veka`, `p-gluveka`, etc.) but its meaning was unclear; I proceeded by ignoring it and focusing on the core analyte and system. The `S-pH(akt)` code was a clear data quality issue; pH is measured in whole blood, not serum, so I mapped it to blood despite the 'S-' prefix. The `Haglund` and `projekti` codes were unmappable research or administrative labels and were correctly left blank.

The highly abbreviated codes like `hpvpapctgc` and `u-omactgc` required educated guesses based on common test combinations (HPV/Pap, Chlamydia/Gonorrhea). The context from other rows (`u-omactgc` clarifying `-omactgc`) was helpful.

# Group 110

This group was dominated by microbiology tests, primarily cultures (`-vi`) and stains (`-vr`). The naming convention was quite consistent, making it possible to decode most abbreviations, especially when `LongName` was available. The leading dash on many codes (`-activi`, `-amebvr`) indicates these might be suffixes or parts of a larger order code that was truncated at the source, but the content was specific enough to map.

A key challenge was interpreting codes that combine methods, like `tbvivr` (culture and stain). LOINC typically has separate codes for smear and culture. I mapped these to a panel concept (`Mycobacterium tuberculosis smear and culture panel`) as this reflects an order that yields two distinct results. This seems more accurate than picking just one method.

The code `l-sauv` and its variants for band neutrophils (`sauvatumaiset`) were an interesting case. The unit `%` and the values clearly pointed to a differential count ratio, which maps to `Neutrophils.band form/Leukocytes [# Ratio] in Blood`.

Several codes like `-em-bl`, `-ervr`, and `rasvat` were too ambiguous or generic to map confidently, as they lacked system information or a clear component, so I left them empty. The code `veri` (blood) is a specimen type, not a test, and was also correctly left empty.

# Group 111

This was a very diverse group containing many different types of tests: routine chemistry (CRP), tumor markers (CA series), cardiac markers (CK-MB), endocrinology (C-peptide, HCG), genetic tests (CYP series), and immunology (complement). 

The most frequent challenge was the conflict between the `-O` suffix (qualitative) and the presence of quantitative units (`mg/l`) and values. My strategy was to trust the unit and values over the suffix, as it's common for qualitative codes to be used for quantitative reporting. When quantitative evidence was absent, I respected the `-O` suffix and named a `[Presence]` test. This seems like a robust heuristic.

A data quality issue was evident in several rows where `value_missing_p` was 100% despite the `value_deciles` being populated. I chose to trust the deciles as they provide concrete information about the test's scale.

There were many local suffixes appended to standard codes (e.g., `-hy`, `-lb`, `-hoi`). I generally ignored these, mapping them to the base test, assuming they represent administrative context (like the ordering ward) rather than a different analytical method. For codes like `poc`, `vt` (vieritutkimus), I correctly identified them as Point-of-Care tests and added `by Point-of-care` to the name.

Identifying high-sensitivity CRP (hs-CRP) from regular CRP required looking at the value deciles. Row 9077 (`b-crp-v`) and 9129 (`p-crp-päi`) had low-end values consistent with hs-CRP, which is a different clinical test from the standard CRP that most other codes represented.

# Group 121

This group was dominated by urine tests. The main challenges were:

1.  **Albumin/Creatinine Ratios**: There were numerous variations in spelling (`u-albkre`, `u-albkrea`, `u-alb/kre`, etc.) and system prefixes (`nU-`, `U-`). All were consistently mapped to the single LOINC concept `Albumin/Creatinine [Mass Ratio] in Urine`, as the core measurement is the same.
2.  **Urine Drug Screens**: The `U-Huum-` codes were plentiful. I interpreted them as panels (`Drugs of abuse screen panel - Urine`). Suffixes like `-ct` (confirmation), `-ps` (basic screen), and Long Names helped distinguish screening from confirmation. Specific numbered panels like `u-huum-10` were interpreted as such. Some codes like `u-alvhu4a` were too garbled to interpret and were left empty.
3.  **Urine Microscopy**: The distinction between automated counts (unit `E6/l`) and manual microscopy (unit `u/field` for #/HPF) was crucial. This allowed me to add `by Automated count` or `by Light microscopy` to the method, creating more specific search queries. Components like `hyalie` (hyaline casts), `levyep` (squamous epithelial cells), `pienep` (small/renal tubular epithelial cells), and `väliepi` (transitional epithelial cells) were identifiable.
4.  **Ambiguous Suffixes/Prefixes**: `E-coli` was a strange case; interpreting `E-` as Erythrocytes is biologically unlikely for an *E. coli* test, but it's what the code says. The `-O` suffix for `u-ph-o` and `u-suhti-o` was also tricky; although it means qualitative/semi-quantitative, pH and specific gravity are inherently numeric, so I chose the quantitative property `[pH]` and the component `Specific gravity of Urine` which has no property.

Overall, using sibling rows to decode abbreviations and relying on Long Names and units where available was effective. Distinguishing between screening/confirmation and automated/manual methods added useful precision to the guesses.

# Group 126

This group was dominated by hemoglobin-related tests, especially HbA1c, and HLA typing. The main challenges were:

1.  **Conflicting Evidence**: Row 10506 (`b-hkr`) had a unit (`fl`) and values (`84-94`) that strongly indicated MCV (E-MCV), directly contradicting the test name for Hematocrit. I prioritized the quantitative evidence as it defined 'what was actually measured'. Conversely, for row 10461 (`b-hb-o`), the qualitative suffix `-O` conflicted with quantitative-looking values. I prioritized the explicit suffix from the national coding system, as it's a more deliberate part of the code's definition than a potentially erroneous value entry.
2.  **Unit Errors**: HbA1c had many incorrect units like `mmol`, `mmol/l`, and `mmol/m`. I interpreted these as data entry errors for the standard IFCC unit `mmol/mol`, as the value distributions were consistent with it.
3.  **Ambiguous Local Suffixes**: Numerous suffixes were not part of the standard Finnish set (e.g., `-hoi`, `-hy`, `-nla`, `-p`). I mapped these to the base test, assuming they are local administrative qualifiers without a separate LOINC equivalent. For point-of-care (`-vt`, `-poc`), I sometimes added `by Point-of-care`, though it's often safer to omit the method for search.
4.  **Complex Components**: The HLA typing tests were challenging due to the high specificity and numerous local, undefined codes (`b-hlamaks`, `b-hla1mun`). For these, a generic guess like `HLA typing [Identifier] in Blood` was the only option. The distinction between low- and high-resolution typing (`-dt` suffix) was an important detail to capture.
5.  **Component Representation**: Correctly representing fractions like HbA1c, Carboxyhemoglobin, and Methemoglobin as `Component/Hemoglobin.total` with properties like `[Ratio]` or `[Molar ratio]` was key. The data provided two distinct populations for HbA1c based on units (`%` vs. `mmol/mol`), corresponding to the NGSP and IFCC reporting standards, which require different LOINC properties.

# Group 129

This group was a mix of microbiology and chemistry. The microbiology codes (`-bakt-xx`) were challenging due to the variety of suffixes (`-he`, `-lm`, `-vi`, `-vr`, `-jvi`, etc.) which map to different LOINC properties and methods (Susceptibility, Identification, Culture, Stain, Subculture). Distinguishing between a screening culture (`[Presence]`), a quantitative culture (`[#/volume]`), and an identification culture (`identified`) required careful interpretation of the code, long name, and any available units.

The lactate (`laktaat`) codes were numerous but straightforward, differentiated primarily by the specimen prefix (aB-, vB-, P-, S-, Li-, etc.). Ambiguous prefixes like `ap-` and `mb-` required making an educated guess (Arterial plasma, Blood).

The fecal bacteria culture panels (`F-BaktVi1`, `F-BaktVi2`, `F-BaktVi3`) were interesting. The `LongName` was crucial for identifying the specific organisms included in each panel. For `F-BaktVi3`, which combines others, a generic `Enteric pathogens panel` name felt like a safer and more searchable query than listing all seven organisms.

Finally, the urine sediment analysis (`U-Sakka-xx`) codes were clear thanks to the combination of `sakka` (sediment) and the cell type (`epit`, `eryt`, `leuk`). The unit `u/field` was a strong clue for microscopy and the `[#/area]` property.

# Group 155

This group contained a mixture of well-defined lab tests, panels, and a significant number of administrative or billing codes. The administrative codes (e.g., `näytteenotto`, `talteen`, `konsultaatiopyyntö`, `maksu`) are unmappable and were correctly identified and left empty.

The main challenge was interpreting the breadth of panel codes. Terms like `perusterveyspaketti` (basic health package) were used as prefixes for individual results (ALT, Glucose, etc.). My approach was to map each row as the individual reported test, not the panel it belongs to, which is the correct way to handle such data. In contrast, codes like `b-täydellinenverenkuva` (complete blood count) or `rasvapaketti` (lipid package) represent the order for the panel itself and were mapped to LOINC panel concepts.

Synonyms and local variations were common, especially for RDW (`punasolujen kokojakauma`, `koonvaihtelu`) and urine specific gravity (`suhteellinen tiheys`). Consistency in mapping these to a single canonical LOINC name is key. Adding method `by Test strip` for specific gravity was possible when the name contained hints like `kval`, `stix`, or `vieritesti`.

Finally, some codes like `aikuistyypindiabetes,vuosikontrolli` (diabetes annual check-up) are very high-level concepts. Mapping them to a generic LOINC panel (e.g., `Diabetes mellitus follow-up panel`) is a reasonable guess to enable semantic search, even if a perfect match is unlikely.

# Group 156

This group was characterized by a large number of common chemistry tests, many of which were related to creatinine, thyroid function, and dialysis monitoring. The main challenges were:

1.  **Disambiguating analytes from calculations**: Row 12749 (`kreatiniini,plasmasta` with unit `ml/min/173m2`) was clearly an eGFR result, not a creatinine measurement. The unit was the definitive clue. This highlights the importance of always considering the unit alongside the test name.
2.  **Panel vs. Single Test**: Codes like `proteiini,fraktiot` (protein fractions) and `sieni,viljelyjanatiivi` (fungus, culture and native prep) strongly suggest a panel or a bundled test rather than a single analyte. I've named these as panels (e.g., `Protein electrophoresis panel - Serum`, `Fungus panel - Specimen`) which seems more appropriate than trying to force them into a single-analyte template.
3.  **Decoding Local/Implicit Information**: The dialysis-related tests (`ennendialyysiä`, `dialyysinjälkeen`) required translating the timing into LOINC's `--pre dialysis` and `--post dialysis` challenge syntax. Similarly, `yskös` (sputum), `limakalvo` (mucous membrane), and `äidinmaito` (breast milk) had to be identified as the specimen/system.
4.  **Interpreting Ambiguous Suffixes**: In row 12776, `proteiini,ty,seerumista` had a `Ty` suffix (typing) but the unit (`g/l`) and values strongly pointed to a Total Protein measurement. I prioritized the quantitative evidence over the ambiguous suffix, guessing `Protein.total [Mass/volume] in Serum`.

Overall, the strategy of using `Serum or Plasma` as a default for S- or P- prefixed general chemistry and being specific (`in Serum`, `in Plasma`) when the source name explicitly states it worked well. For cultures, specifying the method (`by Culture`) and property (`identified`) is key.

# Group 162

This group contained a good mix of routine chemistry, hematology, genetics, and cytology tests. The Finnish names were generally descriptive, making identification straightforward.

- **Genetics:** The pattern `...-geeni, dna-tutkimus` clearly identifies genetic tests. I guessed the most common mutation/target for well-known tests (F5, F2, LCT, JAK2) to create a more specific search query. For broader pharmacogenetic tests like `CYP2D6` and `DPYD`, a more generic `...mutations found [Identifier]` name is more appropriate. The LOINC system `Blood or Tissue` is a good default for these.

- **Cytology:** The term `irtosolututkimus` (loose cell study) consistently means cytology. For specific body sites (bronchial, pleural, urine), I used a pattern like `Cells [Type] in <System> by Cytology`. For gynecological cytology, which is a very common procedure, I opted for the more procedural LOINC name `Cytology study of Cervical or vaginal smear or scraping` as it better reflects the nature of a Pap smear.

- **Panels & Reflexes:** Several codes were clearly panels (`pakettitutkimus`, `paneeli`) or reflex tests (`refleksointitutkimus`). Correctly identifying and naming these as panels (e.g., `Pharmacogenetics panel`, `Thyrotropin.reflex to Free T4 panel`) is crucial. The `neuvola...` code (13173) was interpreted as a standard obstetric panel.

- **Vague codes:** One code, `mikrobiologianerikoistutkimuk` (13172), was too generic ('microbiology special study') to be mapped and was left empty. This is the correct approach for administrative or bucket codes that lack a specific analyte.

