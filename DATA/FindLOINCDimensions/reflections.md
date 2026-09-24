# Group 7

This group was relatively straightforward due to the clear common analyte, tissue transglutaminase antibodies (`kudostransglutaminaasi...vasta-aineet`), a marker for celiac disease. The main challenge was distinguishing between quantitative and qualitative tests. This was reliably achieved by checking for a `UNIT` (`u/ml`) and a low `p_missing` for quantitative tests, versus a missing `UNIT` and a `p_missing` of ~100% for qualitative tests (or test orders).

Several rows demonstrated common data quality issues: some test names contained the specimen type (`seerumista`) explicitly, which was helpful when a standard `S-` prefix was missing. Other names included contextual information like `(keliakia)` or suffixes like `osatutk.` (partial investigation) or `keliakiatutkimus` (celiac investigation). While these could ambiguously suggest a panel, in this context they appear to be single component tests where the name adds clinical context. I interpreted them as single tests, not panels.

Finally, the data included abbreviations (`iggva` for `igg-vasta-aineet`) and minor variations in spelling and spacing, but the grouping by string similarity made it easy to see they all referred to the same set of concepts: tissue transglutaminase IgA, IgG, or total antibodies.

# Group 14

This group covered the very common C-reactive protein (CRP) test and its many local variations. The main challenge was to correctly distinguish between standard CRP and high-sensitivity CRP (hs-CRP). The Finnish keyword `herkkä` (sensitive) was a strong clue, but the `deciles` were the definitive evidence. hs-CRP results have a median around 1-2 mg/L, while standard CRP for acute inflammation is typically >10 mg/L. 

A second point of ambiguity was the LOINC `System`. The codes used prefixes for Blood (`B-`), Serum (`S-`), Plasma (`P-`), and capillary plasma (`cp-`). While LOINC has terms for `... in Blood`, point-of-care tests using whole blood often report a plasma-equivalent result. Given this, and the fact that `Serum or Plasma` is the most common system for this analyte, I chose the broader `C reactive protein [Mass/volume] in Serum or Plasma` for all standard CRP tests. This maximizes the chance of finding the correct common concept.

Finally, many local codes contained contradictory information, such as the suffix `(kval)` on a test clearly reported with quantitative `mg/l` units and numeric deciles. In these cases, the quantitative evidence from `UNIT` and `deciles` was prioritized over potentially inaccurate local naming conventions.

# Group 20

This group was divided into two distinct categories: EKG procedures and microbiology nucleic acid amplification tests (NAATs). The `p_missing` of ~100% for all rows was a strong indicator that these are either qualitative tests or complex reports/panels, which they were.

The main challenge was inferring the specimen and method for rows without a formal prefix or suffix (e.g., rows 1265, 1271-1275, 1310). I used the context of the other, more complete codes in the group (like the `F-` prefixed stool tests) to infer that the system was likely `Stool`. For rows containing `nho` or `nukl.haponos`, I specified the method as `by NAA with probe detection`. For those without, I chose a more generic name omitting the method, as it could have been an antigen test or culture.

Decoding the EKG variations (`Pt-EKG...`) was straightforward: despite many different local textual qualifiers (`asiakkaan ottama`, `sisältäen tietokoneanalyysin`), they all map to the same core LOINC concept, `12 lead EKG panel`. The exception was the 'atrial fibrillation screening' (`eteisvärinän seulonta`), which is better described by `Rhythm EKG`.

The microbiology tests appeared to be components of multiplex panels (one for GI pathogens, one for meningitis/encephalitis pathogens). The similar `n` counts for rows 1276-1282 confirmed they were ordered together as a GI panel. My task was to map each component individually, not the panel itself.

# Group 21

This group was divided into two clear concepts: Transferrin Saturation and Soluble Transferrin Receptor. The Finnish names were mostly consistent, making identification straightforward.

A key decision point was handling the different representations for Transferrin Saturation. Some records used percent (`%`) while others (e.g., row 1326 with unit `osuus`) used a fraction (ratio between 0 and 1), evident from the deciles. I mapped all of these to a single LOINC concept, `Transferrin saturation [Molar ratio] in Serum or Plasma`, as the difference is in local display formatting, not the underlying clinical measurement. LOINC standardizes this as a molar ratio.

For the receptor tests, some names explicitly stated `liukoinen` (soluble), while others did not. As the common clinical test is for the soluble form, I inferred this for all `transferriinireseptori` tests. This was supported by the `mg/l` units and decile values. The final guess was `Transferrin receptor.soluble [Mass/volume] in Serum or Plasma`.

The fasting status indicated by `fP-`, `fS-`, and `paastotilassa` was noted, but I opted for the more general LOINC term without the `--fasting` suffix to provide a broader, more common mapping target. The fasting state is often handled as a separate observation attribute rather than being part of the core test name.

# Group 33

This group contained several different types of tests, making the string-similarity grouping less effective. The tests were primarily panels or qualitative microbiology cultures.

- **MRSA Cultures**: The names were quite clear, often including the method (`viljely`=culture) and the specimen site (`nenästä`=from nose, `nielusta`=from throat, `perineumista`=from perineum). Truncated site names (`ne`, `ni`, `pe`) were easily resolved by context. For non-site-specific MRSA cultures (e.g., row 1812), `Specimen` is a reasonable system choice. The term `seulontaviljely` (screening culture) strongly suggests a multi-site screen, making `Staphylococcus aureus.methicillin resistant screen panel by Culture` a good fit.
- **Drug Screens**: These were clearly identifiable as panels. The listed analytes helped determine the panel size (e.g., 5-drug vs 6-drug). Although the specimen wasn't always stated in the `TEST_NAME`, `Urine` is the standard for such screens and was confirmed by `U-` prefixes in some rows.
- **EKG Holter**: The `Pt-` prefix and descriptive names `pitkäaikaisrekisteröinti` (long-term registration) with specified durations (24h, 48h) made these easy to identify as ambulatory EKG panels.
- **Genetics (row 1816)**: This name was extremely long and specific. Translating it as a request for a 'Targeted gene variant analysis panel' using NGS is an appropriate abstraction for what is being ordered. It's too complex to be a single result, hence `is_panel: true`.

# Group 34

This group focused on Streptococcus microbiology tests. The key was to differentiate between Streptococcus pyogenes (Group A), Streptococcus agalactiae (Group B), and the broader group of beta-hemolytic streptococci. It was also critical to distinguish the method: culture (`viljely`), antigen detection (`antigeeni`), and nucleic acid amplification (`nukleiinihaponosoitus`).

The grouping was very effective, as it placed many textual variations of the same test concept together (e.g., multiple spellings and truncations for 'beta-hemolytic streptococci culture from throat'). The Finnish system prefixes like `Ps-` (pharyngeal secretion/throat) and `Fl-` (vaginal discharge) were invaluable for determining the LOINC System. For rows lacking a prefix or an explicit source in the name, I defaulted to the generic `in Specimen`.

The term `osoituskoe` ('detection test') was ambiguous, as it could refer to either an antigen or a nucleic acid test. I chose the most common rapid antigen test as the likely meaning. Having the official Finnish 4-digit laboratory code for each `TEST_NAME` would have been a great help in resolving such ambiguities.

# Group 37

This group contained a wide variety of tests, from standard chemistry to complex panels and administrative codes. A significant challenge was the prevalence of long, unspaced Finnish test names, which required careful reading to parse the component, system, and method. For example, `-staphylococcusaureus,metilliiniresist.viljely` clearly breaks down into Staphylococcus aureus, methicillin-resistant, and culture.

Many rows were clearly administrative or billing codes (e.g., `lisämaksu` for 'additional charge', `lisävastaus` for 'additional result', or `apututkimus` for 'helper test'), which should not be mapped to clinical LOINCs. Identifying these required some knowledge of Finnish administrative terms.

The distinction between lab-based and point-of-care tests (`vieritesti`) was common and crucial for correct mapping. Similarly, identifying components of larger automated analyses (like urinalysis by `partikkelinlaskija` or 'particle counter') was key. Finally, the provided `prefix_meaning` was helpful but sometimes misleading, as with the `T-` (Thrombocyte) prefix for T-cell subset tests, demonstrating that the full test name context must always take precedence.

# Group 42

This was a large and diverse group of tests, not clustered by a single analyte. The primary challenge was interpreting a wide variety of Finnish abbreviations, some standard (`P-T4-V`, `P-ACTH`) and some ambiguous or local (`p-fs`, `p-ked.`). The `LongName` column was crucial where available, such as for identifying `P-TT` as Prothrombin Time, not Thrombin Time.

Several specific issues arose:
1.  **Ambiguous Codes:** `p-fs` with unit `s` looked like a coagulation time, but `fs` is not a standard abbreviation. Without a `LongName` or more context, I had to leave it blank. Similarly, `p-ked.` and `p-kjd.` were unidentifiable.
2.  **Panel Identification:** Codes like `p-nak` and `sp-pak` were clearly panels, identifiable by the combined analyte name (`NaK`) or suffix (`-pak`), and confirmed by `p_missing` being 100%. This is a reliable pattern.
3.  **Property and System Specificity:** Mapping coagulation tests (e.g., `P-AT3`, `P-FV`) required choosing the correct property (`[Activity]` or `[Arbitrary concentration]`) and system (`in Platelet poor plasma`). Mapping `P-TT` to `Prothrombin time (PT) actual/Normal` (a ratio) instead of a simple time was a key distinction based on the `%` unit.
4.  **Suffix Interpretation:** The suffix `-pa` (long-term) on `p-k-pa` was confusing for a spot potassium test. I chose to map it to the standard potassium concept, assuming the suffix was an ordering instruction rather than part of the result's definition.
5.  **Data Quality:** Numerous rows had incorrect units (e.g., `g/l` for Sodium). In these cases, the `TEST_NAME` and `deciles` were the deciding factors, and the unit was ignored as a data entry error. The presence of deciles for some rows with high `p_missing` was also a useful hint.

# Group 43

This group was dominated by immunoassays and endocrinology tests. The presence of `LongName` for most was very helpful.

Gotchas and ambiguities:
*   **Platelet function tests** (rows 2635-2638, `b-adp`, `b-aspi`): The unit `auc` (Area Under Curve) is specific to the instrument/method and does not map cleanly to a standard LOINC property like `[Ratio]` or `[Time]`. Without knowing the exact test platform, creating a precise LOINC name is difficult. I opted to leave these blank rather than guess a potentially incorrect property.
*   **Ambiguous abbreviations**: `fs-apot`, `s-apot`, `p-hae`, `s-hae`, `s-hbe`, `s-kem` were too generic or unclear to map reliably.
*   **ENA screen vs. panel** (rows 2703, 2704): Differentiating between the initial screen (`S-Ena`, often an index value) and the follow-up identification panel (`S-EnaL`, a qualitative report or set of results) was key. I mapped `S-Ena` to a quantitative index (`[Units/volume]`) and `S-EnaL` to a panel.
*   **Multiple units for the same test**: AFP, EPO, and TATI appeared with both mass (`ug/L`), molar (`pmol/L`), and/or activity units (`U/L`), requiring distinct LOINC names for what is clinically the same analyte.

# Group 44

This group was a good mix of standard chemistry and more esoteric tests. The presence of `LongName` and clear `prefix_meaning` made most tests straightforward.

**Gotchas and Ambiguities:**
*   **Ambiguous abbreviations**: `b-bio`, `li-bio`, `s-bio` are unclear. While `B-Bio` is nationally `Biopsia`, the `Blood` system makes no sense, suggesting a local code. I correctly left these blank.
*   **Unknown drug screens**: The `u-ds*` codes are clearly local drug screen panel components. Without a key, they are unmappable, and leaving them blank was the only safe option.
*   **Out of scope tests**: `mmse` (Mini-Mental State Exam) and `vp-dop` (Doppler pressure) are clinical assessments/procedures, not lab tests. I was able to map `mmse` because it has a very standard LOINC representation. I left `vp-dop` blank as it's too generic without more context.
*   **Creatinine Ratios**: For `u-intp`, the unit `nmol/mmol` was a dead giveaway for a creatinine ratio, which is crucial for the correct LOINC name (`.../Creatinine [Molar ratio]...`). The variant `nmol/mmolkr` made this even clearer.

**Process Improvement Ideas:**
*   A cross-reference for common drug-of-abuse abbreviations (`amp`, `bzd`, `thc`, `fyl`) would be very helpful. I inferred these from common knowledge, but a provided list would increase accuracy.
*   When a national code (`LongName`) conflicts with a local prefix (like `B-Bio` being 'Biopsy' in 'Blood'), it highlights a data quality issue. Flagging these contradictions could be a useful feature for data cleaning upstream.

# Group 51

This group was dominated by infectious disease diagnostics, primarily antigen and antibody tests. A key challenge was differentiating between qualitative `[Presence]` tests and quantitative tests. The combination of `p_missing=100` and no `UNIT` was a strong signal for qualitative tests. Conversely, the presence of deciles and units like `eiu`, `au/ml`, `index`, or `mg/l` indicated quantitative tests, leading to properties like `[Units/volume]`, `[Ratio]`, or `[Mass/volume]`.

Several codes lacked an explicit system prefix (e.g., `-adenag`). Given the context of respiratory viruses, I inferred the system as `Respiratory system specimen`, which is a safe, general choice. Differentiating between pharynx (`Ps-`) and nasal (`Ns-`) specimens was straightforward thanks to the prefixes.

Identifying panels (`is_panel: true`) was based on abbreviations like `-infrpak` (package) and `-rvirag` (respiratory viruses, plural). I distinguished these from multiplex single tests like `-inabrsv` (Influenza A+B+RSV), which are single LOINC concepts. The guess for `S-InfliPa` as an Infliximab panel (drug level + antibodies) is an educated one based on clinical practice.

The code `-ivf-et` (IVF Embryo Transfer) was clearly a procedure, not a laboratory test, and was correctly left blank. Some codes like `-coinrsv` or `-infah03` were too ambiguous to map confidently.

# Group 68

This was a large and diverse group. The Finnish national code table `LongName` and decoded prefixes (`prefix_meaning`) were extremely helpful in disambiguating tests.

**Gotchas and Ambiguities:**
*   **Missing Prefixes:** Codes like `alfa-1` (5247) and `-amyl` (5245) lack a specimen prefix. I inferred Serum/Plasma for `alfa-1` based on later `S-alfa-1` codes and typical use, but left `-amyl` empty because the deciles were unusual for a blood sample, suggesting a different fluid type where I couldn't be certain.
*   **Unusual Values:** `s-oaldos` (5362) and `s-valdos` (5379) had astronomically high deciles for aldosterone, making them unmappable. These are likely data errors or represent extremely specific, unidentifiable clinical contexts (e.g., sampling from an adrenal vein, massive drug interference).
*   **Vague Abbreviations:** Many codes were too ambiguous to map, e.g., `s-kudosab` ('tissue antibodies'), `s-afospit`, `s-hladsa` (mapped as a panel, but specificities are unknown), `s-afluu`, and `saline` (which isn't a lab result).
*   **Allelic IgE:** `s-kolaige` was a guess for dog IgE. A catalogue of common allergen codes would be helpful for these.
*   **Fractions vs. Specific Analytes:** `s-alfa-1` could be the globulin fraction or alpha-1-antitrypsin. The deciles supported either. I chose the globulin fraction as it's the more direct interpretation of the name, but this is an ambiguity.

**Process Improvements:**
*   Having the official Finnish long name (`LongName`) for every row would be the single most impactful improvement. It instantly clarifies abbreviations like `P-Afos` into 'Alkaline phosphatase'.
*   Context from other similar codes is key. Seeing `P-Amyl`, `S-Amyl`, `As-Amyl`, and `U-Amyl` together makes it clear that `Amyl` is amylase and the prefixes denote the specimen.

# Group 70

This group was very large and diverse, containing everything from routine chemistry to histopathology, serology, and administrative codes. The main challenges were:

1.  **Ambiguous abbreviations**: Codes like `b-nakkrea` or `p-pakk-si` were impossible to decipher. Many codes appeared to be administrative placeholders for frozen (`pakaste`) or reserve (`vara`) samples, which are not true analytical tests and were left empty.
2.  **Macroenzymes**: The series of `s-afmakro...` and `s-maksa...` codes required recognizing the pattern for alkaline phosphatase macroenzyme fractionation. The abbreviation `maksa` (liver) being used for `makroentsyymi` (macroenzyme) was a potentially misleading local convention.
3.  **Context-dependent mapping**: `f-calpro` was clearly fecal calprotectin. The version with no system prefix (`-calpro`) was harder, especially with the `mg/L` unit, which is atypical. I mapped it to a mass/volume LOINC concept for stool, assuming a liquid-phase assay, which is a plausible but uncertain guess.
4.  **Panel vs. Single Test**: Differentiating panels (`u-partik`, `s-maksaab`) from single tests that generate a report (`b-karyot`, `sk-padihot`) was important for the `is_panel` flag.
5.  **Unusual observations**: `u-rakkoai` (bladder time) in hours was interesting. While it represents a real clinical observation about the sample collection, it doesn't map to a standard analyte. I couldn't find a confident LOINC match for this specific concept and left it blank.

# Group 73

This group consists entirely of qualitative nucleic acid tests for respiratory viruses, identified by the `-nho` suffix (`nukleiinihappo, kval`). The `LongName`s, when available, confirmed the abbreviations. The lack of specimen prefixes in the codes meant inferring the `System` as 'Respiratory system specimen', which is the standard for these analytes. 

Several codes were clearly typos or garbled (`-inabnhoho`, `-hinnho`) and were left unmapped. The code `hinflnho` was ambiguous between a typo for 'Influenza' and a test for *Haemophilus influenzae*; given the viral context of the group, a typo is more likely, but to be safe, I left it unmapped. 

The primary point of ambiguity was whether a code for multiple pathogens (e.g., `-inabnho` for Influenza A and B) represented a single multiplex result or a panel ordering two separate tests. I interpreted these as panels, as this often reflects laboratory ordering practice, and suitable LOINC panel concepts exist. This assumption is a potential source of error if the source system uses a single code for a combined positive/negative result.

# Group 74

This group was dominated by qualitative nucleic acid tests, identifiable by the `-nho` suffix and 100% missing values. The main challenge was the frequent absence of a specimen prefix in the test code.

For known respiratory pathogens (Bordetella, Bocavirus, Coronavirus), I inferred the system as `Respiratory system specimen`. For other pathogens with no specified specimen (e.g., `baktnho`, `salmnho`), I used the generic `Specimen` to avoid making an incorrect assumption. Prefixes like `r-` (`-rbaktnho`) and `res-` (`resbaktnho`) were interpreted as 'respiratory', reinforcing this choice.

The `kv...nho` codes (5824-5827) were a good example of pattern recognition, where `kv` likely stood for `Koronavirus` and the following characters matched known human coronavirus strains (229E, HKU1, NL63, OC43).

The code `f-paranho` (F-Parasiitit, nukleiinihappo) was ambiguous. While 'Parasites' suggests a panel, it's a single result code. I mapped it to `Protozoa DNA [Presence]...` as a plausible guess for a broad-range PCR target, as `Parasites DNA` is not a standard LOINC component.

# Group 79

This group was a good example of how a single clinical concept (urinary albumin) can manifest as many different LOINC terms depending on the property and system. The main challenges were:

1.  **Differentiating properties**: It was crucial to distinguish between mass concentration (`mg/l`), mass rate (`ug/min`, `mg/12h`), and mass ratio (`mg/mmol`). The `UNIT` and `deciles` columns were essential for this.
2.  **Decoding abbreviations**: I had to correctly interpret `cU` (collected), `nU` (night), `-Mi` (micro), `-O` (qualitative), and `Kre`/`Krea` (creatinine). The `LongName` and `suffix_meaning` columns were very helpful when present.
3.  **Ambiguous and concatenated `TEST_NAME`s**: Rows like 6271 (`u-alb/kre,u-alb`) and 6274 (`u-alb/kre,u-krea`) were problematic. The only way to resolve them was to look at the `deciles`, which strongly suggested they were actually measuring just one of the named components (albumin in the first case, creatinine in the second). This is a tricky data quality issue where the `TEST_NAME` is misleading.
4.  **Handling urine sediment components**: The `U-Sakka` tests required recognizing them as individual components of a manual microscopy exam. The unit `u/field` in some rows was the key clue to select `[#/area]` as the property and `...by Light microscopy` as the method.
5.  **Speculative mapping**: For `u-a1mikre` (row 6259), the guess of `Alpha 1 microglobulin/Creatinine` is plausible but not certain without a `LongName`. It's a reasonable interpretation given the `A1M` pattern and the context of other urine ratios.

Overall, the combination of code structure, units, and deciles made it possible to untangle the different test variations effectively.

# Group 84

This group consists almost entirely of administrative or procedural codes related to specimen handling, not laboratory tests that produce a result. This is evident from the names (`näytteenotto` = sample collection, `näytteen käsittely` = sample processing, `näytteen kuljetus` = sample transport, `ottotapa` = collection method) and the fact that nearly all rows have 100% missing numeric values.

The mapping challenge here is that these local codes often contain more specific context (e.g., `bm-` for bone marrow, `gyn.` for gynecologic, `valv.` for supervised) than is available in a single general LOINC procedural code. I mapped these to generic LOINC concepts like `Specimen collection procedure` because it's the most appropriate general fit, even if it loses some local detail. These are likely used for workflow tracking or billing rather than clinical reporting.

A significant data quality issue was present in row 6675 (`ottotapa`), which had a unit of `h` (hours) and numeric deciles. This makes no sense for a concept meaning "collection method" and was therefore left unmapped as it's impossible to interpret.

# Group 85

This group contained a mix of clearly defined chemical analytes (Urate, Acetone, Valproate), microbiology, and some very cryptic local codes. The main challenge was dealing with missing system information. For `uraatti` (row 6714), the deciles were a perfect match for `p-uraatti`, allowing a confident inference of the `Serum or Plasma` system. For others like `norogi` (row 6699) or `cand.nativ` (row 6686), the lack of a system prefix made them unmappable, even though the component was clear. Local abbreviations like `-omactgc` (rows 6682, 6713) are also tricky; `ctgc` appears to be a common localism for CT/GC testing, and recognizing this pattern was key to mapping `u-omactgc` to a panel. The `LongName` for `ts-abortti` was crucial for identifying it as a pathology report on products of conception. Finally, the unit was essential for distinguishing the allergy skin test `cladosp.he` in `mm` from the serum IgE test in `u/ml`.

# Group 89

This group was dominated by codes ending in `-seul` or `-seula`, Finnish for "screening". This was a powerful hint, almost always indicating a panel of tests. Correctly identifying these as panels (`is_panel: true`) was the main task. The high `p_missing` rate for these codes reinforced this, as panel orders typically don't have a single value themselves.

The group covered a wide range of common screening procedures, from lab panels (`U-KemSeul` for urinalysis, `S-Tr1Seul` for first-trimester maternal screening) to clinical assessments (`hörsel` for hearing, `näköseula` for vision). This required knowledge beyond pure lab terminology. The presence of a Swedish word (`hörsel`) also highlights the bilingual nature of some data sources in Finland.

When available, the `LongName` column was invaluable for confirming the meaning of abbreviations, as seen with the maternal screening tests (`S-Tr1Seul`, `S-Tr2Seul`). For ambiguous codes like `hoikemseul` with no supporting information, leaving the guess empty was the only responsible action.

# Group 105

This group was a textbook example of how a single panel code (like `B-PVK`) can be used in source data to represent both the panel order itself and the individual component results within that panel. The key was to distinguish these two use cases based on whether `UNIT` and `deciles` were present.

Gotchas:
*   **Panel vs Component:** Rows with `p_missing=100` and no unit were clearly panel orders. Rows with specific units (`g/l`, `fl`, `e9/l`, etc.) and numeric data were unpacked components.
*   **Code variations:** `B-PVK`, `B-PVK+T`, `B-PVK+TKD`, and `B-TVK` represent different levels of a complete blood count: short/basic (`PVK`, `PVK+T`), with automated differential (`TKD`, `TVK`), or with a mini-differential (`TMD`). Mapping them to appropriate LOINC panels (`Short blood count panel`, `CBC panel by Automated count`, etc.) was crucial.
*   **Unpacking components:** The `b-pvk+tkd,<analyte>` codes were very helpful as they explicitly named the component. This helped confirm the mappings for less specific codes, e.g., identifying that `g/l` with deciles ~330 is MCHC (row 8579) and not Hemoglobin (deciles ~140, row 8562).
*   **Ambiguous units:** The unit `form` (rows 8561, 8578, 8643) was uninterpretable. The unit `eg/l` (row 8626) was a clear typo for `E9/l`, confirmed by the deciles for platelets.

The logic was to first identify the base panel, then for each row, determine if it's a panel order or a component result. If a component, use the `unit` and `deciles` to identify the analyte. This strategy worked well for this highly structured hematology group.

# Group 106

This group was large but highly structured around the `Bakt` (bacteria) component and a consistent set of suffixes (`-vi`, `-vr`, `-lm`, etc.) and specimen prefixes. The primary challenge was distinguishing between different types of tests that share a similar local code, particularly in the large `U-Bakt` (urine bacteria) section.

The key to disambiguation was to carefully use the `UNIT`, `deciles`, and `p_missing` columns. For instance, `U-Bakt` with `UNIT` `e6/l` and low `p_missing` clearly pointed to a quantitative automated count (`Bacteria [#/volume] in Urine by Automated count`). In contrast, the same base code with a `UNIT` of `/sunf` (field of view) indicated microscopy (`Bacteria [#/area] in Urine sediment...`). Finally, `U-BaktVi` (urine culture) with deciles showing large colony counts (10^4, 10^5) mapped to a quantitative culture (`Bacteria [#/volume] in Urine by Culture`), while variants with 100% missing values were interpreted as the identification part of the culture (`Bacteria identified in Urine by Culture`).

The `LongName` field was very helpful, for example in identifying `Ca-` as catheter tip culture, `Pu-BaktVi1` as anaerobic/aerobic, and `Pu-BaktVi2` as aerobic-only. The presence of `Candida` in the `LongName` for `F-BaktVi2` (row 8672) was a crucial detail, prompting a more specific guess (`Bacteria and Fungus identified...`).

Some codes remained ambiguous (e.g., `d-baktvi`, `u-baktla`), and were correctly left blank. This group highlights the necessity of using all available data columns to differentiate clinically distinct tests that may be represented by very similar local codes.

# Group 110

This group was dominated by immunophenotyping tests (CD markers). The main challenges were:

1.  **Differentiating absolute vs. relative counts:** The local codes use prefixes (`B-` vs `Ly-`) and units (`e9/l` vs `%`) to distinguish between absolute counts (cells/L) and relative counts (percentage of a parent population). This was a critical distinction for constructing the correct LOINC name (`Component [#/volume] in System` vs. `Child/Parent in System`). The `LongName` entries, when available, confirmed these interpretations.

2.  **Non-standard prefixes:** The prefixes `La-` and `So-` were not standard. I inferred `La-` as `Leukapheresis product` from the context of CD34 counts and the `e6/kg` unit, which is specific to stem cell transplant dosing. This was an educated guess but a strong one. The `So-` prefix remained ambiguous; without knowing the system (specimen), I could not create a valid LOINC name and had to leave those rows blank.

3.  **Redundant or mistyped codes:** Many codes contained redundant information (e.g., `B-T-CD3` where CD3 already implies T-cell) or typos (`b-b-cd19`, `ly-tt-cd8`). Grouping similar codes was essential to see they all represented the same underlying test concept.

4.  **`S-GT-CDT`:** This was a tricky one. The code appeared to conflate two different markers, GGT and CDT. However, the unit (`%`) and deciles strongly suggested it was the standard CDT test, which is a ratio (`Carbohydrate deficient transferrin/Transferrin.total`). I concluded that `GT-CDT` was a local, perhaps misleading, name for the CDT test.

Overall, the process worked well for this group because immunophenotyping has a very regular structure that aligns with LOINC's compositional model. The deciles and units were crucial for disambiguation.

# Group 111

This group was dominated by COVID-19 tests, which highlights several common mapping challenges. A large number of local codes (`-cv19ag`, `-cv19ag0`, `pika-covid-19ag`, `oma-covid-o`, etc.) all correspond to the same concept: a qualitative rapid antigen test. The `LongName` fields for many of these were brand names of test kits (Panbio, Flowflex, etc.), which correctly map to a generic LOINC term. The `cv19infrs` code was an interesting case of a local abbreviation for a multiplex panel (COVID, Influenza, RSV).

A significant data quality issue was apparent for the `-cv19ag` test (rows 9096-9105), where a fundamentally qualitative test was recorded with a wide variety of quantitative units. I inferred these were errors and mapped them to the qualitative concept, as confirmed by the high `p_missing` and lack of unit in the most common variant (row 9106). This pattern of erroneous units on qualitative tests is a recurring theme.

Finally, some codes like `-covidjt` and `cldinho` were too ambiguous to map confidently, even with context from the group. The `cldinho` code was particularly tricky as it contained a recognizable suffix (`nho` for nucleic acid) but an unidentifiable prefix.

# Group 121

This group was dominated by molecular genetics and hematopathology tests. The `LongName` and `suffix_meaning` columns were crucial for disambiguation. For example, the `-D` suffix (DNA test) and `p_missing=100` immediately pointed towards qualitative or nominal genetic tests.

The abbreviations were largely decodable for common genetic targets (e.g., `FV` for Factor V, `JAK2`, `BCR`, `LAKT`). The system prefixes (`B-` for Blood, `Bm-` for Bone Marrow) were also highly consistent and useful. Many tests were identifiable as panels (e.g., `b-varfa-d` for warfarin pharmacogenomics, `bm-mggfe` for bone marrow morphology + iron stain), which required creating panel-type names.

Ambiguities arose from very generic codes like `b-fuus-mr` (fusion gene), `b-sekvy-d` (sequencing), or un-annotated acronyms like `b-auria10`. Without more context or a `LongName`, these are impossible to map. The `form` unit was a useful clue indicating a structured/narrative report, reinforcing the qualitative nature of many of these tests.

# Group 126

This group was straightforward as it revolved entirely around glucose ('gluk'). The main challenge was differentiating between fasting/baseline samples, timed samples from a glucose tolerance test (GTT), and point-of-care tests. The numeric suffixes (0, 30, 60, 1h, 120, 2h) and the deciles were key to identifying the timed GTT samples. Finnish abbreviations like 'vieri' (point-of-care), 'ras' (rasitus, challenge), and 'valm' (valmistelu, preparation) were very helpful. Codes with 'valm' or 100% missing values were clearly procedural/order codes, not results.

The most unusual codes were `-gluk-tbr` and `-gluk-tir` with unit `%`. The deciles strongly suggested 'Time Below Range' and 'Time In Range' from Continuous Glucose Monitoring (CGM). This is a newer type of measurement, and it was interesting to see it appear in this dataset. Mapping them to the generic LOINC CGM concepts felt correct as the local codes didn't specify the exact glucose thresholds for the range. The leading hyphen in these codes is odd, perhaps indicating they are derived or calculated values within a specific system's report format.

# Group 129

This group was dominated by `Pt-` (Patient) prefixed codes, which typically denote whole-patient investigations or panels rather than specimen-based lab tests. This made the `is_panel` flag crucial. The primary difficulty was deciphering the heavily abbreviated and sometimes non-standard test names. For example, `pt-fvspiro` likely means 'Patient - Flow Volume Spirometry with bRonchodilator', but this requires inferring `spiro` from `spi`, and `r` (for the standard Finnish suffix `-R`) from `o`. Having the Finnish long name (`LongName`) for more rows would have been extremely helpful, as seen with `pt-sper-*` (Semen analysis) and `pt-st-temp` (Thermal sensory threshold). The presence of `form` in the `UNIT` column and 100% missing values for many rows reinforces the idea that these codes often represent orders for complex studies or entire reports, not individual measurable results. A significant number of codes remained too ambiguous to map, highlighting the challenge of working with truncated or idiosyncratic local variations.

# Group 160

This group was very straightforward. The `TEST_NAME` values were the full Finnish names for three common liver enzymes: `alaniiniaminotransferaasi` (ALT), `aspartaattiaminotransferaasi` (AST), and `glutamyylitransferaasi` (GGT). The unit `U/l` and the associated deciles consistently indicated an enzymatic activity measurement, leading to the `[Enzymatic activity/volume]` property.

The main variation between rows was the specimen type, indicated by prefixes (`p-`, `s-`, `fp-`, `fs-`) or by an explicit name suffix (`...plasmasta`). For these common chemistry tests, LOINC uses the broad system `Serum or Plasma`, which correctly covers all these variants. The fasting status (`fp-`, `fs-`) is not typically distinguished in the main LOINC term for these enzymes, so it was appropriate to map them to the same general concept. All rows were clearly single-analyte tests, so no panels were involved.

# Group 161

This group was a mix of many different tests, requiring individual analysis for each concept rather than leveraging group context for a single concept. The main challenges were:

1.  **Implicit Systems:** Many microbiology tests (e.g., `Chlamydia pneumoniae`, `Haemophilus influenzae`) lacked a system prefix. I had to infer the most likely specimen type (e.g., Respiratory system specimen) based on the pathogen's typical presentation. The presence of `Li-` (CSF) for `H. influenzae` in one row (13040) helped confirm that system-less codes likely referred to a different specimen type.

2.  **Challenge/Timing Nuances:** The glucose and C-peptide tests required careful parsing of Finnish terms like `aterian jälkeen` (after meal), `toimintakokeissa` (in functional test), and specific timings (0h, 1h, 2h) to map to appropriate LOINC challenge terms (e.g., `--2 hours post dose glucose`, `--post meal`).

3.  **Specific vs. General:** Differentiating between patient-measured capillary glucose (`ihopisto` = skin prick, row 13050) and continuous sensor glucose (`sensori`, row 13052) was crucial, as they map to different LOINC systems (`Capillary blood` vs. `Interstitial fluid`).

4.  **Panel Identification:** A test like `ulosteen ripulivirukset` (fecal diarrhea viruses, row 13067) is clearly a panel, and requires mapping to a panel concept, not a single analyte. Identifying these is key.

Having the `prefix_meaning` was extremely helpful, as seen with `B-` (Blood) and `Li-` (CSF). When it was missing, the task became significantly more ambiguous.

# Group 162

This group contained a good mix of standard chemistry, hematology, and more specialized tests. The string grouping was particularly effective for tests like RDW (`punasolujen kokojakauma`) and free/total PSA ratio, which appeared under many different local spellings.

The main challenges were:
1.  **Ambiguous Panels**: Codes like `fs-työterveyshuollonperuspaketti` (occupational health basic package) or `s-nightingale-mittaus` are clearly panels, but their contents are unknown, making it impossible to select a specific LOINC panel. I correctly identified them as panels but left the name guess empty.
2.  **Procedure/Administrative Codes**: Several codes represented procedures (`ekg,hoitoyksikönottama`, `pt-vaativainhalaatiohoito`) or administrative events (`erikoislääkärinkonsultaatio`), not laboratory results. I mapped EKG to a panel but left the others empty as they don't fit the lab test model.
3.  **Conflicting Information**: The test `p-urea,resirkulaatio` (row 13138) had a name suggesting a percentage (recirculation) but a unit of `mmol/l`. This internal contradiction makes it unmappable, and I correctly left it empty.
4.  **Blood Gas System Ambiguity**: The `AB-`, `VB-`, `CB-` prefixes were clear, but a code like `p-aktuaalinenbikarbonaatti` (row 13124) is ambiguous. I interpreted `P-` in a blood gas context as likely referring to a sample from venous blood, but this is an assumption. More context on local conventions for blood gas specimen labeling would be helpful.

# Group 167

This group was a good example of how local test names encode a lot of context. The term "osatutkimus" (component test) consistently indicated that the code represents a single result from a larger analysis, correctly setting `is_panel` to `false`.

The distinction between absolute (`[#/volume]`) and relative (`/Leukocytes`) cell counts was very clear. Codes with a `b-` prefix, `e9/l` unit, and terms like "absol.arvot" pointed to absolute counts. In contrast, codes with an `l-` prefix or `%` unit pointed to relative counts (fractions of leukocytes).

The protein electrophoresis results were also quite clear. The text `osatutkimus s-prot-fr` in the `TEST_NAME` was a strong signal that these were components of a serum protein fraction analysis, making it appropriate to add `by Electrophoresis` to the LOINC name guesses for albumin, globulins, and the M-components. The `(valetietue...)` or 'dummy record' text for M-components was an interesting detail, showing how labs embed metadata for data entry purposes.

