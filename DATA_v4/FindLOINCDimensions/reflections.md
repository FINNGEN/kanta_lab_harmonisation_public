# Group 7

This group was straightforward, focused on tissue transglutaminase antibodies (IgA and IgG). The Finnish names were quite descriptive.

*   **Gotcha**: The name `s-transglutaminaasivasta-aineet` (rows 384, 385) does not specify the immunoglobulin class. I mapped this to a generic `Transglutaminase Ab` component. This is a safe search query, as it could represent a total antibody measurement or a screening test where the lab system didn't specify the class. The alternative, assuming it's IgA because that's the primary screening test, would be a stronger but potentially incorrect assumption.
*   **Data Quality**: Suffixes like `(keliakia)` (celiac disease), `keliakiatutkimus` (celiac investigation), and `osatutk.` (part of study) provided clinical context but didn't change the analyte. My interpretation was to ignore these for the LOINC name construction, as they describe the reason for the test rather than the test itself, which aligns with LOINC's principles. Similarly, the `eliau/ml` unit hinted at an ELISA method, but I correctly omitted the method to create a broader, more robust search query.
*   **Process Improvement**: The high number of rows with missing units and values for tests that are clearly quantitative highlights the importance of the instruction to guess the property based on the most common form of the test. Consistently assuming `[Units/volume]` for these antibody tests, based on the rows that did have a `U/ml` unit, was the key to handling this group effectively.

# Group 14

This group was entirely about C-reactive protein (CRP), but with many variations that test the mapping logic. The main challenges were:

1.  **Standard vs. High-Sensitivity (hs-CRP):** The keyword `herkkä` (sensitive) was a reliable indicator for hs-CRP (`C-reactive protein.high sensitivity`). However, several codes without this keyword (e.g., rows 1043, 1049) showed value distributions characteristic of hs-CRP. I consistently prioritized the explicit name over the value distribution, mapping these to standard CRP. This is a safer bet for a search query, as the patient population can skew values, but it highlights a significant data ambiguity.

2.  **Point-of-Care (POC) Tests:** Numerous terms indicated a POC or rapid test (`pika`, `vieritesti`, `hoitoyksikkö`, `ihopiston`). My strategy was to generally omit the method from the LOINC name guess, as most LOINC CRP terms are method-less. I only specified a different system, `Capillary blood`, when the term `ihopiston` (skin prick) gave a strong justification. This simplifies the search and avoids making it overly specific.

3.  **Specimen Type:** Specimen was specified by prefix (`B-`, `P-`, `S-`), by a word in the name (`veri`, `plasma`, `seerumi`), or not at all. My rules were to use the specified specimen, and default to `Serum or Plasma` when unspecified, which is standard LOINC practice for general chemistry.

4.  **Contradictory Information:** Row 1016 included `(kval)` suggesting qualitative, but the unit `mg/l` and quantitative values contradicted this. I correctly prioritized the quantitative evidence over the ambiguous text qualifier. Similarly, `osoitus` (indication) in row 1040 suggested qualitative, but a sibling row (1041) was clearly quantitative, so I mapped all of them to the quantitative concept.

# Group 20

This group was dominated by two types of tests: electrocardiograms (ECG) and nucleic acid amplification tests (NAATs) for various pathogens. The Finnish names were quite descriptive, making interpretation straightforward.

**ECGs:** Most codes referred to a standard "12 lead resting ECG" (`12 kytkentää levossa`), which maps well to the LOINC `12 lead EKG panel`. Numerous variations included administrative details like the recording location (`osastolla`, `terveyskeskus`), whether it was patient-recorded (`asiakkaan ottama`), or included a computer analysis (`sisältäen tietokoneanalyysin`). I consistently mapped these to the same core `12 lead EKG panel` because these details generally don't lead to a different top-level LOINC panel concept. A notable exception was the "atrial fibrillation screening from monitor ECG" (`eteisvärinänseulonta, valvontamonitori-ekg`), which is a different clinical procedure. I guessed `Atrial fibrillation [Interpretation] by EKG.monitor` to capture this specific screening intent, which is a departure from a diagnostic 12-lead study.

**NAATs:** Many codes used the abbreviations `nukl.haponos` or `nho`, clearly indicating a nucleic acid test. The system was specified by prefixes (`F-` for Feces/Stool, `Li-` for CSF), and the target organism was named. This allowed for precise guesses like `Organism [Presence] in System by NAA with probe detection`. For pathogens where the specimen was not specified (e.g., `ehec`), I defaulted to `Stool` as the most common system for enteric pathogens.

# Group 21

This group was straightforward, covering two main concepts: Transferrin Saturation and Soluble Transferrin Receptor. The Finnish names `rautakyllästeisyys` and `saturaatio` both clearly map to saturation, while `reseptori` maps to receptor.

A key ambiguity was the representation of Transferrin Saturation. Some rows had values in the percentage range (e.g., 8-40) with unit `%`, while others had values in the fraction range (e.g., 0.08-0.40) with no unit or the unit `osuus` (fraction). Fortunately, the LOINC property `[Molar ratio]` correctly covers both representations, so a single LOINC name works for all of them. This is a good example of where relying on the value deciles is crucial when the unit is missing.

The unit `paketti` (package) on row 1327 was a potential gotcha. However, its very low `unit_share` (4%) and the fact that the name specifies a single analyte (`transferiininrautakyllästeisyys`) strongly suggest a data entry error rather than a true panel. I correctly interpreted this as noise and mapped it to the single analyte test.

# Group 33

This group primarily contained microbiology cultures, toxicology panels, and a few clinical procedures. The grouping by string similarity was essential for interpreting truncated names for MRSA culture sites (e.g., `viljelyne` next to `viljelynenästä` made it clear the site was `Nose`).

The drug screen panels were straightforward to parse into LOINC panel names by listing the analytes. `Urine` was a reasonable default system for these screens when not explicitly mentioned.

The Holter EKG tests were also clear, identified by `Pt-EKG` and `pitkäaikaisrekisteröinti` (long-term recording), easily mapping to `EKG XX hour study`.

The most ambiguous case was row 1816, a very long and generic description of a targeted NGS analysis. My guess, `Gene variants and Copy number variants panel - Specimen by NGS`, is a broad interpretation intended to capture the key methodological components mentioned in the name ('base changes', 'copy number variations', 'NGS'). This is a 'best effort' guess for what is more of a service description than a specific test.

# Group 34

This group focused on microbiology tests for Streptococcus. The main challenge was the lack of an explicit specimen (system) in many of the test names. I inferred the most likely specimen based on clinical context: `Throat` for Streptococcus pyogenes (Group A) and `Vagina` for Streptococcus agalactiae (Group B). This is a reasonable and necessary guess, as an unspecified system would make the search query less effective.

The Finnish terms `nukleiinihaponosoitus` (nucleic acid detection), `viljely` (culture), and `antigeeni` (antigen) were clear indicators of the method. The various truncated and misspelled versions of `hemolyyttiset streptokokit` (hemolytic streptococci) for throat culture were easily resolved because the rows were grouped by string similarity.

A specific ambiguity arose with `osoituskoe` ('detection test'), which is non-specific about the method. I interpreted it as a rapid antigen test, which is a common screening method for Strep A, but it could also refer to a nucleic acid test. More specific terminology in the source data would have resolved this.

# Group 37

This group contained a wide variety of tests, including standard chemistry, microbiology, hematology, point-of-care testing, complex procedures (`Pt-` prefixed codes), and several administrative or billing codes. 

Gotchas and ambiguities:
*   **Administrative codes:** Several codes were clearly for billing or administrative purposes (e.g., `lisämaksu...`, `lisävastaus...`, `pt-näytteenotto0maksu`). These were left with an empty guess.
*   **Instrument-specific codes:** Rows 1936-1938 (`...aptimapanther...apututkimustulostensiirtoon`) appear to be codes for managing data flow from a specific instrument platform, not for ordering a clinical test. These were also left empty.
*   **Point-of-care (`vieritesti`):** This qualifier was frequent. I chose to name the core test (e.g., `Glucose [Moles/volume] in Blood`) and omit the method, as `point-of-care` is often a separate attribute or part of a distinct LOINC concept. Including it in the name as `by Point-of-care` might make the search too specific and miss the core concept. The exception was for urine dipstick tests where `by Test strip` is standard LOINC practice.
*   **Misleading prefixes:** Rows 1985 and 1986 (`t-auttajasolujen...`, `t-estäjäsolujen...`) used the `T-` prefix (for Thrombocytes), but the test names clearly describe T-lymphocyte subsets (helper/suppressor cells). I ignored the prefix and named the tests based on the full name and immunology context.
*   **Panels vs. single tests:** Many codes clearly described panels (`CBC with Differential`, `Blood gas panel`, various drug screen panels). Other codes like the histology/pathology descriptions (`pienikudoskoepala...`) are ambiguous; they describe a procedure that results in a report, which functions like a panel. I used panel naming conventions where appropriate.
*   **Unit errors:** Row 1945 for creatinine had unit `mmol/l` but values in the range of `µmol/l`. I trusted the numeric values over the stated unit.

# Group 42

This group was dominated by sodium (`Na`) measurements in various specimens, which were straightforward. The main challenges were:

1.  **Ambiguous abbreviations**: `P-fs` (2527), `P-ttr` (2591), `P-ked.` (2543), `P-kjd.` (2544), and `pneag` (2602) were not standard. For `P-fs` and `P-ttr`, I used the unit and value ranges to infer they were `Thrombin time` and `Prothrombin time`, respectively. For the others, I had to leave the name empty as there wasn't enough information to form a reasonable hypothesis.
2.  **Panel identification**: Several codes like `P-NaK`, `P-K+Na`, and `ap-nak` clearly indicated panels. The `100% p_missing` for these rows supported the interpretation that they are orderables, not resultables. I named them as panels.
3.  **Pulmonary function tests**: `PEF` codes were present. The Finnish suffixes `-pa` (long-term) and `-ras` (exercise) were crucial for selecting the correct LOINC concept type (monitoring vs. challenge test).
4.  **Troponin versions**: The data contained codes for standard troponin (`P-TnI`), high-sensitivity (`P-hsTnI`, `P-TNIH`), and Troponin T vs. I. Distinguishing these required careful attention to the abbreviations. I added `by High sensitivity method` where the code implied it.
5.  **Specimen nuances**: Most plasma/serum chemistry was mapped to `Serum or Plasma`. Coagulation tests (`P-AT3`, `P-FV`, `P-TT`) were mapped specifically to `Plasma`. Arterial samples (`aB-`, `aP-`) were also specifically named.

# Group 43

This group contained several ambiguous abbreviations that were difficult to map without a LongName, leading to empty guesses. Examples include `p-hae`/`s-hae`, `s-hbe`, `p-hepg`, `p-hok`, and `s-kem`. The `fs-tp-*` series was also unidentifiable. The distinction between a screening test (`S-Ena`, row 2703) and a speciation panel (`S-Enal`, row 2704) was subtle but inferable from national code lists; the presence of quantitative values for the screen (a ratio) was a key piece of evidence.

The code `-ana` (row 2630-2631) with a leading dash is unusual and likely a data entry error, though its meaning was clear. Similarly, `s-afp/d` (row 2675) has an unclear `/d` suffix which I assumed was a local, non-mappable modifier.

For `U-hCG` without a unit (row 2734), I inferred a qualitative test (`[Presence]`) based on the most common clinical use case for urine hCG (i.e., pregnancy screening dipstick) and the high percentage of missing values, in contrast to the explicitly quantitative `iu/l` and `u/l` units on other rows for the same code. This is an interpretative leap but a pragmatic one.

# Group 44

This group contained a good mix of standard chemistry tests, toxicology screens, and a few more obscure or problematic codes. 

**Gotchas and Ambiguities:**
*   **Ambiguous abbreviations:** `bio` (guessed as Biotin), `fsl` (guessed as a coagulation test), and `inf` (guessed as a bacterial culture) were challenging. The guess for `inf` (infection) as a culture is a clinical inference that may or may not be correct but is a plausible starting point.
*   **Opaque codes:** The `U-DS*` series of codes were impossible to decipher without external information. They likely represent a specific local panel or drug screen, but no analyte could be identified.
*   **Non-lab tests:** `MMSE` (Mini-mental state examination) and `vp-dop` (Doppler blood pressure) are clinical assessments, not lab tests. Recognizing these and using the appropriate LOINC naming convention (e.g., survey name, panel name for a device reading) is key.

**Data Quality Issues:**
*   Unit typos were frequent (e.g., `mmol/`, `mlu/l`, `mu/l`), but generally easy to correct based on the analyte's typical value range and more common unit spellings in other rows.
*   Misleading suffixes, like `-Cl` on `U-Cl` for clearance, can be confusing. I decided to ignore it because the unit (`mmol/L`) clearly pointed to a simple concentration, not a clearance rate.

**Process Improvements:**
*   For ratio tests like `U-iNTP`, where the unit is `nmol/mmol`, it was necessary to know the implicit denominator is Creatinine. Making this explicit (e.g., in a `LongName` like "Kollageeni.../kreatiniini") would be helpful. The unit `nmol/mmolkr` did provide this hint, which was useful.

# Group 51

This group was dominated by microbiology tests, particularly viral antigens and antibodies. The leading hyphen in many codes (e.g., `-adenag`) made it impossible to determine the specimen system from the code alone. In these cases, I inferred a `Respiratory specimen` based on the analytes (Influenza, RSV, etc.), which is a reasonable but not guaranteed assumption. The `LongName` was very helpful when present, confirming analytes and sometimes specimens, as with `ps-adenag` which specified a nasopharyngeal sample.

There were many instances of the same test code appearing with and without quantitative information. I systematically mapped rows with units like `eiu`, `u/ml`, `index`, or `s/co` to quantitative properties (`[Units/volume]`, `[Ratio]`) and those without to qualitative `[Presence]`. This distinction is crucial. Units like `form` were interpreted as qualitative.

Some abbreviations were ambiguous (`-coinrsv`, `bi-inflamm`) or likely misspelled (`s-micfaeg`), requiring interpretation from context or knowledge of common tests. The code `-ivf-et` (Embryo transfer) was a procedure rather than a lab test, which is a different category of concept in LOINC. Finally, several codes clearly represented panels (`-inabrsv`, `-infrpak`, `s-inflipa`), which I named using the LOINC panel convention.

# Group 68

This group was characterized by many variations of a few core analytes, particularly Amylase and Alkaline Phosphatase (AFOS). The Finnish abbreviations for AFOS isoenzymes (`-luu` for bone, `-suoli` for intestinal, `-muut` for other) were quite systematic and easy to interpret once the pattern was recognized. This allowed for specific LOINC component guesses like `Alkaline phosphatase.bone`.

A significant ambiguity arose with several Aldosterone (`aldos`) tests that had cryptic prefixes (`a-`, `o-`, `v-`) and extremely high, non-physiological values (e.g., `s-valdos`, `s-oaldos`). While the core analyte was clear, the context (which is crucial for these values) was lost. I mapped them to the base Aldosterone concept, but these almost certainly represent specific collection sites (e.g., adrenal vein sampling) or post-stimulation tests. Without more information, a more precise guess is impossible.

There were also several completely unmappable codes like `s-kalatue`, `s-ngmuut`, and `saline`, which appear to be either very obscure abbreviations, data entry errors, or administrative codes rather than lab tests. Correctly identifying these as unmappable is an important part of the process.

# Group 70

This group contained a large number of administrative or storage-related codes (`s-pakaste`, `b-vara`, etc.) which are unmappable and were left empty. These are common in source data but represent pre-analytical or logistical steps, not observations. The `s-maksa*` and `s-afmaks*` series of codes were ambiguous, likely referring to different liver enzymes (ALT, AST) or alkaline phosphatase isoenzymes without being specific. I made educated guesses (e.g., mapping `maksa-1` to ALT) but this is a low-confidence mapping. Similarly, `p-varmtr` was obscure, and I had to guess a generic coagulation test. Having a more complete national codebook with mappings from these local abbreviations to official long names would resolve most of these ambiguities. The IgE allergy tests (`-pähe`, `-päe` suffixes) were quite clear, as were the therapeutic drug monitoring tests (carbamazepine, valproate). The variety of units for `S-Parvabg` (parvovirus IgG) demonstrates the importance of mapping each unit combination separately, as `titre`, `index` (Ratio), and `iu/ml` (Units/volume) all correspond to different LOINC properties.

# Group 73

This group was dominated by nucleic acid tests for respiratory pathogens. The local suffix `-nho` was a very reliable indicator for 'nukleiinihappo (kval)', which translates to a qualitative nucleic acid test. This allowed for consistent mapping to a `[Presence]` property and a `by NAA with probe detection` method.

The main challenges were:
1.  **Ambiguous abbreviations**: Codes like `-hinnho` and `-tintnho` were too garbled to interpret reliably and were left empty.
2.  **Context vs. direct reading**: The code `hinfnho` strongly suggests *Haemophilus influenzae*, a bacterium, even though it's surrounded by viral tests. I chose to map it as a bacterial DNA test, assuming it's a valid part of a differential diagnosis panel for respiratory symptoms.
3.  **Data artifacts**: Many codes had a leading dash (`-`) or a stuttered suffix (`-hoho`), which were clearly artifacts and ignored in the mapping.
4.  **Panel vs. single test**: The code `-inabrsnho` was interpreted as a panel for Influenza A, B, and RSV. The code `-inabnho` for Influenza A and B was interpreted as a single combined test rather than a panel, as LOINC has concepts for this pattern.

Since no specimen information was provided in the codes, `Respiratory specimen` was used as a default, which is a safe and common choice for these pathogens.

# Group 74

This group was dominated by nucleic acid tests, identifiable by the `nho` suffix and confirmed by `LongName`s like `nukleiinihappo (kval)`. The main tasks were to decode the analyte abbreviation and select the correct system.

**Gotchas and Ambiguities:**
*   **Component decoding:** Several codes were local inventions or typos. The group's string similarity was crucial for interpreting `-bocanho` as `-bokanho` (Bocavirus) and for identifying the block of `kv...nho` codes as various Human coronaviruses (e.g., `kv229enho` for HCoV-229E).
*   **Interpreting Prefixes:** Non-standard prefixes like `r-` and `res-` required an educated guess (Respiratory specimen). Codes starting with a dash or lacking a prefix were mapped to the generic `Specimen`.
*   **Property Choice (`[Presence]` vs. `[Identifier]`):** For broad-spectrum tests like `-baktnho` (Bacteria) or `f-paranho` (Parasites), I chose `[Identifier]` over `[Presence]`. My reasoning is that such tests typically aim to identify which organism is present (e.g., via a multiplex PCR panel or 16S sequencing), not just give a yes/no for the entire class. This is an interpretation based on clinical utility.
*   **DNA vs. RNA:** I specified DNA or RNA in the component name based on the pathogen type (e.g., `Sapovirus RNA`, `Human bocavirus DNA`). This adds precision but requires external domain knowledge about the organisms.
*   **Combination Tests:** The code `-boppnho` was interpreted as a combination test for *Bordetella pertussis* and *parapertussis*, a common pairing. LOINC's `+` syntax was used to represent this.

# Group 79

This group focused heavily on urine tests, including albumin, protein, their creatinine ratios, and sediment microscopy. 

Key takeaways:
- Prefixes like `cU-` (Collected), `nU-` (Night/Timed), and `U-` (spot) were essential for determining the LOINC System, leading to `in Collected Urine`, `in Timed Urine`, or `in Urine`.
- Many local variations for the same test existed (e.g., `u-alb/kre`, `u-alb/krea`, `u-albkre`). Recognizing these as synonyms for the Albumin/Creatinine ratio was crucial. The units `g/mol` and `mg/mmol` both correspond to the LOINC property `[Mass Ratio]`.
- Garbled test names combining multiple codes (e.g., `u-alb/kre,u-alb`) were a significant challenge. The decile values were indispensable for disambiguation; by comparing the value range to typical ranges for each component, I could infer which test the result actually represented. Without deciles, these would have been ambiguous.
- The `u-sakka` family of codes clearly pointed to urine sediment microscopy. I inferred the method `by Microscopy` and used `[#/area]` as the property for cell counts per field.
- A few codes like `u-alvhu4a` were completely uninterpretable due to non-standard abbreviations and were left empty.
- There were several instances where `p_missing` was 100% but deciles were present. I trusted the deciles over the `p_missing` field, assuming the latter was a data processing artifact.

# Group 84

This group consists entirely of administrative or procedural codes related to specimen collection, not laboratory tests that measure an analyte. The Finnish term 'näytteenotto' (sample collection) and its many abbreviations ('notto', 'n.otto') are the central theme. The lack of numeric values (`p_missing` is ~100%) confirms their nature.

My approach was to map these to LOINC's procedure or 'Ask at Order Entry' (AOE) concepts rather than to standard laboratory test concepts. This means the names do not follow the typical `Component [Property] in System` structure. Instead, they are descriptive phrases like `Specimen collection procedure` or `Specimen collection method`.

Gotchas and ambiguities:
*   Many codes include administrative suffixes (e.g., `-tyks` for a hospital, `-pkl` for a clinic) which needed to be ignored to find the core clinical concept.
*   One code, `ottotapa` (row 6675), had a nonsensical unit ('h') and value distribution. Given its low `unit_share` (1%) and the meaning of the code ('collection method'), I concluded this was data noise and disregarded it.
*   Distinguishing between a procedure (`Specimen collection procedure`) and an observation about that procedure (`Specimen collection method`) was key. 'Notto' (collection) implies the action, while 'ottotapa' (collection method) implies describing the action.

# Group 85

This group presented several challenges. 

1.  **Ambiguous and concatenated codes**: Codes like `-omactgc`, `hpvpapctgc`, and `hpvrefctgc` are difficult to parse. They seem to be local abbreviations, possibly concatenating multiple tests (like CT/GC) or using parts of a method name. My interpretation of `omactgc` as Chlamydia/Gonorrhea is a strong hypothesis, especially with the `u-` prefix (row 6713), but remains a guess.

2.  **Administrative codes**: `annosvoim` (dose strength) and codes like `f-projekti` (project) are not lab tests. It's crucial to identify these and leave them empty rather than forcing a mapping.

3.  **Context from different rows**: Seeing `cladosp.he` with `mm` units (row 6687) and `U/ml` units (row 6688) on separate rows was key to understanding that the same abbreviation was used for two completely different allergy testing methods (skin prick vs. serum IgE). This highlights the importance of not assuming a single mapping for one `TEST_NAME` string.

4.  **Value of `LongName`**: The `LongName` for `ts-abortti` (row 6712), "Dissection study of abortion tissue", was indispensable. Without it, the code would have been unmappable. It allowed translation of a pathology procedure into a LOINC concept, a different type of test from the usual chemistry or microbiology.

5.  **Qualitative vs. Quantitative**: For analytes like `asetoni`, where both qualitative and quantitative tests exist, the absence of units and values (e.g., rows 6702, 6707) makes it a judgment call. I opted for `[Presence]` as a safer guess for a screening-type purpose, given the 100% missing values.

# Group 89

This group was characterized by the suffix `-seul` or `-seula` (from `seulonta`, screening), making it clear that these were all screening tests. The main task was to determine whether a code represented a single-analyte screen (like HPV) or a multi-test panel (like maternal screens or urine chemical screens).

Key takeaways:
- **Panel Recognition**: Finnish codes like `S-Tr1Seul` (1st trimester screen), `U-Kemseul` (urine chemical screen), and `S-ENAScul` (ENA screen) are standard abbreviations for panels. Recognizing these and using the LOINC `Panel name - System` format was crucial.
- **Non-Lab Procedures**: The presence of `hörsel` (hearing screen) and `näköseula` (vision screen) highlights that LOINC covers more than just laboratory tests. These were mapped to simple screen names without properties or systems.
- **Ambiguity**: A code like `hoikemseul` (row 7015) was too garbled to interpret confidently, so leaving the guess empty was the correct action. In contrast, `s-ivfseul` (IVF screen) was specific enough to warrant a targeted panel guess, even if it might map to a more generic infectious disease panel in practice.
- **Interpreting Data**: The decile values for `u-kemseul` (row 7037), which clearly matched urine specific gravity, were an excellent example of how quantitative data can exist for a test that is conceptually a panel. This reinforces the rule to prioritize the test's identity (a chemical screen panel) over the presence of values for one of its components.

# Group 105

This group was challenging due to the pervasive use of panel codes (`B-PVK`, `B-TVK`) to report individual component results. The primary task was to distinguish between an order for a panel and a single result from that panel.

The `unit` and `deciles` columns were critical for this disambiguation. When a row had a specific unit (like `g/l`, `e12/l`, `fl`, `pg`) and a plausible value range, I mapped it to the corresponding component (e.g., Hemoglobin, Erythrocytes, MCV, MCH). When the unit was missing or ambiguous (`%`, `form`), or explicitly a 'package' (`paketti`), I mapped it to the panel concept (`CBC panel`, `CBC with automated differential panel`, etc.).

A significant gotcha was interpreting the different flavors of CBC panels from the Finnish abbreviations:
*   `B-PVK`: Perusverenkuva (Basic blood count). Mapped to `CBC with platelet panel` as platelets are standard.
*   `B-PVK+T`: Explicitly includes trombosyytit (platelets), confirming the above.
*   `B-PVK+TKD`: Includes koneellinen erittelylaskenta (automated differential). Mapped to `CBC with automated differential panel`.
*   `B-TVK`: Täydellinen verenkuva (Complete blood count). Considered synonymous with `B-PVK+TKD`.
*   `B-PVK+TMD`: Minidiffi. Mapped to `CBC with 3 part differential panel`.

The detailed `b-pvk+tkd,[component]` codes were straightforward, clearly indicating a specific result from the differential count. The main task was to choose the correct LOINC property (`[# Ratio]` for `%` and `[#/volume]` for `e9/l`) and component name format (`CellType/Leukocytes` vs. `CellType`).

The many garbled/concatenated codes (`b-pvkt`, `b-pvktkdr`) were handled by parsing the constituent parts and mapping to the corresponding panel.

# Group 106

This group was focused entirely on bacteriology. The Finnish abbreviations (`-vi` for culture, `-vr` for stain, `-lm` for identification, `-he` for sensitivity) were very consistent and helpful. The specimen prefixes were also clear for the most part. The main challenge was differentiating the multiple concepts hiding behind the simple `u-bakt` (urine bacteria) code. Here, the combination of `UNIT` and `deciles` was crucial. It allowed for distinguishing between automated quantitative counts (`e6/l`, `[#/volume]`), microscopic counts (`/sunf`, `[#/area]`), and qualitative/screening tests (`[Presence]`). Similarly, for urine culture (`u-baktvi`), the values showed it was a quantitative culture (`[#/volume]`) rather than just a nominal identification. The `LongName` for the fecal culture panels (`f-baktvi1`, `f-baktvi2`, `f-baktvi3`) was essential for recognizing them as panels targeting specific enteric pathogens. Without the LongName, they would have appeared as simple cultures. This highlights the value of having as much metadata as possible.

# Group 110

This group was overwhelmingly composed of lymphocyte subset analyses (CD markers), which are well-structured in LOINC. The primary challenge was distinguishing between absolute counts ([#/volume] in Blood) and relative counts ([# Ratio] of a parent population). The Finnish prefixes (`B-` for blood vs. `Ly-` for lymphocyte) and the units (`e9/l` vs. `%`) were the key differentiators.

The `la-` prefix was not standard but contextually decipherable as referring to apheresis products, especially given the `e6/kg` unit, which is characteristic of stem cell dosing. This allowed for guessing the `Apheresis product` system.

The `so-` prefix remains ambiguous. I mapped it to the generic `Specimen` system, which is a safe but not very informative choice. If this prefix recurs, it would be valuable to find its meaning.

Two rows (`s-gt-cdt`) appeared to be erroneously grouped by string similarity with the T-cell markers (`t-cd...`). I mapped them based on their own content (Carbohydrate-Deficient Transferrin), ignoring the group's theme. This highlights the importance of evaluating each row independently.

The large number of similar but slightly different local codes for the same concept (e.g., `ly-cd4`, `ly-cd4-t`, `ly-t-cd4`) shows the value of this mapping effort to standardize them to a single LOINC concept.

# Group 111

This group was overwhelmingly about SARS-CoV-2 (COVID-19) testing. The main challenge was differentiating between antigen tests, nucleic acid tests, and antibody tests based on the often-cryptic local codes.

*   **Data Quality**: A significant issue was the presence of numerous nonsensical units for the `-cv19ag` code (rows 9096-9105). These had extremely low record counts and 0% unit share, correctly identifying them as data entry errors. The high `p_missing` on the main entry for this code was key to confirming its qualitative nature, overriding the noise from the bad units.
*   **Interpreting Codes**: The Finnish national coding conventions were crucial. `ag` for antigen, `nh` for nucleic acid, `-o` for qualitative, and `ab` for antibody were reliable guides. Suffixes like `g` (IgG) and `m` (IgM) were also clear. The `LongName` fields, when present, were invaluable, confirming interpretations (e.g., `piikkiproteiini` for Spike protein) or specifying the exact test kit used.
*   **Ambiguities**: For codes like `cv19infrs`, I had to infer a multiplex panel based on the likely components (COVID-19, Influenza, RSV). The name `cldinho` was highly garbled; my interpretation is a low-confidence guess but is better than leaving it blank.
*   **Assumptions**: I consistently assumed `Respiratory specimen` for antigen and NAAT tests where no system was specified. For serology, I used `Serum` or `Serum or Plasma` even when the prefix was `B-` (Blood), as this reflects the typical laboratory matrix. For antibody tests without a specified quantity, I defaulted to `[Units/volume]`, which is a common property for semi-quantitative serology.

# Group 121

This group was dominated by molecular genetics tests, identifiable by the `-D` suffix (DNA test), `LongName` descriptions, and abbreviations for genes (e.g., `APOE`, `JAK2`, `TPMT`) or methods (e.g., `FISH`, `PCR`). The `p_missing=100%` on almost all rows was expected for these kinds of tests, which are typically reported as nominal or qualitative findings, not numbers.

The main challenge was interpreting the local, non-standard abbreviations. For many, like `B-AURIA10` or `B-BO3-D`, there was insufficient information to make a reasonable guess. For others, I had to infer the meaning from common practice, e.g., `B-BLAPCR` as a B-lymphocyte clonality assay, or `BM-MM-IFT` as immunophenotyping for Multiple Myeloma.

The distinction between qualitative (`[Presence]`), identifying (`[Identifier]`), and quantitative (`[# Ratio]`) properties was crucial. `-QR` (quantitative real-time) clearly indicated a quantitative test like `BCR-ABL1`. For genotyping tests (`-tyypitys` in `LongName`) or tests for multiple mutations (`valtamutaatioiden tutkimus`), `[Identifier]` was appropriate. For tests targeting a single, well-known mutation (e.g., Factor V Leiden, JAK2 V617F), `[Presence]` seemed the best fit. I often specified `by Molgen` as a general method for DNA tests, as it's more specific than nothing but not overly presumptive.

Panel names were necessary for codes covering multiple genes (`B-FVFII-D`, `B-VARFA-D`), broad test categories (`B-FARMA-D`, `B-NGS-D`), or multiple stains (`BM-MGGFE`). This requires recognizing when a single code represents a bundle of results.

# Group 126

This group was centered on glucose tests, primarily from glucose tolerance tests (GTT). The naming conventions were quite varied for the same underlying concept. For example, a 2-hour post-challenge glucose was represented by `gluk2h`, `gluk120min`, `glukoosi120min`, `glukr-2h`, `glukr2h`, and `glukras120`. This highlights the necessity of recognizing multiple synonyms for timings (`2h`, `120min`) and for challenge tests (`-r`, `ras`).

The most difficult codes were administrative ones. `glukr1valm` and `glukrvalm` likely mean "glucose challenge preparation" (`valmistelu`). These are not lab results and have no measurable value, so I left their names empty. A process to identify and flag such procedural or administrative codes would be beneficial.

Two codes, `-gluk-tbr` and `-gluk-tir`, were interesting as they represent modern Continuous Glucose Monitoring (CGM) metrics: Time Below Range and Time In Range. Recognizing these newer abbreviations (`TBR`, `TIR`) was key to correctly identifying them as `[Time Fraction]` in `Interstitial fluid`.

The `gluk-vieri` codes were clearly point-of-care tests, which I mapped to `Blood` as the system and `Test strip` as a likely method, which is a common LOINC pattern for such tests.

# Group 129

This group consists entirely of `Pt-` (Patient) prefixed tests, which are procedures, panels, and functional tests rather than specimen-based measurements. This makes naming them as LOINC panels or studies the correct approach.

A significant challenge was the large number of `pt-fvs...` codes (`pt-fvsirod`, `pt-fvspido`, etc.). The `FVS` prefix points to spirometry (`toiminnallinen vitaalikapasiteetti, spirometria`), but the suffixes are non-standard and likely represent local administrative codes for different report types or sub-results. As the goal is to identify the ordered procedure, I've mapped all of these to the general `Spirometry panel`.

Some codes allowed for more specific interpretation. `pt-spirob` was interpreted as `Spirometry with bronchodilator panel` based on `b` for `bronkodilataatio`. The code `pt-sppesu` was interpreted as `Semen analysis panel - Washed semen`, with `pesu` meaning `wash`. The cardiac tests (`pt-syd...`) were decipherable from their components: `perg` (perfusion), `ras` (rasitus/stress), and `uä` (ultraääni/ultrasound).

The code `pt-spiromd` was ambiguous. The `d` could potentially stand for `diffuusio` (diffusion capacity, DLCO), but this is not a standard abbreviation. Given the uncertainty, I opted for the more conservative guess `Spirometry panel`.

# Group 160

This was a very straightforward group. The tests were common liver enzymes: Alanine aminotransferase (ALT), Aspartate aminotransferase (AST), and Gamma-glutamyltransferase (GGT). The Finnish names were clear and unambiguous. The `u/l` unit consistently pointed to the property `[Enzymatic activity/volume]`, which was confirmed by the provided deciles.

The main point of interpretation was handling the various specimen types (`s-`, `p-`, `fs-`, `fp-`, and `plasmasta`). For these routine chemistry analytes, LOINC's standard practice is to use the broad `Serum or Plasma` system. I followed this convention, as specifying Serum or Plasma individually, or including fasting status, would lead to less common LOINC codes that are likely incorrect for general use. All rows, including those without units, were mapped to the most common quantitative form of the test.

# Group 161

This group demonstrated several key challenges. 

Firstly, the prevalence of microbiology nucleic acid tests (NAA) without a specified specimen (e.g., `chlamydiapneumoniae,nukleiin`, `haemophilusinfluenzaenukleii`) required defaulting to the generic `in Specimen`. Access to the original specimen type would significantly improve mapping accuracy. For `ulosteenripulivirukset,nukle` (diarrhea viruses in stool, by NAA), I had to infer a panel concept like `Viral gastroenteritis panel - Stool by NAA`, which is an educated guess based on common clinical practice.

Secondly, the point-of-care glucose tests (`potilasmittari glukoosi`) were interesting. The Finnish terms `ihopisto` (skin prick) and `sensori` (sensor) allowed for a precise distinction between `Capillary blood` (for glucometers) and `Interstitial fluid` (for CGMs). This highlights the importance of understanding both the technology and the local language. One code, `p-omagluk,,potilasmittaringlukoosi`, had a `P-` (Plasma) prefix that contradicted the test name, reinforcing the rule to trust the name's descriptive content over potentially erroneous prefixes.

Finally, distinguishing between absolute counts and ratios was crucial for `suuret värjäytymättömät solut` (Large unstained cells). The `B-` (Blood) prefix pointed to an absolute count (`[#/volume]`), while the `L-` (Leukocyte) prefix with a unit of `%` indicated a ratio, leading to the component `Large unstained cells/Leukocytes`.

# Group 162

This group contained a wide variety of tests, from standard chemistry and hematology to specialized panels and non-lab procedures. The prefixes (`aB`, `vB`, `cB`, `fP`, `fS`) were very helpful in determining the specimen type. Several rows referred to RDW using different Finnish descriptive names (`punasolujen kokojakauma`, `koonvaihtelu`), which was straightforward to normalize.

Several challenges arose:
1.  **Administrative/Procedure Codes**: Rows like `erikoislääkärinkonsultaatio` (specialist consultation) and `pt-vaativainhalaatiohoito` (demanding inhalation therapy) are not laboratory tests and were assigned empty names. `ilmajohtotarv.luujohto` (air vs bone conduction) was interpreted as a hearing evaluation panel, a reasonable guess for a related clinical assessment.
2.  **Ambiguous Test Names**: For `punasolujenerittelylaskenta` (RBC differential), the name suggests morphology (`[Interpretation]`), but the unit (`%`) and values were consistent with RDW (`[Ratio]`). I prioritized the test name (`erittelylaskenta` = differential/manual count) over the quantitative data, as instructed, but this is a significant ambiguity.
3.  **Proprietary/Panel Names**: `s-nightingale-mittaus` and `fras,oksidatiivinenstressi` refer to specific platforms or test concepts. I created broad panel names (`Metabolites panel`, `Free radicals`) to target the right area in LOINC. Similarly, various `tth-paketti` (occupational health package) codes were mapped to a generic panel name.
4.  **Non-standard Prefixes**: `zB-` (row 13176) is not a standard prefix. I inferred it as 'central blood' (`sentraaliveri`), which is a plausible guess but unconfirmed. Access to a more comprehensive list of local prefix conventions would be beneficial.

# Group 167

This group consisted of two well-defined sets of tests: components of a complete blood count with differential, and fractions from a serum protein electrophoresis. The Finnish term `osatutkimus` (sub-study/component test) was a key clue that these were individual results from larger panels.

For the hematology tests, I distinguished between absolute counts (e.g., `B-Neut`, `absol.arvot`, unit `E9/l`) and relative differential counts (e.g., `L-Neut`, unit `%`). I translated absolute counts to `[#/volume]` property and relative counts to `[# Ratio]` with a `Component/Leukocytes` structure. The term `konediffi` (machine differential) provided strong evidence to add `by Automated count` to the method.

For the protein fractions, the context `s-prot-fr` strongly implied the results were from electrophoresis. I therefore added `by Electrophoresis` to the method for all these components (albumin, globulin fractions, M-components). The unit `g/l` consistently pointed to `[Mass/volume]` property. The `M-komponentti-1`, `-2`, `-3` codes were straightforwardly mapped to `Monoclonal protein 1`, `2`, `3`, which exist as distinct concepts in LOINC.

