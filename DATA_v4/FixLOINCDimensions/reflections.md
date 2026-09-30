# Group 7

This group was straightforward, focusing on tissue transglutaminase IgA and IgG antibodies. The Finnish names were clear, breaking down into `kudostransglutaminaasi` (tissue transglutaminase) and the specific immunoglobulin class (`iga-vasta-aineet` or `igg-vasta-aineet`). The candidate list was excellent, providing the preferred top-2000 LOINC codes which include the method (`by Immunoassay`), which is standard for these tests. The unit `eliau/ml` in row 12 provided strong confirmation for choosing the immunoassay-specific concept. Most rows could be mapped with high or medium certainty. Rows without units were mapped with medium certainty by assuming they followed the standard quantitative measurement. The only unmappable rows were 21 and 22, where the test name `s-transglutaminaasivasta-aineet` was ambiguous, not specifying the Ig class, and the candidate list lacked a concept for 'total' or 'unspecified' transglutaminase antibodies.

# Group 14

This group was entirely about C-reactive protein (CRP) and its variations. The mapping was mostly straightforward, distinguishing between standard lab tests, high-sensitivity tests, and rapid/point-of-care tests. The key Finnish terms were `herkkä` (sensitive), and a cluster of terms for rapid/POC tests: `pika`, `pikatesti`, `vieritesti`, `vieritutkimus`, `hoitoyksikkö`, `pikamittari`. The candidate list was excellent, providing distinct concepts for these different test types.

I developed a consistent strategy:
1.  **Standard CRP**: Mapped to `3020460` (CRP [Mass/vol] in S/P). This was the default and is a Top 2000 concept.
2.  **High-sensitivity CRP**: Mapped to `3010156` (CRP [Mass/vol] in S/P by High sensitivity). The term `herkkä` and low decile values were clear indicators.
3.  **Rapid/POC CRP**: Mapped to `1469985` (CRP [Mass/vol] in S/P/B by Rapid immunoassay). The various Finnish terms for rapid/POC tests were the main evidence. The deciles often showed a characteristic floor around 5 mg/L, supporting this choice. The broader specimen `Serum, Plasma or Blood` was appropriate as POC tests can use different sample types.
4.  **Capillary CRP**: Mapped to `3051387` (CRP [Mass/vol] in Capillary blood). The `cp-` prefix and the term `ihopiston` (skin prick) were definitive.

Some minor challenges:
- The `B-` (Blood) prefix for a standard lab test was slightly ambiguous. I chose to map it to the standard `Serum or Plasma` concept (`3020460`), assuming `B-` refers to the collected sample and not the analyzed matrix, which is standard practice for CRP. This seemed more plausible than choosing a less common, non-Top2000 concept for 'Serum, Plasma or Blood'.
- Some names included hints of qualitative testing (`kval`, `osoitus`) but were paired with quantitative units and values. I consistently prioritized the quantitative data, as it is stronger evidence.
- One row (94) had deciles that conflicted with its name ('pika'), but given the low sample count and high missingness, I trusted the name.

# Group 20

This group was a mix of EKG procedures and microbiology NAA tests. Mapping was straightforward for most rows.

**Successes:**
*   The numerous variations of '12 lead EKG' were all confidently mapped to the single `12 lead EKG panel` concept (3044889), correctly identifying the local variations as contextual details rather than different tests.
*   The microbiology tests with explicit specimen prefixes (`F-`, `Li-`) and method suffixes (`-nho`, `-nukl.haponos`) were a perfect fit for specific LOINC concepts for NAA tests in Stool or CSF.

**Challenges:**
*   Rows 147 and 148 (`pt-ekg,eteisvärinänseulonta...`) were too specific for the available candidates. The Finnish name clearly indicates 'atrial fibrillation screening via monitor EKG', and no candidate captured this. A concept like `Atrial fibrillation [Interpretation] by EKG.monitor` was guessed by the previous step but was not in the candidate list, indicating a potential search failure or vocabulary gap.
*   Rows without an explicit method (109, 119, 154) were difficult. I mapped row 109 (EHEC) to a Shiga Toxin Immunoassay concept as a plausible non-NAA alternative, but left rows 119 (ETEC) and 154 (Shigella/EIEC) unmapped because no good non-NAA alternative was present. The fact that the coding system has specific codes for NAA tests strengthens the case that these method-agnostic codes are for something else (e.g., culture, immunoassay) or are umbrella codes. Without better candidates, leaving them unmapped is the safest option.

# Group 21

This group contained two distinct analytes: Transferrin iron saturation and Soluble transferrin receptor. The Finnish names (`transferriininrautakyllästeisyys`, `transferriinireseptori`) were clear, and the candidate list provided excellent matches. For saturation, `3009814` (Iron saturation [Molar fraction] in Serum or Plasma) was the correct choice, supported by `%` units or fractional deciles, and its status as a top-2000 code. For the receptor, `3015399` (Transferrin receptor.soluble [Mass/volume] in Serum or Plasma) was correct, confirmed by `mg/l` units and the presence of `liukoinen` (soluble) in many names. Most rows could be mapped with high certainty. Rows without values or units were mapped with lower certainty. One row (171) had a UNIT of `paketti` (package) and was correctly left unmapped as it represents a test order, not a result.

# Group 33

This group contained three main types of tests: MRSA cultures, drug screening panels, and Holter EKG studies. 

The MRSA cultures were straightforward to map, with specific LOINC concepts available for Nose and Pharynx (Throat), and a general 'Specimen' concept for unspecified sites or sites like Perineum for which no specific LOINC was in the candidate list. Using the general 'Specimen' concept is a safe and correct approach in these cases.

The EKG studies for 24h or 48h long-term recording were well-described by the Finnish names and mapped clearly to the 'Ambulatory cardiac rhythm monitor (Holter) study' concept, which correctly represents the procedure without specifying the duration.

The drug panels were slightly more complex. A 5-drug panel mapped perfectly to a specific LOINC concept. However, several rows described a 6-drug panel (including Buprenorphine), for which no exact match was available in the candidates. I mapped these to a more generic 'Drugs of abuse panel' concept, which is a reasonable solution, though less precise.

One row (187) for a complex genetic test looking for both sequence variants and copy number variants by NGS could not be mapped, as no single candidate concept captured this specific combination of analyses. Leaving this unmapped was the correct action to avoid an inaccurate mapping.

# Group 34

This group was straightforward to map. The Finnish laboratory codes were highly descriptive, clearly distinguishing between *S. pyogenes* (group A), *S. agalactiae* (group B), and general beta-hemolytic streptococci. The methods were also explicitly stated: `viljely` (culture), `antigeeni` (antigen), and `nukleiinihaponosoitus` (nucleic acid detection). Specimen information was available either via prefixes (`Ps-` for throat, `fl-` for vaginal) or spelled out (`nielusta` for throat). When a specimen was not specified, I correctly used the generic 'Specimen' concepts. Qualifiers like `vieritesti` (point-of-care) were also present and mappable to 'Rapid immunoassay'. The candidate list was excellent and contained all the necessary specific and generic concepts to make accurate mappings.

# Group 37

This group contained a wide variety of tests, from routine chemistry and hematology to microbiology, pathology, and complex panels. Many codes were for point-of-care ('vieritesti') or automated system sub-components ('osatutk.').

**Successful Mappings:** Most standard analytes (glucose, creatinine, electrolytes, blood gases, CBC, urine dipstick components) were mapped with high certainty. The Finnish names were generally descriptive, and the presence of units and values was very helpful. POC test concepts were well-represented, allowing for more specific mappings (e.g., CRP by rapid immunoassay, INR in capillary blood).

**Challenges and Unmapped Rows:**
- **Administrative/Billing Codes:** Several rows (e.g., 226-229, 264-266, 279, 299, 321) were clearly administrative and unmappable.
- **Missing Ratio Concepts:** Percentage-based flow cytometry results (NK cells % in row 286, T-helper cells % in row 313) could not be mapped because the candidates only included absolute counts ([#/volume]). This is a significant gap. I could map CD8% (row 314) because a candidate with the `Cells` property (implying a ratio) was available.
- **Vague/Generic vs. Specific Concepts:** A generic MRD analysis (row 240) couldn't be mapped as all candidates were disease-specific. Similarly, a generic 'resistant' bacteria culture (rows 232, 306) was too vague. Conversely, some local codes were for panels not present in the candidate list (e.g., Yersinia multiplex panel row 338, drug enantiomer panel row 323).
- **Pathology/Procedure Codes:** Codes for histological preparation (row 222) and complex procedural descriptions (e.g., sleep studies, PEF diurnal variation) often lacked corresponding observational or panel concepts in the LOINC list provided.

The `loinc_name_guess` was generally very accurate and a good starting point, but the candidate list was the limiting factor in several cases. For flow cytometry percentages, a broader search retrieving ratio concepts would be necessary.

# Group 42

This was a very large group with a wide variety of tests, though sodium (`Na`) was the most frequent. The mapping was mostly straightforward due to the systematic Finnish naming convention (`<specimen>-<analyte>`) and the availability of units and value distributions.

Most `S-` (serum) and `P-` (plasma) codes could be confidently mapped to LOINC's `Serum or Plasma` concepts. Similarly, `B-` (blood), `dU-` (24h urine), `U-` (urine), and `Pf-` (pleural fluid) had direct LOINC equivalents.

Several codes could not be mapped:
- `p-ked.` and `p-kjd.` (rows 395, 396) and `pneag` (454) were completely uninterpretable abbreviations.
- Lupus anticoagulant tests `p-la1` (screen) and `p-la2` (confirm) were problematic. The candidate list lacked generic concepts for screening and confirmation results reported in seconds; it only offered specific neutralization tests, making an accurate mapping impossible.
- `p-fs` (row 380) was too ambiguous without supporting data.
- `pef-pa` (row 448) describes a monitoring protocol rather than a single measurable result, and no suitable panel/protocol concept was available.

The candidate list was generally very good and comprehensive for this diverse set of analytes.

# Group 43

This group contained a wide variety of tests, many of which were clearly identifiable by their abbreviations (e.g., `s-hcg`, `s-dheas`, `li-tpha`) and could be mapped with high certainty, especially when units and values were present to confirm the property. 

Several rows could not be mapped. The primary reasons were:
1.  **Missing candidates:** Some tests, like Erythropoietin in Amniotic fluid (`am-epo`), VASP (`b-vasp`), and Tumor-associated trypsin inhibitor (`s-tati`), had no corresponding concepts in the candidate list. This is a search issue.
2.  **Ambiguous local codes:** Codes like `fs-apot`, `p-hae`, `s-hbe`, and the `fs-tp-[n]` series were too generic or non-standard to be identified with any certainty.
3.  **Property mismatch:** Platelet aggregation tests (`b-adp`, `b-aspi`) had a unit of `auc` (Area Under Curve), but no candidate LOINC concepts with this property were available. Similarly, `s-ena` had quantitative values suggesting a ratio, but only panel/presence/units candidates were present.

Most of the core chemistry and endocrinology tests were straightforward. The distinction between Mass, Moles, and Units properties was critical and generally well-supported by the provided units. For hCG in urine without a unit, mapping to the qualitative `[Presence]` concept was the most logical choice given its common use as a pregnancy screen.

# Group 44

This group contained a wide variety of tests, from common chemistry (Bilirubin, Cholesterol, TSH) to toxicology (heavy metals, drugs of abuse) and urinalysis. The mappings were generally straightforward where units and values were provided.

**Successes:**
- Most common analytes like Bilirubin, Cholesterol, Magnesium, TSH, FSH, and BNP were easily mapped using the combination of name, specimen prefix, and unit/values. The `Serum or Plasma` concepts worked well for `S-`, `P-`, `fS-`, and `fP-` prefixes.
- Urine drug screens (`u-amp`, `u-bup`, `u-bzd`, etc.) were clearly identifiable as `[Presence]` tests and mapped correctly.
- Urinalysis components like `u-sed` (sediment panel), `u-sg` (specific gravity), and `u-ph` were also mapped with high confidence.

**Challenges & Unmapped Rows:**
- **Missing quantity information:** A large number of rows could not be mapped because they lacked a unit or value distribution (`evidence_level` = `name`). This prevents choosing between properties like `[Mass/volume]`, `[Moles/volume]`, or `[Presence]`.
- **Uninterpretable codes:** The `u-ds...` series of codes were completely unidentifiable and could not be mapped.
- **Unknown analytes:** The code `p-fsl` seems to refer to a proprietary coagulation test for which no standard LOINC exists in the candidate list. `u-kivi` (stone analysis) is a panel, but no matching panel concept was available.
- **Missing candidates:** The tests for 1-Hydroxypyrene (`u-pyr`), Biotin in CSF (`li-bio`), and MMSE (`mmse`) could not be mapped because the correct concepts were not retrieved in the candidate list.

# Group 51

This group was dominated by infectious disease serology and antigen tests, mostly for respiratory and gastrointestinal pathogens, plus some therapeutic drug monitoring (Infliximab, Mycophenolate). Mapping was generally straightforward when the analyte, specimen, and property were all clearly specified.

Several rows could not be mapped due to gaps in the candidate list:
*   **Panel codes:** Several local codes for respiratory antigen panels (e.g., `-inabrsv`, `-infrpak`, `-rvirag`) and enteric virus panels (`f-virag`) had no corresponding generic panel concepts in the candidate list. The available panels were either for RNA or for different combinations of pathogens.
*   **CSF serology:** A significant number of tests for antibodies in cerebrospinal fluid (`Li-` prefix) could not be mapped because the specific analyte-isotype combination (e.g., Adenovirus IgG, Influenza A/B IgG) was missing for the CSF specimen.
*   **Ratio properties:** Rows for Mycoplasma pneumoniae IgM antibodies (793-795) were reported with units `index` and `s/co`, clearly indicating a ratio. No `[Ratio]` concept was available in the candidates, preventing a correct mapping.
*   **Missing specific components:** Tests for specific Influenza A subtypes (H1, H3) as antigen tests on primary specimens were unmappable as candidates were for RNA or on isolates.
*   **Vague codes:** A few codes like `bi-inflamm` (inflammatory marker in bile) and `-ivf-et` (a procedure) were unmappable by nature.

The `loinc_name_guess` was generally helpful in pointing to the right area, but the final decision always relied on dissecting the Finnish code and data, which often led to choosing a different, more precise, or more generic concept, or leaving the row unmapped.

# Group 68

This group contained a variety of common analytes like amylase, alkaline phosphatase, albumin, and aldosterone, with different specimens (serum, plasma, urine, pleural fluid, etc.) and properties. Most were straightforward to map. 

The main challenges were:
1.  **Ambiguous qualifiers**: Codes like `s-aaldos`, `s-oaldos`, and `s-valdos` had prefixes ('a', 'o', 'v') whose meanings were unclear, but the associated values were dramatically different from baseline, suggesting post-challenge states. I mapped `s-aaldos` to a generic post-challenge concept with medium certainty but left the others unmapped due to the extreme and implausible values.
2.  **Underspecified components**: `s-gliade` (deamidated gliadin) didn't specify IgA or IgG, and no generic concept was available. `s-allige` (allergen IgE) was generic, and I chose a 'Miscellaneous allergen' concept as a placeholder.
3.  **Uninterpretable codes**: `s-kalatue`, `s-ngmuut`, and `sp-suld` were unmappable due to unrecognizable component names.
4.  **Missing quantity information**: As usual, rows without units or values could not be mapped if multiple properties (e.g., mass vs. moles, or absolute value vs. ratio) existed for the same test code.
5.  **Missing candidates**: There was no candidate for Amylase in Pancreatic juice (`pa-amyl`).

# Group 70

This group was large and contained a mix of well-defined tests, ambiguous codes, and administrative codes. The well-defined codes, especially for therapeutic drug monitoring (carbamazepine, valproate), allergens (nuts, pollen), and common chemistry (bile acids, calprotectin, ALP isoenzymes), were generally straightforward to map, aided by clear prefixes (`S-`, `F-`), units, and `LongName`s.

Several challenges arose:
1.  **Missing candidates:** The candidate list was missing concepts for Beta-carotene (`fs-bkarot`), Macro-alkaline phosphatase (`s-afmakro`), and Parvovirus avidity (`s-parvavi`), preventing mapping for these rows.
2.  **Ambiguous local codes:** Codes like `b-nakkrea`, `p-varmtr`, and `p-varmtt` were difficult to interpret. While `p-varmtt` was mapped to a Thrombin time ratio based on the unit `%` and a likely pairing with the `p-varmtr` (time) code, this was a medium-certainty decision. The others were unmappable.
3.  **Administrative codes:** Many codes (`b-vara`, `s-pakast*`, etc.) clearly referred to sample handling (spare, frozen) rather than a specific test and were correctly left unmapped.
4.  **Property ambiguity:** For many codes, especially when a unit or values were missing (`name` evidence level), it was impossible to determine the property (e.g., Moles/volume vs Mass/volume, Titer vs Units/volume), forcing a 'no map' decision to avoid guessing.
5.  **Panel vs. Component:** Codes like `s-maksa` (liver) or `u-gluprot` (glucose-protein) were correctly identified as panels. `du-parprot` (paraprotein in 24h urine) was mapped to a protein electrophoresis panel, which is the procedure to identify it.

The presence of both `s-afmaksa` as a ratio (`%`) and as an absolute activity (`u/l`) was interesting, highlighting the importance of checking the unit for every single row, even with identical test names.

# Group 73

This group consisted of nucleic acid amplification tests (NAA/PCR) for various respiratory pathogens. The Finnish codes were highly systematic, with the `-nho` suffix consistently indicating a qualitative nucleic acid test. Many codes had `LongName`s that confirmed the interpretation.

The main challenge was selecting the appropriate specimen type. Since the codes did not specify the specimen, I chose the general `Respiratory system specimen` where available, as this is the most appropriate default for these pathogens. In a few cases (e.g., `-inabrsnho` panel, `-pinfnho`), a concept with this specimen was not in the candidate list, so I opted for the more generic `Specimen` to avoid making an unsubstantiated choice like `Upper` or `Lower` respiratory. 

One code, `-tintnho`, was unmappable as the abbreviation 'tint' is unknown. Most mappings were high confidence because the qualitative nature of the test (`[Presence]`) meant the lack of numeric values was not a barrier, and the Finnish codes were very clear.

# Group 74

This group consisted entirely of qualitative nucleic acid amplification tests, identifiable by the `-nho` suffix. Most local codes were clear and had direct mappings in the candidate list, especially for specific pathogens with an unspecified specimen, or with a common specimen like Serum or Stool. The coronavirus tests (229E, HKU1, NL63, OC43) were particularly straightforward.

The main difficulty was the absence of certain concepts in the candidate list. Specifically, several general tests for 'Bacteria' combined with specific specimens (Respiratory, Stool, CSF) could not be mapped (rows 1144, 1149, 1157, 1158). Similarly, a concept for Sapovirus in Stool was missing (row 1152), and a combined Bordetella pertussis+parapertussis concept was absent (row 1141), forcing a fallback to a less specific `Bordetella sp` concept. This suggests the search for candidates might be improved by including more combinations of common analytes and common specimens, even if they don't exactly match the initial `loinc_name_guess`.

# Group 79

This group was mostly about urine chemistry, particularly albumin, creatinine, and their ratios, along with urine sediment microscopy. The mappings were generally straightforward.

The main challenge was deciding between `Albumin/Creatinine` and `Microalbumin/Creatinine` concepts for the various `u-albkre` codes. The Finnish codes themselves don't distinguish, but the test is clinically for microalbuminuria. I decided to standardize on the LOINC Top 2000 concept `3001802 (Microalbumin/Creatinine [Mass Ratio] in Urine)` for all quantitative ratios, as this seems to be the recommended practice for this common test, promoting consistency over a literal interpretation of the absence of 'micro' in the source code.

Timed collections (`cU-`, `nU-`) were handled by selecting specific LOINC concepts where available (e.g., `12 hour Urine` for `nU-`).

The urine sediment (`U-sakka`) codes were very clear and mapped well to the standard Top 2000 LOINC concepts for microscopy findings (bacteria, erythrocytes, leukocytes, casts). The code `u-sakka,muuta` (other findings) was mapped to the generic `Microscopic observation` concept.

A few codes (`u-alvhu...`) were uninterpretable gibberish and were left unmapped. Rows without sufficient evidence for the property (e.g., a ratio test with no unit or values) were also correctly left unmapped.

# Group 84

This group primarily consists of Finnish codes for procedures and services related to specimen handling, such as `näytteenotto` (specimen collection), `näytteen käsittely` (processing), and `näytteen kuljetus` (transport). These are procedural codes, likely for ordering or billing.

The major challenge was that the candidate list was almost entirely populated with observational or descriptive concepts (e.g., 'Collection method', 'procedure comment', 'supervision level'), while a core concept for 'Specimen collection procedure' was missing. This resulted in a large number of unmappable rows, as mapping a procedural code to a descriptive attribute would be incorrect.

I could successfully map the codes that were inherently descriptive: `ottotapa` (collection method), `u-ottotapa` (urine collection method), and `valv.notto` (supervised collection, which maps well to 'supervision level'). For the rest, the gap between the procedural nature of the source codes and the descriptive nature of the candidates was too large to bridge.

# Group 85

This group contained a mix of microbiology, chemistry, and allergy tests, plus some unmappable administrative or pathology codes. Most mappings were straightforward, with clear evidence from the local code's prefix (specimen), name (analyte), and unit/values (property). For example, `b-koboltti` in `ug/l` was a clear match for Cobalt [Mass/volume] in Blood. Microbiology codes for specific pathogens (Coronaviruses, Noroviruses) were also clear matches. 

The main challenges were:
1.  **Ambiguous local codes**: `hpvpapctgc` and `hpvrefctgc` seem to represent local bundles of tests for which no single LOINC concept exists. These were left unmapped.
2.  **Non-test codes**: `annosvoim` (dose strength) and `projekti` (project) were correctly identified as non-laboratory results and left unmapped.
3.  **Lack of specific candidates**: For `ts-abortti` (gross examination of abortion tissue), the candidates were generic pathology terms. `Pathology report gross observation Narrative` was chosen as a best-fit, but it lacks the specimen information, hence the 'low' certainty.
4.  **Quantitative vs. Qualitative**: For codes like `p-asetoni` that appeared both with and without units, I made a judgment call. For acetone, a qualitative screen is common, so I mapped the unit-less version to a `[Presence]` concept. For standard chemistries like `uraatti` and `valproaatti`, I mapped the unit-less versions to the same quantitative concept as their counterparts, assuming missing data rather than a different test type.

# Group 89

This group consisted almost entirely of screening panels (`seul`, `seula`). The mappings were generally straightforward when a clear match was present in the candidates, such as for urinalysis (`u-kemseul`), first-trimester maternal screens (`s-tr1seul`), and ENA screens (`s-enaseul`).

The main challenges were:
1.  **Missing candidates**: The correct concepts for an Rh(D) antibody screen (`rhdnegseul`) and a generic second-trimester maternal screen (`s-tr2seul`) were not in the candidate list. The list for the latter only contained specific triple/quad/penta panels, which were too specific for the generic Finnish code.
2.  **Ambiguous local codes**: One code (`hoikemseul`) was too truncated to interpret.
3.  **Generic-to-specific mapping**: For generic screening codes like `luov.seul.` (donor screen) and `s-ivfseul` (IVF screen), I had to map to a plausible panel (`Sexually transmitted blood borne infections panel`), which is an interpretation but likely correct in practice. The certainty for these is lower. Similarly, the generic 'mother screen' codes (`äit-seul`) were mapped to a general maternal screen panel.

# Group 105

This large group centered on Finnish blood count panels (`PVK` and `TVK`) was mostly straightforward to map. The key was to distinguish between panel orders and results for individual components of those panels. The `LongName`, `TEST_NAME` structure, units, and decile values were crucial for this.

`B-PVK` and its variants (`B-PVK+T`, `B-PVKT`) were mapped to the general `CBC panel - Blood by Automated count` (40761511), as this corresponds to a basic blood count without differential, which is the definition of `Perusverenkuva`.
`B-TVK` and `B-PVK+TKD` were mapped to `CBC W Auto Differential panel - Blood` (40760140), as these codes (`Täydellinen verenkuva` and `...koneellinen erittelylaskenta`) explicitly call for a differential count.

Rows with specific units and values were mapped to the corresponding component concepts (e.g., Hemoglobin, Leukocytes, MCV, etc.). The highly structured nature of the `b-pvk+tkd,*` codes made this part very clear.

Several rows could not be mapped because they requested panel combinations for which the correct LOINC panel concept was not available in the candidate list. These were primarily panels including reticulocytes (`+r`) or a 3-part differential (`+tmd`). Specifically, panels for CBC+retics, CBC+diff+retics, and CBC+3-part-diff were missing. Forcing these to a more generic panel would lose important information, so leaving them unmapped was the correct choice.

A few rows were left unmapped due to ambiguity in the local code (e.g., `b-pvk+ner`, `b-pvk+tmdl`) or because the evidence was insufficient to distinguish between multiple possible components (e.g., `b-pvk+tkd` with unit `e9/l` but no values).

# Group 106

This group covered bacterial tests, primarily cultures (`-vi`), stains (`-vr`), and identifications (`-lm`). Mapping was successful for standard tests where the Finnish code's prefix (specimen) and suffix (method) aligned with a specific LOINC concept. For example, `Li-baktvi` (CSF culture) and `fl-baktvr` (vaginal fluid gram stain) were clear matches.

The main challenges were:
1.  **Lab process codes**: 'Subculture' (`-jvi`) codes (e.g., 1404, 1451) were unmappable as they represent an internal workflow step, not a reportable result.
2.  **Missing candidates**: The candidate list lacked generic concepts for `Bacteria identified in Specimen by Stain`, preventing mapping of codes like `-baktvr` (1400) and `ex-baktvr` (1417). Similarly, codes for 'special culture' (`u-baktevi`, 1450) or specific panels (`f-baktvi2`, 1420) did not have corresponding candidates.
3.  **Ambiguity in `U-Bakt`**: The many variants of urine bacteria tests required careful use of `UNIT` and `deciles` to distinguish quantitative automated counts (`#/volume`), microscopy (`#/area`), and qualitative screening (`Presence`). Mapping screening tests (`u-bakts`) to 'Nitrite [Presence]' was a necessary interpretation.
4.  **Panel mapping**: Stool culture panels (`f-baktvi1`, `f-baktvi3`) were mapped to a general 'Gastrointestinal pathogens panel' as a best-fit compromise, losing some specificity from the `LongName`.

# Group 110

This group consisted primarily of immunophenotyping codes (CD markers). The mapping was generally straightforward. The main division was between absolute counts (`B-` prefix, units `e6/l` or `e9/l`) and relative counts/ratios (`Ly-` prefix, unit `%`). 

**Successes:**
*   Absolute counts in blood (e.g., `B-CD3`, `B-CD4`, `B-CD19`) were easily mapped to their `[#/volume] in Blood` LOINC equivalents. The `top2000` concepts for CD4 and CD8 (`CD3+CD4+` and `CD3+CD8+`) were correctly identified as the standard targets.
*   CD4/CD8 ratios in blood were also clearly identifiable and mapped to the correct `top2000` concept.
*   The `La-` prefix was correctly identified as referring to leukapheresis products ('Blood product unit' in LOINC), allowing for mapping of CD34 counts in that context.
*   The `Ly-` prefix was correctly interpreted as a ratio with lymphocytes as the denominator.

**Challenges:**
*   **Missing specific concepts:** The candidate list lacked specific concepts for CD4 and CD8 counts in apheresis products (`la-t-cd4`, `la-t-cd8`), forcing these to be left unmapped. Similarly, concepts for `CD4-CD8-` cells were missing.
*   **Ambiguous denominators:** For relative counts (`Ly-` prefix), the LOINC concepts sometimes use `/cells` as a denominator where the Finnish code implies `/Lymphocytes`. This is a common ambiguity in flow cytometry reporting (is 'cells' the whole population or the gated lymphocyte population?). I mapped them based on the best fit and `top2000` status but with medium certainty (e.g., `ly-cd16/56`).
*   **Ambiguous specimen prefixes:** The `So-` prefix was unknown, forcing a fallback to the generic `Specimen` system, which is less precise. The low value ranges for these rows compared to blood supported the decision not to map to blood concepts.
*   For `ly-cd4 %` and `ly-cd8 %`, the best available candidates were in `Specimen` rather than `Blood`. While `Specimen` is a valid supertype, a concept with `in Blood` would have been a better match. This seems like a gap in the search retrieval.

# Group 111

This group was dominated by COVID-19 related tests. Most were clearly identifiable from the test code abbreviations (`ag`, `nho`, `abg`, `pika`, `sekv`). A significant number of rows represented rapid antigen tests, including both generic codes and codes specific to test kits. A single LOINC concept (`36033641`) for rapid antigen tests in upper respiratory specimens was a good fit for all of them. The antibody tests were also straightforward to map, with clear distinctions for IgA, IgG, IgM, and total antibodies based on the Finnish codes.

Two main challenges arose from gaps in the candidate list:
1.  **C1q IgG Antibodies (`p-c1qabg`)**: The candidate list only had a concept for total C1q antibodies, not the IgG-specific one required by the code. The mapping was left empty.
2.  **Spike Protein Antibodies (`s-cv19sab`)**: The code specifies antibodies to the Spike protein, and the data clearly shows it's a quantitative test. The candidate list did not contain a suitable concept for *total* quantitative S-protein antibodies; the available options were for a specific subclass (IgG) or property (`[Presence]`). These rows also had to be left unmapped.

A few codes with uninterpretable suffixes (e.g., `-c19agvt`, `-covidjt`) were too ambiguous to map confidently.

The rows for `-cv19ag` with various quantitative units (1566-1575) were clear cases of data error (0% unit share, very low `n`), and were mapped based on the primary, qualitative use of the code seen in the main row (1576).

# Group 121

This group was dominated by molecular genetics and cytogenetics tests. Mapping was successful for codes where the gene name was clear (e.g., `b-jak2-d`, `b-apoe-d`, `b-fv-d`) and a corresponding LOINC concept was available. 

Several challenges arose:
1.  **Ambiguous/Generic Codes**: Many codes were unmappable because they were too generic (e.g., `-fishhyb`, `b-fuus-mr`, `bm-mrd-vs`). These codes specify a method or a broad category without naming the specific analyte or panel, making a precise mapping impossible.
2.  **Missing Candidates**: Some clearly identifiable tests could not be mapped because the correct LOINC concept was absent from the candidate list. This happened for `b-atrytyd` (Alpha-1-antitrypsin genotyping), `b-fii-d` (Prothrombin gene mutation), and several panels like `bm-mggfe` (MGG + Iron stain) and `bl-bal-1` (BAL cell differential). This suggests the initial search query, while good, could not retrieve all necessary concepts.
3.  **Panel Ambiguity**: Codes for panels were difficult. For example, `bm-fishhem` (hematologic FISH) could refer to multiple different panels (AML, MDS, etc.), and no general "hematologic FISH panel" concept was available to match the code's level of abstraction.
4.  **Local/Administrative Codes**: Some codes like `-ctr-d` (control) and `b-finngen` (FinnGen project) are clearly not standard clinical tests and are correctly left unmapped.

# Group 126

This group was dominated by glucose tests, primarily from glucose tolerance tests (GTTs). The local codes consistently used suffixes like `0`, `1h`, `120min`, `r0`, `ras-0` to denote time points, which were straightforward to map to the corresponding LOINC 'post dose' or 'baseline' concepts. A key decision was to use the generic 'post dose' concepts because the local codes did not specify the glucose load (e.g., 75g or 100g). The `gluk-vieri` code was interpreted as a point-of-care test and mapped to a more specific 'Capillary blood by Glucometer' concept. Two continuous glucose monitoring (CGM) codes were present; 'Time Below Range' (`-gluk-tbr`) was mapped successfully, but 'Time In Range' (`-gluk-tir`) could not be mapped as the candidate list lacked a concept for this single measure, offering only a panel. Lastly, two codes (`glukr1valm`, `glukrvalm`) were identified as administrative and left unmapped.

# Group 129

This group consisted primarily of patient-level (`Pt-`) investigation codes, which are orders for panels or procedures. The mappings were generally successful where a suitable panel or study concept was available. 

**Successes:** Most spirometry, semen analysis, and cardiac imaging codes (`echocardiography`, `stress echo`, `stress study`) found good matches in the candidate list. The Finnish abbreviations like `syd` (heart), `ras` (stress), `uä` (ultrasound), `sper` (semen), and `fvs`/`spiro` (spirometry) were quite clear.

**Challenges & Gaps:**
*   **Specificity:** For `pt-sper-1/2/3`, which represent different levels of semen analysis ('limited', 'extensive'), a single general `Semen analysis panel` had to be used. Similarly, for spirometry with a bronchodilator (`pt-spirob`), a specific panel was not available, forcing a mapping to the general `Spirometry panel`. These are acceptable generalizations but lose some detail.
*   **Missing Concepts:** Several codes could not be mapped because the candidate list lacked a suitable concept. `pt-st-temp` (Thermal sensory threshold test), `pt-sydperg`, and `pt-sydperq` (Myocardial perfusion study) are clear examples where the local code is identifiable, but the search did not return the correct LOINC panel/procedure. A future search should specifically look for panels related to 'thermal sensory testing' and 'myocardial perfusion study'.

# Group 160

This was a straightforward group of common liver function tests: ALT, AST, and GGT. The local names were clear, and the candidate list contained the three correct LOINC concepts, all of which were on the top-2000 list. The mapping was unambiguous for all rows.

The main distinction was between rows with full evidence (unit and/or values) and those with only the test name. For the latter, I assigned a 'medium' certainty as per the instructions, since the property (`[Enzymatic activity/volume]`) had to be inferred. However, for these specific analytes, this property is so standard that the inference is very safe. The specimen was either explicitly stated via a prefix (`P-`, `S-`, `fP-`, `fS-`) or a word (`plasmasta`), or could be safely assumed to be Serum/Plasma as is standard.

# Group 161

This group was mostly straightforward, with clear mappings for hormones, fatty acids, microbiology NAA tests, and glucose measurements. 

Several rows could not be mapped due to shortcomings in the candidate list. All rows for Phosphatidylethanol (`B-fosfatidyylietanoli` and variants) were reported in `umol/l`, indicating a molar concentration. The candidate list only contained a concept for mass concentration (`44816559`). The correct concept, `Phosphatidylethanol [Moles/volume] in Blood` (OMOP 43530861), was missing. 

Similarly, `s-c-peptidi1haterianjälkeen` (row 1827) clearly specifies a C-peptide measurement 1 hour after a meal. The candidate list lacked this specific timing, offering only a generic post-meal concept or a post-glucose challenge concept, leading to an unmapped row.

For glucose tolerance tests where the dose was unspecified (`p-glukoosi,toimintakokeissa...`), I used the more generic `...post dose glucose` concepts, which felt safer than assuming the standard 75g dose. For the pre-dose sample, a generic concept was unavailable, so I had to assume the 75g standard.

Rows with only a name and no quantitative information (e.g., for hormones) were left unmapped because the property (e.g., Units/volume vs. Moles/volume) could not be definitively chosen from the candidates.

# Group 162

This group was a good mix of standard laboratory tests and unmappable local codes. The standard tests, particularly for blood gases (bicarbonate), routine chemistry (ALP, CK, LDH, ACE), and hematology (differential counts, RDW), were generally easy to map with high certainty. The Finnish prefixes for specimen (`ab-`, `vb-`, `p-`, `s-`, etc.) were extremely reliable guides. Quantitative evidence (`UNIT` and `deciles`) was crucial for distinguishing mass from mole units (for PTH) and confirming specimen (RBC folate vs serum folate).

Several codes could not be mapped because they were not laboratory tests, but rather administrative codes (`erikoislääkärinkonsultaatio`), procedure codes (`pt-vaativainhalaatiohoito`), or local panel definitions (`tth-peruspaketti`). The code for Kt/V dialysis adequacy was identifiable, but the correct LOINC concept was missing from the candidate list, indicating a gap in the search retrieval for that item.

A few codes like `u-solut, peruslaskenta` (urine cells, basic count) were too ambiguous to map confidently, as 'basic count' isn't specific enough to distinguish between a panel, a total count, or just a leukocyte count. Overall, the evidence provided was sufficient for making confident decisions for the majority of rows.

# Group 167

This group contained common hematology (differential blood counts) and clinical chemistry (serum protein electrophoresis) tests. The mappings were generally straightforward due to clear Finnish naming conventions. The use of 'konediffi' (machine differential) allowed for mapping to 'Automated count' concepts, while its absence led to choosing more general concepts. 'absol.arvot' (absolute values) and units like 'e9/l' clearly distinguished absolute counts from relative counts in '%'. The serum protein fractions were clearly part of an electrophoresis panel ('s-prot-fr'), justifying the choice of 'by Electrophoresis' concepts. Several rows were left unmapped because they lacked units and values, making it impossible to confidently determine the property of the measurement (e.g., [#/volume] vs ratio, or [Mass/volume] vs another property), which is the correct procedure in such cases. The candidate list was comprehensive for this group.

