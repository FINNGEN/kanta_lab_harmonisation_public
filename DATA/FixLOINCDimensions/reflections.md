# Group 7

This group contained tests for tissue transglutaminase (tTG) antibodies, part of the celiac disease workup. The mapping was straightforward, guided by three clear distinctions in the source data:
1.  **Immunoglobulin class**: The local names specified IgA (`-iga-vasta-aineet`) or IgG (`-igg-vasta-aineet`).
2.  **Property**: Rows with a unit (`U/mL`) and numeric values were mapped to quantitative concepts (`[Units/volume]`). Rows with no unit and 100% missing values were mapped to qualitative concepts (`[Presence]`).
3.  **Specimen**: All tests were in serum (`S-` prefix or implied).

For quantitative IgA and IgG tests, I chose the more general LOINC concepts (`3019050` and `3046870`) over the method-specific ones (`3046538`, `40759657`). This decision was reinforced by their Top 2000 status and significantly higher existing mapping frequency in Finland, suggesting they are the preferred targets.

Row 21 (`s-transglutaminaasivasta-aineet`, `U/mL`) was left unmapped. The name is non-specific about the immunoglobulin class. While it's likely IgA, the candidate list lacked a generic quantitative concept for "Tissue transglutaminase Ab [Units/volume]", so making an assumption would be incorrect. In contrast, its qualitative counterpart (row 22) had a perfect match in `3041414`, which I used.

# Group 14

This group was entirely about C-reactive protein (CRP) and was quite straightforward to map. The candidate concepts were excellent. The mapping strategy was to distinguish between three main types of tests based on the local codes and data:
1.  **Standard CRP in Serum/Plasma**: The vast majority of codes, with prefixes `S-`, `P-`, `fS-` or no prefix, mapped to the top-2000 concept `3020460`. This included point-of-care (`pika`, `vieritesti`) tests where the specimen was still plasma or serum.
2.  **High-sensitivity CRP (hs-CRP)**: Codes containing `herkkä` (sensitive) clearly mapped to `3010156`. The decile data, showing values typically <10 mg/L, confirmed this distinction.
3.  **CRP in Blood/Capillary blood**: Codes with prefixes `B-` (Blood), `cp-` (Capillary), or names including `veri` (blood) or `ihopisto` (skin prick) were mapped to `3051387` for Capillary blood, which is the most appropriate concept for whole-blood point-of-care tests.

All rows were successfully mapped. The provided data (prefixes, units, deciles, and keywords in names) was sufficient for a confident mapping for every row.

# Group 20

This group consisted primarily of microbiology nucleic acid amplification tests (NAA/PCR) and electrocardiogram (EKG) panels. The candidate concepts were excellent and highly specific, allowing for confident mapping of nearly all rows.

*   **NAA Tests**: Rows with `F-` (Feces) or `Li-` (CSF) prefixes and the `-nukl.haponos.` (`-Nh`) suffix were straightforward to map to the corresponding NAA-based LOINC codes. The candidate list provided perfect matches for each pathogen and specimen combination.
*   **EKG Panels**: The numerous variations of `pt-ekg, 12 kytkentää` (12-lead EKG) were all correctly mapped to the standard `12 lead EKG panel` concept (`3044889`), which also has high existing usage in Finland.
*   **Ambiguous Methods**: A few rows lacked explicit prefixes or method suffixes (e.g., `ehec...`, `etec...`). For EHEC (row 109), I chose a common immunoassay screen (`3020489`) which is also a Top2000 concept, as it seemed more appropriate for a generic code than the specific NAA test. For other pathogens where only an NAA candidate was available, I mapped to the NAA concept, assuming the generic name referred to the same common test.
*   **EKG Screening**: Rows 147-148 for atrial fibrillation screening were mapped to a `Rhythm segment [Interpretation]` concept (`3007355`), as there was no specific "rhythm screening panel" available, and an interpretation fits the purpose of screening.

# Group 21

This group was straightforward to map. The rows divided cleanly into two concepts: transferrin iron saturation and soluble transferrin receptor. The candidate list contained excellent matches for both.

For transferrin iron saturation (`transferriininrautakyllästeisyys` or `transferriinisaturaatio`), the LOINC Top 2000 concept `3009814` (Iron saturation [Molar fraction] in Serum or Plasma) was a perfect fit. The local data included results reported both as percentages (e.g., 23%) and as decimal fractions (e.g., 0.23), but both correctly map to the single LOINC concept with the property `Molar fraction`.

For soluble transferrin receptor (`transferriinireseptori, liukoinen`), the candidate `3015399` (Transferrin receptor.soluble [Mass/volume] in Serum or Plasma) was an exact match for the test name, specimen (serum/plasma), and unit (`mg/l`, implying mass/volume).

Only one row, #171, could not be mapped. Its unit was `paketti` (package/panel), which plainly contradicts the `is_panel: false` input. I have corrected `is_panel` to `true` for this row and left it unmapped as no suitable panel concept was available in the candidate list.

# Group 33

This group contained microbiology cultures, drug screens, EKG studies, and a genetic test. 

The MRSA cultures were mostly straightforward to map, with clear candidates for generic specimen (`3019902`), nose (`3039355`), and pharynx/throat (`46235760`). However, the candidate list lacked a concept for MRSA culture from perineum, preventing mapping of rows 186, 195, and 196.

The drug screen panels were a mixed bag. The 5-panel screen (row 188) was mapped to `40768439`, which specifies 'Screen method'. Multiple rows (189, 201, 202, 203) clearly indicated a 6-panel screen including buprenorphine, but no such concept was available in the candidate list, so these were left unmapped. 

The ambulatory EKG (Holter) studies (rows 198, 199, 200) were successfully mapped to the general `Ambulatory cardiac rhythm monitor (Holter) study` concept `3010479`. This was deemed appropriate even for the 48-hour study, as LOINC often uses a general study concept regardless of duration. 

The generic NGS panel (row 187) was left unmapped as none of the available candidates were a good fit for a generic "targeted gene variant analysis" test.

# Group 34

This group consisted of various Streptococcus tests (S. agalactiae/Group B, S. pyogenes/Group A, and beta-hemolytic strep). The mappings were generally straightforward by distinguishing between analyte, method (culture, antigen, NAA), and specimen (throat, vaginal fluid, or unspecified). The candidate list was comprehensive and contained appropriate matches for all rows.

The `prefix_meaning` (e.g., `Ps` for pharyngeal secretion, `Fl` for vaginal discharge) was critical for selecting the correct specimen-specific LOINC code. For rows without a prefix, the `Specimen` concept was chosen. For row 216, the specimen was identified from the Finnish long name `nielusta` (from throat) even though it lacked a prefix.

For the Strep A antigen tests (rows 213, 215), I chose `3033319` (Streptococcus pyogenes Ag [Presence] in Throat) over the more method-specific `21491660` (...by Rapid immunoassay) because `3033319` is also a `top2000` concept and has very high existing usage in Finland, suggesting it's the established national standard mapping.

# Group 37

This group was a mix of standard chemistry, hematology, microbiology, and more specialized tests. The point-of-care (POC) tests were generally easy to map, either to a specific POC concept (e.g., 'by Glucometer', 'by Rapid immunoassay') or to a general concept if a specific one wasn't available.

I was able to map most rows successfully. The unmapped rows fell into several categories:
1.  **Administrative/Billing Codes**: Rows like 226, 227, 279, and 321 are for billing or process management and have no clinical LOINC equivalent.
2.  **Lab Procedures**: Row 222 (`-histologinensolublokki...`) describes a sample preparation step, not an observation, so it doesn't map to a result LOINC.
3.  **Missing Panel Concepts**: Several local panels did not have a corresponding LOINC panel in the candidate list. This includes a generic bone marrow MRD panel (240), PEF monitoring panel (302), various drug panels with specific compound counts (276, 319, 320, 323, 328, 330), and a Yersinia species panel (338). Mapping these to a single component or a non-matching panel would be incorrect.
4.  ** overly specific local codes**: Row 225 for 'other pathogenic HPV' doesn't have a direct LOINC counterpart, which usually list specific genotypes or just test for 'HPV DNA'.

The candidate list was very comprehensive for single analyte tests, especially for common POC and urine dipstick measurements. For panels, especially in toxicology and microbiology, the granularity of the local codes sometimes exceeded what was available in the candidate list.

# Group 42

This group was largely straightforward, consisting of many common chemistry tests. The Finnish prefixes (`aP-`, `fP-`, `B-`, `dU-`, `Pf-`, etc.) were very helpful in determining the specimen. Most tests mapped well to `top2000` concepts.

A key decision was for `P-TT` (Prothrombin time) reported in `%`. This corresponds to prothrombin activity, not an INR ratio. I mapped it to `3005353` (Prothrombin activity actual/normal...), which has the `ACnc` property suitable for `%` units, rather than the INR concept `3033658`.

Several codes could not be mapped:
- `ap-nak` (row 348): No candidate for an *arterial* sodium/potassium panel.
- `p-fs` (rows 379-380), `p-ked.` (395), `p-kjd.` (396), `pneag` (454): The abbreviations were unidentifiable.
- Lupus anticoagulant tests `p-la1` and `p-la2` (rows 397-400): These clearly represent screen and confirm tests, but the candidate list lacked these specific concepts, only offering a generic dRVVT code which would lose this important distinction.
- `p-ttr` (rows 443-444): No concept for 'Time in Therapeutic Range' was available.
- `pef-pa` (448) and `pef-ras` (449): These are clearly PEF monitoring panels (long-term and post-exercise), but no suitable panel concepts were in the candidate list.

# Group 43

This group was a mix of straightforward mappings and unmappable codes. Most endocrinology tests (hCG, HE4, SHBG, DHEA/S, E1, E2, AMH) and common serology (ANA, ASO, TPHA) were easily mapped using the provided candidates. Differentiating between mass, molar, activity, and titer properties based on units and deciles was crucial, as was separating Presence/Absence tests from quantitative ones.

Several codes could not be mapped due to missing candidates:
*   Platelet function tests (`B-ADP`, `B-ASPI`, `B-VASP`) were completely absent from the candidate list.
*   Erythropoietin (EPO) in amniotic fluid (`am-epo`) and EPO reported in `pmol/l` (`s-epo`, row 558) had no matching concepts.
*   Tumor-associated trypsin inhibitor (`s-tati`) was also missing.
*   Several abbreviations (`-apot`, `-tp-*`, `-hae`, `-hepg`, `-hok`, `-hbe`, `-kem`) were too ambiguous to map confidently.

For therapeutic drug monitoring (Vancomycin, Gentamicin), the decile data was essential to confidently map to the more specific `--trough` concepts, which is a significant improvement in precision over the general drug level concepts.

# Group 44

This group contained a wide variety of tests, from routine chemistry (Bilirubin, Cholesterol, TSH) to toxicology (drugs of abuse, heavy metals), endocrinology (FSH), and urinalysis. Most quantitative tests were straightforward to map using the analyte, specimen, and unit. The use of `top2000` codes was very helpful in confirming the standard target concepts.

Several rows could not be mapped. The main reasons were:
1.  **Missing `Presence` concepts**: Many qualitative/screening tests (rows with no unit and high `p_missing`) could not be mapped because a specific LOINC concept for `[Presence]` in that specimen did not exist in the candidate list (e.g., Bilirubin in Serum/Plasma, FSH in Serum/Plasma).
2.  **Vague local codes**: Codes like `b-bio`, `u-bio`, `u-inf`, and the drug screen panels `u-ds*` were too non-specific to map confidently.
3.  **Missing candidates**: Tests for 1-Hydroxypyrene (`u-pyr`, rows 699-701) and MMSE (row 610) had no suitable candidates. Row 710 (`vp-dop`) was a non-laboratory procedure (arterial pressure measurement).
4.  **Specimen mismatch**: For umbilical cord TSH (row 708), the local code specified serum (`uS-`) but the only available candidate was for whole cord blood (`42870560`). This was mapped as the best available option, but it's an imperfect fit.

The distinction between BNP (`3011960`) and NT-proBNP (`3029187`) for code `P-BNP` was resolved by the `(32-)` in the long name, which likely refers to the 32-amino acid active BNP molecule, making `3011960` the correct choice.

# Group 51

This group covered a wide range of microbiology tests, mainly for respiratory and gastrointestinal pathogens, as well as some therapeutic drug monitoring (Infliximab, Mycophenolate) and tumor markers (SCC-Ag). 

The mapping was largely successful. The provided data fields (`LongName`, specimen prefixes, `UNIT`, `p_missing`) were critical for distinguishing between antigen vs. nucleic acid tests, qualitative vs. quantitative results, and different specimen types (respiratory, stool, serum, CSF, urine). Preferring Top2000 concepts and those with existing Finnish usage (`n_codes` > 0) helped resolve ambiguities, especially for common rapid antigen tests.

Several rows were left unmapped due to specific reasons:
- **Ambiguous local codes:** Codes like `-coinrsv`, `-infavt`, and `f-virag` were too vague to confidently map to a specific panel or test.
- **Missing candidates:** The candidate list lacked precise matches for several CSF antibody tests (e.g., Influenza IgG in CSF, Mycoplasma IgM `[Presence]` in CSF). It also lacked concepts for ratio-based antibody results (`index` or `s/co` units for `s-mypnabm`).
- **Non-lab procedures:** `-ivf-et` is a clinical procedure (embryo transfer), not a lab test, and thus has no LOINC laboratory concept.

For `rvirag-o` and `rvirag`, I overrode `is_panel=TRUE` to `FALSE` because the best fitting LOINC concept (`40757376`) has the property `[Identifier]`, meaning the result is the name of the identified virus, which is a single observation, not a panel of separate results.

# Group 68

This was a large group with many common analytes (Amylase, Alkaline Phosphatase, Albumin, Aldosterone) and their variants. The mapping was straightforward for most of these, especially where `top2000` concepts were available. The presence of deciles for rows with missing units was very helpful and allowed for confident mapping of many high-volume codes (e.g., rows 821, 825, 872).

Several rows could not be mapped due to ambiguous or unidentifiable local codes (e.g., `s-afluu`, `s-afospit`, `s-kalatue`, `s-oaldos`). The values for some of these were so extreme that they are likely local calculations or from a very specific context not covered by standard LOINC. For `s-amyl-is` (amylase isoenzymes), the available candidates were for specific panel sizes (3 or 7), not a generic panel, so it was left unmapped.

The candidate list was missing a concept for Amylase in 'Pancreatic fluid' (`Pa-Amylaasi`, row 832). While 'Duodenal fluid' was an option, it's not the same specimen. Similarly, `s-gliade` (deamidated gliadin Ab) could not be mapped to a total antibody test, as only IgA and IgG-specific concepts were available in the candidate list. The panel mapping for `s-adalip/s-adalipa` to 'Adalimumab and Adalimumab Ab panel' is a reasonable inference.

# Group 70

This was a large and diverse group of tests. Most rows were mappable thanks to a comprehensive candidate list. The tests covered therapeutic drug monitoring (carbamazepine, valproate), infectious disease serology (Parvo, Mumps), allergy testing (various nuts), coagulation (INR, PT, TT), and specialized chemistry (calprotectin, bile acids, carnitine).

Key points:
* **Calprotectin:** The distinction between `mass/mass` (ug/g) and `mass/volume` (mg/l) was clear and candidates were available for both (`3048689`, `42529010`).
* **Alkaline Phosphatase Isoenzymes:** The codes for macro-AP fractions (`s-afmaks1`, `s-afmaks2`) mapped well to `Alkaline phosphatase.liver 1/2` (`3035062`, `3036185`), but a quantitative concept for total macro-AP (`s-afmakro` and `s-afmaksa` with `u/l`) was missing from the candidates.
* **Allergies:** The candidate list was good, but for some allergens like Alder (`s-leppäe`), the local code is generic while LOINC is specific (Grey Alder, White Alder etc.). I chose Grey Alder (`t2`) as it is a common mapping target, but this is an assumption.
* **Administrative codes:** Several codes like `s-pakast*` (frozen sample), `u-valvott` (supervised collection) are administrative and correctly unmapped.
* **Panels:** Several panel codes (`b-vara` for crossmatch, `s-maksaab` for liver autoantibodies, `u-partik` for urine microscopy) were successfully mapped to appropriate panel concepts.
* **Missing concepts:** Some tests like Parvovirus IgG avidity (`s-parvavi`) and Parvovirus total Ab (`s-parvab`) lacked suitable candidates.
* **Data inconsistency:** Some rows (e.g., 961, 967) had `p_missing`=100% but also had decile values, which is contradictory. I used the deciles as the primary evidence in these cases, assuming they were quantitative tests with some data entry issues.

# Group 73

This group consisted of qualitative nucleic acid amplification tests for various respiratory viruses. The Finnish codes were generally clear mnemonics (e.g., `-infanho` for Influenza A, `-pin1nho` for Parainfluenza 1, `-rinonho` for Rhinovirus), and the `-Nho` suffix correctly identified them as qualitative nucleic acid tests. The main challenge was the specimen type, as the local codes often lacked a prefix. For single-analyte tests, I consistently chose the LOINC concepts with the generic `Specimen` system, as these had significant pre-existing usage in the Finnish data (`n_codes` and `n_events`), indicating a strong precedent. For panel tests (`-inabnho`, `-inabrsnho`), I selected the corresponding LOINC panel concepts. Several codes were left unmapped due to ambiguity (e.g., `-hinfnho`, `-tintnho`) or non-specific terms (e.g., `-infvnho` for 'variant'). The `hoho` suffix on some codes appears to be a local convention and could not be interpreted.

# Group 74

This group consisted entirely of qualitative nucleic acid tests (`-nho`). Mapping was generally successful where the Finnish code specified an analyte and either a specific specimen (e.g., `S-` for Serum, `F-` for Feces) or no specimen at all. For codes without a specimen prefix (e.g., `-bopenho`, `bopenho`), I consistently mapped to the LOINC concept with the generic `Specimen` system, as this is the most accurate representation.

Several rows could not be mapped because the candidate list was missing the required concepts. This was particularly evident for:
-   Generic bacterial NAA tests in specific specimens: `li-baktnho` (CSF), `f-baktnho` (Stool), and `-rbaktnho`/`resbaktnho` (Respiratory) all had plausible LOINC analogues, but those concepts were not among the candidates.
-   Panel tests: `f-paranho` (`-Parasiitit`, parasites plural) and `-boppnho` (`B. pertussis` + `B. parapertussis`) clearly represent multiplex tests, but no corresponding panel LOINC codes were retrieved.

The distinction between a generic code like `-borrnho` (Borrelia) and a specific one (`Borrelia burgdorferi`) was important; I chose the more general `Borrelia sp` concept (`648686`) as the better fit.

# Group 79

This group was dominated by urine albumin and protein tests, especially albumin/creatinine ratio (ACR) and urine sediment microscopy. Mapping was generally straightforward due to the excellent candidate list, which included the key Top 2000 LOINC codes for these common tests.

*   **Albumin/Creatinine Ratios:** Multiple local codes (`u-alb/kre`, `u-albkre`, `u-albkrea`, `nu-albkre`) all map to the same concept. I consistently chose the Top 2000 code `3001802` (Microalbumin/Creatinine [Mass Ratio] in Urine), which is the recommended target despite the "Microalbumin" term, as it fits the `mg/mmol` unit (a mass/mole ratio that LOINC files under Mass Ratio) and is the standard for this measurement.
*   **Urine Sediment:** The `U-Sakka` (sediment) components were easily mapped to their corresponding Top 2000 microscopy codes (Erythrocytes, Leukocytes, Epithelial cells, Bacteria, Casts). For casts (`lieriö`), I chose the low-power field concept (`3005658`), as this is the standard method for observing them. For 'other' (`muuta`), I found a more specific concept (`40761543`, Other elements) than the generic `Microscopic observation`.
*   **Timed vs. Spot Samples:** I was able to distinguish between timed collections (e.g., `cU-Alb-mi` in `ug/min`, `nU-Alb-mi` in `mg/12h`) and spot samples (e.g., `U-Alb-mi` in `mg/l`).
*   **Unmappable Codes:** The codes `u-alvhu4a`, `u-alvhu5b`, and `u-alvhu6a` were opaque and had no supporting data, so I correctly left them unmapped.

# Group 84

This group consisted of administrative codes for pre-analytical procedures. The majority (`notto`, `otto`, etc.) represented the act of specimen collection, which often appear as billable items with no result value. I mapped these to `36660087 | Specimen Collection procedure comment`, as this best reflects their nature. Codes explicitly mentioning supervision (`valv.notto`, `alvhuumott`) were mapped to the more specific `1989324 | Specimen collection supervision level`. 

A key distinction was made for `ottotapa` (collection method): row 1236 had a unit of 'h' and numeric values, pointing to a time measurement, and was mapped to `3026893 | Specimen collection [Time] of Specimen`. Row 1237, with no unit or value, was mapped to the nominal `3042242 | Collection method - Specimen`. This highlights the importance of using unit and value data to differentiate concepts. The candidate list was good but lacked a concept for specimen transport, forcing me to leave `näytekulje` (row 1232) unmapped.

# Group 85

This was a varied group with clear mappings and some unmappable codes. The quantitative tests like Urate, Acetone, Valproate, and Cobalt were straightforward, with `UNIT` and `deciles` providing clear evidence for selecting the right LOINC concept based on property (Moles/volume or Mass/volume) and specimen. The `Top2000` flag was very helpful in resolving ambiguity, for instance, in choosing `Acetone [Presence] ... by Screen method` (3037286).

Several rows could not be mapped. Administrative or procedural codes like `-aerobivi`, `annosvoim`, and `projekti` are outside the scope of LOINC lab tests. Some local codes were too fragmentary (`-omactgc`) or complex (`hpvpapctgc`) to decipher. The `cladosp.he` with unit `mm` (row 1248) was clearly a skin test, for which no candidates were available. Qualitative `uraatti` tests (rows 1265, 1270, 1276) also lacked a suitable `[Presence]` candidate in serum/plasma. Similarly, `u-omactgc` (row 1274), a CT/GC panel in urine, did not have a perfect panel candidate in the list — the available options either included an extra pathogen (Trichomonas) or were specific to rRNA, making a confident mapping impossible.

For the coronavirus RNA tests (1251-1254), I opted for the more general `Specimen` concepts over `Respiratory system specimen`, as this was safer without explicit specimen information and was consistent with existing mappings in Finland (`n_codes` > 0).

# Group 89

This group consisted almost entirely of screening tests (`seul` or `seula`), mostly panels. The mappings were generally straightforward by combining the prefix (e.g., `S-`, `U-`) with the core test name (`hpv`, `kem`, `ena`, `äit`).

*   **Mappable**: The urine chemical screens (`u-kemseul`), maternal screens (`s-äit-seul`, `s-tr1seul`), ENA screen (`s-enaseul`), and drug screen (`u-huseula`) had clear, well-established panel candidates.
*   **Slight Ambiguity**: For the generic second-trimester screen (`s-tr2seul`), the candidate list offered specific panels (triple, quad, penta) but no generic one. I chose a broader panel concept (`3029318`) that covers the purpose of second-trimester screening for fetal abnormalities.
*   **Unmappable**: `hoikemseul` (row 1278) was too ambiguous without a `LongName` or other context clues; the `hoi` prefix could have several meanings.
*   **Single Tests vs. Panels**: It was important to distinguish panels from single tests. For example, `hpvseul` (HPV screen) and `rhdnegseul` (RhD screen) are screening tests but report a single result (Presence/Absence), so I mapped them to single concepts and set `is_panel` to false.

# Group 105

This group consists of various complete blood count (CBC) panels and their components. The Finnish codes `B-PVK` (basic blood count), `B-PVK+T` (with platelets), `B-PVK+TKD` (with automated differential), and `B-TVK` (complete blood count) were generally straightforward to map.

For individual result components, I consistently chose LOINC concepts specifying `by Automated count` when available and on the Top2000 list, as these tests are performed on automated hematology analyzers. This provides more specific mapping than the generic codes, even if the generic codes had higher existing usage in Finland.

The panel codes were mostly mapped successfully. `B-PVK` and `B-PVK+T` were mapped to `Short blood count panel - Blood` (40758558). `B-PVK+TKD` and `B-TVK` were mapped to `CBC panel - Blood by Automated count` (40761511).

Some rows could not be mapped:
- Rows with ambiguous units like `form` (1309, 1326, 1391) or unclear measurements (1319, 1392) were left unmapped.
- The candidate list was missing concepts for certain panels. Specifically, panels including reticulocytes (e.g., `b-pvkt+re`, `b-pvktkdr`, `b-tvk+r`) and panels with a 3-part 'minidiff' (`b-pvk+tmd`) did not have exact matches. For the 3-part diff panels, I mapped to the 5-part diff panel (`40761511`) as the closest available superset. The reticulocyte panels were left unmapped due to a lack of a suitable candidate panel.

# Group 106

This was a large group of bacteriology tests. The mapping was mostly successful by carefully parsing the Finnish test names (prefixes for specimen, suffixes like `-vi` for culture and `-vr` for stain). The distinction between identification (qualitative), counts per volume, and counts per area was crucial and could be determined from the units (`e6/l`, `/sunf`) and deciles.

The main challenge was the lack of good candidates for generic stain results (e.g., `ex-baktvr`, sputum stain) and for some less common or ambiguously named tests (`pp-baktnh`, `-bakt-he`, `u-baktla`). For specimen-specific stains like in CSF or synovial fluid, a `Microscopic observation [Identifier] ... by Gram stain` concept was available and chosen as the most likely interpretation of `-vr` (stain). For urine, the distinction between automated particle counts, microscopy counts, and culture counts (both quantitative and qualitative) was clear and had excellent LOINC candidates in the list, many of which were top-2000 codes with high existing usage in Finland.

# Group 110

This group consisted primarily of lymphocyte subpopulation counts from blood and other specimens, measured either as absolute counts (`B-`, `#/volume`) or as fractions of a parent population (`Ly-`, `%`). Mapping was generally successful for standard markers like CD3, CD4, CD8, and the CD4/CD8 ratio, especially where `top2000` concepts with existing Finnish usage were available.

A key challenge was interpreting LOINC concepts where the denominator is `.../cells` when the Finnish code (`Ly-` prefix) clearly indicates a fraction of lymphocytes. I mapped these to the `/cells` concepts (e.g., for `Ly-CD4` to `3014037 CD3+CD4+ .../cells`), assuming this is standard practice, supported by their `top2000` status and Finnish usage. The concept `1175426 CD3 cells/Lymphocytes in Blood` shows a more specific denominator is possible, but such options were not available for other markers.

A significant gap in the candidate list was the absence of a concept for `B-lymphocytes/Lymphocytes in Blood` (e.g., LOINC 21087-9). This prevented mapping for several rows (1519, 1520, 1525-1528) measuring `Ly-CD19`.

Measurements from leukapheresis products (`LA-` prefix) were mostly mappable, though for CD4 and CD8 counts, only generic `Specimen` concepts were available. Rows with the unknown specimen prefix `so-` (1558-1563) could not be mapped.

# Group 111

This group was almost entirely COVID-19 related tests, which were generally straightforward to map. 

*   **Mapped successfully:** Most tests for COVID-19 RNA (`-cv19nho`), rapid antigen (`-cv19ag`, `-cv19pika`, etc.), multi-pathogen RNA panels (`cv19infrs`), and serum/plasma antibodies (total, IgG, IgA, IgM) had clear targets in the candidate list. For the many local variations of the rapid antigen test, I standardized them to `36033641` (Ag [Presence] in Upper respiratory specimen by Rapid immunoassay), which already had Finnish usage.
*   **Data Quality Issues:** Rows 1566-1575 for `-cv19ag` reported quantitative results in nonsensical units for an antigen test (e.g., `e12/l`, `fl`). These are clearly data errors and were left unmapped.
*   **Candidate List Gaps:** The codes for spike protein antibodies (`s-cv19sab`, rows 1608-1610) could not be mapped. The Finnish code does not specify IgG or neutralizing function, but the available candidates did (e.g., `...S protein IgG Ab...` or `...S protein RBD neutralizing antibody...`). The correct generic LOINC concepts for total anti-Spike antibodies (quantitative `94745-0` and qualitative `94746-8`) were not in the candidate list.
*   **Approximation:** For C1q IgG antibodies (`p-c1qabg`), no IgG-specific concept was available. I mapped them to the concepts for total C1q antibodies (`3042951` and `3041700`) as a reasonable approximation, supported by existing Finnish usage.
*   **Unmappable:** Codes like `-covidjt` and `cldinho` were too cryptic to identify and were left unmapped.

# Group 121

This group consisted almost entirely of molecular genetics and cytogenetics tests. Many were standard pharmacogenomic or hematologic oncology tests that were readily mappable thanks to `LongName` descriptions and informative abbreviations (e.g., `B-LAKT-D`, `B-FV-D`, `B-JAK2-D`, `B-BCR-QR`).

The candidate list was generally very good. However, a crucial concept for Prothrombin (Factor II) gene analysis (`B-FII-D`, rows 1638-1639) was missing, preventing a mapping for this common thrombophilia test. Similarly, several requests for FISH panels (`B-FISHHEM`, `BM-FISH-MM`) were for panels more generic than the specific disease panels available in the candidate list, leading to no mapping.

A few codes were too cryptic to map (e.g., `-ctr-d`, `b-auria10`, `b-blapcr`). For quantitative MRD tests (`bm-aso-qd`, `bm-mrdmut`), the specific LOINC concepts for quantitative PCR-based monitoring of clone-specific markers were not present, though the guess was accurate. I mapped what I could to the most specific available concepts, leveraging `top2000` status and existing Finnish usage data (`n_events`) as strong indicators (e.g., for `B-LAKT-D` and `B-TPMT-D`).

# Group 126

This group was straightforward, consisting almost entirely of glucose measurements. Most rows were clearly identifiable as parts of a glucose tolerance test (0, 30, 60, 120-minute samples) and mapped cleanly to the corresponding time-stamped LOINC concepts for Serum/Plasma. The `mmol/l` unit and deciles confirmed these were Moles/volume measurements.

The `gluk-vieri` codes (rows 1712, 1737, 1738) were correctly identified as point-of-care tests, which pointed to `Capillary blood` as the specimen (`3040151`).

The CGM-related codes `-gluk-tbr` (time below range) and `-gluk-tir` (time in range) were interesting. `1469878` was a good fit for TBR. For TIR (row 1711), the candidate list lacked a perfect match for '% time in range'. I chose `1617716 | Glucose measurements in range out of Total glucose measurements during reporting period` as the best available proxy, since it represents a ratio ('%') of in-range values.

Several rows with 100% missing values (`1719`, `1723`, `1731`, `1736`) were left unmapped, as they likely represent cancelled orders or administrative/preparatory steps (`-valm`).

# Group 129

This group consisted of `Pt-` (Patient) investigations, mainly panels or studies. I was able to map several categories of tests.

*   **Spirometry**: Codes with `spiro` and `fvsp` were clearly spirometry. I mapped basic spirometry to `3000492` (Spirometry study), preferring it over `21493451` (Spirometry panel) because of its existing usage in Finland. For codes implying a bronchodilator test (e.g., `pt-fvspird`, `pt-spirom`), I used `36031657` (Pulmonary vasodilator test panel).
*   **Semen Analysis**: The `pt-sper-` codes were clearly identifiable from `TEST_NAME` and `LongName`. All variants (`suppea`/limited, `laaja`/extensive) were mapped to the general `3008607` (Semen analysis panel), as this represents the overall procedure.
*   **Cardiology**: `pt-sydänuä` was a clear abbreviation for `sydämen ultraääni` (echocardiogram), which I mapped to `3009203` (Cardiac echo study Procedure).

Several codes could not be mapped. Many, such as `pt-fvsirod` and the `pt-syd...` codes (1764-1767), had abbreviations that were too truncated or ambiguous and lacked a `LongName` to clarify their meaning. Additionally, `pt-st-temp` (`Pt-Terminen tuntokynnysmittaus` / Thermal sensation threshold measurement) had a clear meaning but no suitable LOINC candidate was available in the provided list; the available temperature-related concepts were for simple measurements, not a sensory threshold study.

# Group 160

This was a very straightforward group. The local test names clearly corresponded to three common liver enzymes: Alanine aminotransferase (ALAT/ALT), Aspartate aminotransferase (ASAT/AST), and Gamma glutamyl transferase (GT/GGT). The candidate list provided the exact, top-ranked, highly-used LOINC concepts for these three tests in Serum/Plasma with the property of Enzymatic activity/volume, which matched the `U/l` unit in the data. All rows could be confidently mapped. The variations in local names (e.g., `s-`, `p-`, `fs-`, `fp-`) correctly collapsed into the standard LOINC 'Serum or Plasma' specimen type. Rows with missing units and values were clearly orders for these same tests and were mapped accordingly.

# Group 161

This group contained a mix of chemistry, microbiology, and hematology tests. The mappings were generally straightforward.

A key challenge was the `B-Fosfatidyylietanoli` (Phosphatidylethanol in Blood) test. Rows with the unit `umol/l` (e.g., 1790, 1792) clearly indicate a quantitative molar concentration. However, the candidate list lacked a LOINC concept for `[Moles/volume]`, only offering `[Mass/volume]` and `[Presence]`. Consequently, these quantitative rows were left unmapped. The rows with empty units and high `p_missing` were mapped to the `[Presence]` concept, assuming they represent qualitative screening tests.

The glucose tests with specific timings (fasting, 1h/2h post-dose, 2h post-meal) were easily mapped to the correct Top 2000 LOINC codes. Similarly, hormones like FSH and LH were clear matches.

The microbiology NAA tests were identifiable by the `-nukleiini` suffix. Most were mapped to general `Respiratory system specimen` concepts, which seemed appropriate in the absence of more specific local information, except for the `Li-` prefixed test which was correctly mapped to CSF.

The two types of "Large unstained cells" were successfully differentiated by their units: `e9/l` mapped to the absolute count (`[#/volume]`), and `%` mapped to the fraction (`/Leukocytes`).

For C-peptide `1h post meal` (row 1827), a perfectly specific LOINC concept was not in the candidate list. The mapping was made to the less specific but correct parent concept `C peptide ... --post meal` (`40759040`).

# Group 162

This group was a mix of common chemistry, hematology, and some specialized tests. Mapping was straightforward for most common tests like ALP, CK, LDH, phosphate, and the various bicarbonate measurements, where the specimen prefix (`AB-`, `P-`, `VB-`, `CB-`) and the distinction between actual vs. standard bicarbonate were key. The candidate list was excellent for these.

The many synonyms for Red Cell Distribution Width (RDW, e.g., `punasolujen kokojakauma`, `koonvaihtelu`) all correctly mapped to the same `top2000` LOINC concept (`3019897`). Similarly, all variants of the free/total PSA ratio mapped well to `3001784`.

I was unable to map several rows:
- Row 1842 (`-kt/v,daugirdaksenkaava`): No candidate for this dialysis adequacy measure.
- Rows for local/administrative panels (e.g., `fs-työterveyshuollonperuspaketti`, `s-nightingale-mittaus`) are unmappable to standard LOINC concepts.
- Row 1909 (`p-lupusantikoagulantti`): The local name was too general for the specific LOINC candidates available.
- Row 1911 (`p-urea,resirkulaatio`): The name implied a ratio (recirculation) but the unit (`mmol/l`) and values were for a substance concentration, a contradiction that prevented mapping.
- Some non-laboratory or highly specific procedural codes (`erikoislääkärinkonsultaatio`, `ilmajohtotarv.luujohto`) were also unmappable as expected.

# Group 167

This group consisted of common hematology differential counts and serum protein electrophoresis fractions. Mapping was straightforward for most rows. The local naming was clear, distinguishing between absolute (`B-`, `e9/l`, 'absol. arvot') and relative (`L-`, `%`) counts, and explicitly stating automated method (`konediffi`). I chose specific 'by Automated count' LOINC codes where `konediffi` was present or implied for modern tests (like absolute counts and RDW), and more general codes (without method) where the Finnish code was generic (e.g., `L-Neut`). The serum protein fractions were also clearly named and mapped well to the specific electrophoresis LOINC codes. The only unmapped row was for 'M-komponentti-3' (row 1984), as the candidate list lacked a concept for a third monoclonal protein band, only providing options for a general/first band and a second band.

