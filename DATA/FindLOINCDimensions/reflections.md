# Group 7

This group was fairly consistent, centered around tissue transglutaminase antibodies. The key distinctions were between IgA and IgG, and between quantitative (`Qn`) and qualitative (`Ord`) results.

**Gotchas and Ambiguities:**
*   **System Inference**: Rows 364-371 lacked the `S-` prefix. However, sibling rows like 366 and 369 explicitly mentioned `seerumista` (from serum), and all other rows in the group were for Serum. It felt safe to infer `Serum` for all, but this relies on group context which might not always be reliable.
*   **Panel vs. Single Test**: Suffixes like `osatutk.` (part of study, row 374) and `keliakiatutkimus` (celiac study, row 380) could imply a panel. I interpreted them as descriptive text added to a single test's name, not as a panel code itself, because the component (IgA antibodies) was explicitly named. True panels usually have a more generic name.
*   **Ambiguous Component**: Rows 384 and 385 (`s-transglutaminaasivasta-aineet`) didn't specify the immunoglobulin class (IgA/IgG). I used a more general component `Transglutaminase Ab` which is correct but less specific.
*   **Method Detection**: Only row 375 (`eliau/ml`) gave a clear hint about the method (`Immunoassay`). It's highly likely all other quantitative tests in this group use a similar method, but without evidence, the method axis was correctly left empty per instructions.

Overall, the pairing of quantitative rows with units and deciles alongside qualitative rows with 100% missing values was a clear and helpful pattern. The component name `Transglutaminase Ab` is the standard LOINC component, so mapping was straightforward once the IgA/IgG distinction was made.

# Group 14

This group was overwhelmingly about C-reactive protein (CRP), which made the component identification straightforward. The main challenges were:

1.  **Ambiguous Systems**: Many test names lacked a specimen prefix (`B-`, `P-`, `S-`). I was able to infer the system in some cases from clarifying text in the name string itself (e.g., `...plasmasta` for Plasma, `...veri` for Blood, `...seerumista` for Serum). For others, like row 971, the system had to be left empty. The prefix `cp-` combined with `ihopiston` (skin prick) was a good clue for `Blood capillary`.
2.  **Conflicting Information**: Some test names included qualifiers that contradicted the data. For instance, `p-c-reaktiivinenproteiini(kval)` (row 1016) suggests a qualitative test, but the `mg/l` unit and deciles clearly indicate it's quantitative. In these cases, I trusted the quantitative data (unit, deciles) over the text in the name. Similarly, `...osoitus` (detection) suggests qualitative, but it was used for both qualitative (row 1040) and quantitative (row 1041) results, highlighting inconsistent naming.
3.  **Data Quality**: Several rows had inconsistent or dirty data. Row 970 had a unit of '1' but quantitative deciles consistent with mg/l, suggesting a data entry error. I prioritized the deciles. Rows 1024 (unit '1', no deciles) and 1025 (unit 'alle') appeared to be genuinely non-quantitative, which I mapped to Ord and Nar respectively.

Overall, the deciles were extremely useful for confirming property (`Mass Concentration`) and scale (`Qn`) even when the unit was missing or incorrect. The grouping of similar test names was crucial for resolving typos (`resktiivinen`) and for using a clear entry (e.g., one with a unit) to inform its siblings with missing data.

# Group 20

This group contained two distinct test types: ECG procedures and microbiology nucleic acid amplification tests (NAATs). 

The NAATs were clearly identifiable by terms like `nukl.haponos` or the `-nho` suffix. The identical `n` counts for the Feces (`F-`) and CSF (`Li-`) pathogen test groups strongly suggest they are components of multiplex PCR panels (e.g., a gastrointestinal panel and a meningitis/encephalitis panel, respectively). I have correctly coded these as individual results (`is_panel: false`). The ambiguity arose for pathogen tests without a clear specimen or method (e.g., rows 1265, 1275, 1310), for which I could only assign Component, Property, Scale and Time, leaving System and Method empty.

The ECG codes were mostly variations of a 12-lead resting ECG. I inferred the system as `^Patient` even when the `Pt-` prefix was missing, as this is intrinsic to an ECG. The numerous suffixes like `(asiakkaan ottama)` (patient-recorded), `(sisältäen tietokoneanalyysin)` (includes computer analysis), or location information are interesting metadata but do not typically alter the core LOINC axes for the procedure itself, which I mapped as a `Doc`ument `Finding`. Row 1296 with a `UNIT` of '1' and `p_missing` of 55% was an outlier that I interpreted as a data quality issue and mapped consistently with its peers.

# Group 21

This group contained two main concepts: 'Transferrin saturation' (Finnish: *transferriinin rautakyllästeisyys* or *rautasaturaatio*) and 'Soluble transferrin receptor' (*transferriinireseptori*). The distinction was clear from the test names.

A key observation was the dual representation of Transferrin saturation: some rows used '%' as the unit with values like 20-30, while others had no unit but deciles in the 0.2-0.3 range. This is a classic percentage vs. fraction-of-1 issue. I correctly inferred the property as `Mass Fraction` for both, using the `deciles` to disambiguate where the `UNIT` was missing. The Finnish unit 'osuus' (fraction) on row 1326 confirmed this interpretation.

Identifying panels was straightforward: row 1327 had 'paketti' (package) as its unit, a clear indicator. For many rows, the system (specimen) was not specified in the local code, so leaving `has_system` empty was the correct action. The rows with very high `p_missing` and no deciles were mapped to the `Nar` scale, which is a reasonable interpretation of data that could not be parsed as quantitative, even if the underlying test is quantitative.

# Group 33

This group contained several long, descriptive test names, which are challenging but also informative. The grouping by text similarity was crucial for interpreting truncated names, such as `viljelyne` being a prefix of `viljelynenästä` (culture from nose) or `viljelyni` being a prefix of `viljelynielusta` (culture from throat). A key ambiguity was identifying panels vs. complex single tests. I classified the long-term ECG recordings (`Pt-EKG`) as panels, as they represent a whole study culminating in a report with multiple findings, which aligns with LOINC's modeling approach for such procedures. Conversely, the generic NGS test name (row 1816) describes a single complex narrative result, so I marked it `is_panel: false`. The `TEST_NAME` for the NGS test was too generic ('study of...a predefined gene') to allow for component identification, highlighting a limitation when local codes are descriptive but non-specific.

# Group 34

This group highlights several common challenges in microbiology test mapping. 

1.  **Method Ambiguity**: The term `osoituskoe` ('detection test') in row 1850 is too generic to confidently map to a specific method like `Immunoassay` or `NAA+probe`, forcing the `has_method` axis to be left empty. 
2.  **Missing System Information**: Many rows lack a system prefix (`Ps-`, `Fl-`), making it impossible to determine the `has_system` axis. While row 1845 contained a clue in the test name (`nielusta` -> from the throat), most others did not, demonstrating a common data quality gap. Having the `LongName` for these rows would likely have resolved this.
3.  **Component Specificity**: The test name `hemolyyttiset streptokokit` (beta-hemolytic streptococci) refers to a group of bacteria. I mapped this to a generic component `Streptococcus beta hemolytic`. While throat cultures often focus on Group A (S. pyogenes), the test name is broader, and mapping to the more specific component would be an over-inference. For cultures (`-Vi`), I opted for `Presence or Identity` as the property and `Nom` as the scale, as the goal is to identify the organism, whereas for antigen/NAA tests, `Presence or Threshold` and `Ord` are more fitting for a positive/negative result.

# Group 37

This was a very diverse group, ranging from standard chemistry and hematology to microbiology, pathology, genetics, and patient-level procedures like lung function tests and sleep studies. The `TEST_NAME` strings were often long, concatenated, and descriptive Finnish phrases rather than clean abbreviations, which required more interpretation.

**Gotchas and Ambiguities:**
*   **Administrative codes:** Several rows (e.g., 1898-1901, 1936-1938, 1993) were clearly administrative or billing codes ('additional fee', 'result transfer helper'). Identifying and ignoring these is key.
*   **Incorrect `prefix_meaning`:** For rows 1985 and 1986, the prefix `T-` was decoded as 'Thrombocyte', but the component was clearly T-cells (auttaja-/estäjäsolut). This required overriding the provided hint with knowledge of the test component, assigning `Blood` as the system.
*   **Incorrect `UNIT`:** For row 1945 (`b-kreatiniini`), the unit was `mmol/l`, which is biologically impossible for creatinine. The deciles clearly indicated the standard `umol/l`. I trusted the deciles and analyte name over the recorded unit.
*   **Ambiguous `Scale`:** For urine particle counter tests (e.g., 1910, 1923), some rows had quantitative data (`Qn`) while others with identical names had 100% missing values. I interpreted the latter as `Ord` (`Presence or Threshold`), assuming a different reporting mode (e.g., 'few', 'many') or that they are just order codes.
*   **Point-of-Care (`vieritesti`):** For POCT, the System is often not specified. I left it blank unless there was a clear indicator like 'sormenpäänäyte' (fingertip sample -> `Blood capillary`). Method is often `Test strip`, which I added for urine dipstick tests, but left blank for others to avoid over-interpreting.

**Improvements:**
Having the official Finnish long name (`LongName`) for more rows would have been very helpful, especially for the longer, more descriptive `TEST_NAME`s, as it would confirm interpretations. Also, having a dictionary of common Finnish medical terms (like 'vieritesti', 'osatutkimus', 'pikatesti', 'viljely') would speed up the process.

# Group 42

This group was large and diverse, covering basic chemistry, hormones, coagulation, and cardiac markers. The presence of `LongName` for many rows was extremely helpful for confirming components (e.g., `P-TT` as thromboplastin time, `P-FV` as Factor V).

**Gotchas and Ambiguities:**
*   **Prefix `ap-`**: This isn't a standard prefix. I inferred it as 'Arterial Plasma' based on the combination of `a` (arterial) and `p` (plasma). This seems plausible, especially for `ap-lakt` (Lactate), which can be measured from arterial samples. This leads to the `Plasma arterial` system, which is a valid but less common LOINC system.
*   **Unclear codes**: `p-fs`, `p-ked.`, `p-kjd.`, `p-tnl` were ambiguous. For `p-fs` (unit 's'), I made a conservative guess of a generic `Coagulation` component. For `p-ked.` and `p-kjd.`, the component was unknowable. For `p-tnl`, the context strongly suggested a typo for `p-tni` (Troponin I).
*   **Coagulation System**: Coagulation tests (AT3, FV, FX, TT, LA) are typically performed on `Platelet poor plasma`. The prefix `P-` just decodes to `Plasma`. I used the more specific `Platelet poor plasma` system and added `Coagulation assay` as the method, as this is a standard LOINC convention for these tests.
*   **Panel Identification**: Codes like `p-k+na`, `p-nak`, `pef-pa`, and `sp-pak` were clearly panels, either combining multiple analytes or representing a procedure/serial measurement. The 100% `p_missing` is a strong indicator for these.
*   **Inconsistent data**: Many rows had `100%` `p_missing` but still had deciles (e.g., 2535 `p-gt`, 2553 `p-na`). This is a data quality issue, but I trusted the deciles to infer the property and scale for those rows.

**Improvements:**
*   A glossary of non-standard prefixes like `ap-`, `cp-`, and `v-` would be beneficial. `vp-` was inferable as Venous Plasma, but `v-` alone was ambiguous (I chose `Blood venous`).
*   Clarification on how to handle rows with both high `p_missing` and `deciles` would be useful. My current approach is to trust the deciles over the missingness percentage if they are present and plausible.

# Group 43

This was a large and diverse group of tests, covering everything from hormones and tumor markers to drug levels and antibodies. Having the `LongName` was critical for most rows; without it, abbreviations like `AST` (Antistreptolysin, not the enzyme), `APOT`, `HAE`, or `KEM` are ambiguous or unmappable.

Key challenges and decisions:
*   **Platelet function tests (`b-adp`, `b-aspi`, `b-vasp`):** These are less common than standard chemistry. Recognizing `ADP` and `ASPI` as agonists and `VASP` as a specific test was necessary. Assigning `Platelet aggregation` or `Flow cytometry (FC)` as methods was an expert judgment but important for distinguishing these tests.
*   **Panel vs. Single Test (`s-enal`, `ts-res`):** Codes with 100% missing numeric values and suggestive names (`-L` for `laadullinen`/qualitative or `-Res` for `tutkimus`/study) are good candidates for panel codes. I marked `S-ENAL` and `Ts-Res` as panels. The `S-ENA` row with deciles was interpreted as a quantitative ENA screen index.
*   **Implicit Methods:** For classic tests like `ANA` (IF), `EMA` (IF), `TPHA` (Hemagglutination), and qualitative `U-hCG` (Test strip), I added the method because it is almost invariably linked to the test and is key to its identity. This goes slightly beyond the explicit data but greatly improves the mapping quality.
*   **Conflicting Data:** Row 2723 (`S-SHBG`) had `p_missing` of 100% but also a full set of `deciles`. I trusted the deciles, assuming the `p_missing` was an error, and mapped it as quantitative (`Qn`). This highlights the need for careful cross-checking of all available columns.
*   **`du-5hiaa` variants:** It was important to distinguish between total amount per collection (`umol`, property `Substance Rate`), explicit rate (`umol/24h`, property `Substance Rate`), and concentration (`umol/l`, property `Substance Concentration`). The `dU-` prefix consistently defined the `Time` as `24 hours`.

# Group 44

This group contained a mixture of common chemistry tests, toxicology screens, and a few unidentifiable codes. The pattern of having a quantitative row followed by a high `p_missing` row for the same test was very consistent. I've mapped these high-missing rows as `Nar` (narrative) scale with a `Finding` property, assuming they represent cases where results were entered as text or were otherwise non-numeric. This reflects the data's state but links them to the same conceptual test.

Several abbreviations were ambiguous or non-standard (`b-bio`, `p-fsl`, `u-ds...`), requiring either inference (`p-fsl` -> Fibrinolysis time) or leaving them unmapped. For `fl-koh`, I inferred `KOH prep` for `Fungus`, which is a strong possibility but still a guess. The `suffix_meaning` for `u-cl` (row 2811) contradicted the `LongName` and `UNIT`, so I trusted the latter two.

Distinguishing between `Mass Concentration` (`g/l`, `ug/l`, etc.) and `Substance Concentration` (`mol/l`, etc.) was straightforward based on units. A key point was remembering that for hormones (FSH, TSH), LOINC uses `Substance Concentration` for `IU/L` units, not `Catalytic Concentration`.

The large number of qualitative urine drug screens (`u-amp`, `u-bup`, etc.) with `p_missing` of 100% was easy to classify as `Ord` with `Presence or Threshold` property.

# Group 51

This group was dominated by infectious disease testing, primarily viral antigens (`-ag`) and antibodies (`-ab`, `-abg`, `-abm`). The Finnish abbreviations were quite systematic and, combined with the `LongName` column, made component identification straightforward. 

A key challenge was distinguishing single multiplex tests from true panels. I interpreted codes with multiple pathogens in the name (e.g., `-inabrsv`) or with generic names like `-rvirag` (respiratory virus antigen) as panels, especially when corresponding single-pathogen tests existed. The logic is that these codes represent an orderable that results in multiple distinct observations.

The most significant ambiguity arose from data contradictions in rows 3511 and 3515, where `p_missing` was 100% but `deciles` were also present. I prioritized the `p_missing` value, as it directly reflects the absence of numeric results in the source, and classified them as `Ord` (Ordinal). This points to a potential upstream data processing issue. The presence of both quantitative (with units like `eiu`, `mg/l`) and qualitative (high `p_missing`, no unit) versions of the same test was a common and easily handled pattern.

# Group 68

This group contained a wide variety of tests, primarily chemistry and immunochemistry. Here are some observations and challenges:

*   **Ambiguous Codes**: Several test codes were ambiguous. For example, `s-aaldos`, `s-oaldos`, and `s-valdos` all appear to be Aldosterone tests, but the prefixes `a-`, `o-`, `v-` are not standard and the result distributions are vastly different, suggesting they are performed under specific, unstated conditions (e.g., stimulation tests). Without documentation for these local codes, I mapped them to the base component 'Aldosterone' but the true LOINC would likely include a challenge in the component name.
*   **Data Contradictions**: A recurring issue was rows with `p_missing=100` that still had `deciles` data (e.g., 5263, 5267, 5271). In these cases, the decile distributions closely matched quantitative sibling rows, so I inferred the scale was `Qn` despite the `p_missing` value, assuming a data pipeline error. This highlights the importance of using all available columns for context.
*   **Missing System**: Codes without a system prefix (e.g., `alfa-1`, `-amyl`) are difficult to map accurately. While context strongly suggests `Serum` for protein fractions like `alfa-1`, I had to leave the `has_system` axis empty as per the instructions, which reduces the specificity of the mapping.
*   **Panel vs. Component**: Differentiating panels from components was key. Codes with the `-is` (isoenzymes) suffix, like `s-afos-is` and `s-amyl-is`, were identified as panels that bundle multiple individual results. This was straightforward. More complex panels would be harder to spot without a `LongName` or more structural information.
*   **Inferred Methods**: For protein fractions (`alfa-1`, `alfa-2`) and isoenzymes (`s-afos-is`), `Electrophoresis` is the standard method and adds crucial context, so I inferred it. Similarly for `s-scl-t` (Immunoblot) and `s-hladsa` (Flow Cytometry), these are very standard methods for these tests. This goes slightly beyond the explicit information but is a reasonable expert inference.

# Group 70

This group was rich in different test types, from standard chemistry (Calprotectin, Bile Acids) and TDM (Carbamazepine, Valproate) to serology, allergy testing, and histology. The presence of `LongName` for many rows was extremely helpful for confirmation, especially for the allergy tests (e.g., confirming `s-haspähe` is Hazelnut IgE) and histology (`sk-padihot`).

The main challenges were:
1.  **Ambiguous abbreviations**: Codes like `s-maksa1`, `s-maksa2` were ambiguous. I inferred they were alkaline phosphatase isoenzymes based on sibling rows `s-afmaksa`, but this is a guess. `p-varmtr` and `p-varmtt` were inferred as Thrombin Time and PT%, which seems plausible but isn't certain.
2.  **Panel vs. Specific Test**: Differentiating panels from specific tests with multiple reporting formats was tricky. For example, `s-kardab` (Cardiolipin Ab) has a `titre` row and a high `p_missing` row, but it's an orderable that bundles IgG and IgM. I marked it as a panel. Conversely, for a specific test like `s-kardabg` (IgG only), the multiple rows represent different ways of reporting (quantitative vs. qualitative), not a panel.
3.  **Local/Handling Codes**: Many codes like `s-pakaste` (frozen), `b-vara` (reserve), or `u-valvott` (supervised) are clearly not actual tests but sample handling instructions or placeholders. It's important to recognize and map these to empty axes rather than trying to force an interpretation.
4.  **Unit Diversity**: For serology tests like Parvovirus IgG Ab (`s-parvabg`), there were many different arbitrary units (`eiu`, `ie/ml`, `index`, `iu/ml`, `titre`). This highlights the lack of standardization and reinforces the need to use `Arbitrary Concentration` or `Titer` as the property, and not to assume they are equivalent. It also shows the value of having `p_missing` to identify the qualitative versions of these tests.

# Group 73

This group was characterized by nucleic acid amplification tests for various respiratory viruses. The `-nho` suffix was a very strong and consistent indicator of the method ('nukleiinihappo', nucleic acid), scale ('Ord'), and property ('Presence or Threshold'), especially when combined with the `(kval)` in the `LongName` and 100% missing numeric values.

The main challenges were:
1.  **System/Specimen:** No prefixes were available to determine the specimen type. While these are almost certainly from respiratory specimens like nasopharyngeal swabs, the data provided does not confirm this, so the `has_system` axis was correctly left empty.
2.  **Panel vs. Single Test:** Codes like `-inabnho` (Influenza A and B) and `-inabrsnho` (Influenza A, B, and RSV) clearly represent multiplex tests that are best modeled as panels. The `LongName` for `-inabnho` ("Influenssa A ja B-virus") confirmed this. This distinction is crucial.
3.  **Typos and Ambiguity:** Several codes were obvious typos (e.g., `-inabnhoho`, `-hinfnho`, `-tintnho`). For those with no `LongName`, the component was left empty. The code `hinflnho` (row 5794) was ambiguous: it could be a typo for `infanho` (Influenza A) given the viral context, or it could be for *Haemophilus influenzae*. I opted for the latter as it's a valid abbreviation, but it's a low-confidence guess. The grouping of similar codes was very helpful in identifying these patterns and typos.

# Group 74

This group was uniformly composed of qualitative nucleic acid tests, identifiable by the `-nho` suffix, the `LongName` containing "nukleiinihappo (kval)", and the 100% missing numeric values. This made assigning `Property: Presence or Threshold`, `Scale: Ord`, and `Method: Nucleic acid amplification with probe detection` straightforward for all rows.

The main ambiguities arose from missing `LongName`s and non-standard abbreviations:
*   **Typos/variants:** `bocanho` (5807) was clearly a typo of `bokanho` (5808), which was easy to resolve due to the grouping. `bopanho` (5809) was more ambiguous, likely a variant of `bopenho` or `bparanho`; I mapped it to the more general `Bordetella` to be safe.
*   **Combined tests:** `boppnho` (5812) was inferred to be a combined test for *Bordetella pertussis* and *parapertussis*. This is an educated guess based on the abbreviation, but such multi-pathogen tests are common.
*   **Unspecified systems:** Many codes lack a system prefix (e.g., `-aspenho`, `baktnho`). Others have suggestive but non-standard prefixes like `res-` in `resbaktnho` (5829), likely for a respiratory sample, but this cannot be mapped to a specific LOINC system without more information.
*   **Component specificity:** For `s-parvnho` (5830), I specified `Parvovirus B19` as this is the overwhelming clinical context, even though the `LongName` only says `Parvovirus`.

Having a more comprehensive list of both standard and common local abbreviations would significantly improve accuracy, especially for resolving ambiguous or combined-analyte codes.

# Group 79

This group was mostly straightforward, focusing on albumin, protein, and their creatinine ratios in urine, along with urine sediment analysis. However, a few ambiguities and data quality issues stood out:

*   **Ambiguous Component:** The code `u-a1mikre` (row 6259) was the most challenging. While grouped with albumin tests by string similarity, `a1m` is a standard abbreviation for Alpha-1-microglobulin. I chose the more literal interpretation (`Alpha-1-microglobulin/Creatinine`), but the grouping and similar decile ranges to albumin/creatinine ratios create significant ambiguity. This could be a local typo for an albumin ratio.
*   **Concatenated Codes:** Codes like `u-alb/kre,u-alb` (6271) and especially `u-alb/kre,u-krea` (6274) are messy. For 6274, I had to use the decile values to infer that the result was likely for creatinine alone, not the ratio, contradicting the first part of the code. This shows that concatenated codes can be misleading.
*   **Uninterpretable Codes:** The `u-alvhu...` series (6284-6286) was completely unmappable ('dark matter'), with no clues from any column. I had to leave most axes blank.
*   **Data Inconsistencies:** The presence of deciles for rows with 100% missing numeric values (e.g., 6251, 6258) is confusing and suggests an artifact in the data aggregation pipeline. Similarly, the nonsensical unit `mg/mmol/l` (6282) required an educated guess based on the test name `u-albkrea` indicating a ratio.

# Group 84

This group was unusual as it contained no analytical laboratory tests. All codes referred to pre-analytical or administrative procedures, primarily 'näytteenotto' (sample collection) and its variants. The high `p_missing` values across the board confirmed that these are not quantitative measurements.

The main challenge was mapping these procedural concepts to the LOINC axes. I consistently used components like `Specimen collection` with the property `Finding` (to indicate the action was performed) and system `^Patient`. For codes describing the *method* of collection (`ottotapa`), I used the component `Specimen collection method` and property `Type`.

A significant ambiguity was row 6675 (`ottotapa`), which had numeric deciles and a unit of `h` (hours), contradicting its name which means 'collection method'. I judged the name to be the more reliable clue, interpreting the numeric values as codes for a categorical method. I therefore mapped it to an `Ord` scale and considered the unit `h` a data entry error. The alternative, mapping it as a quantitative time measurement, seemed less likely given the context of the entire group.

Purely administrative codes referencing specific hospital departments (`notto,tyks`, `nottopkl`) were unmappable to a general clinical model and were correctly left blank. This highlights the presence of location-specific identifiers mixed in with more general procedure codes.

# Group 85

This group was a mix of clearly defined chemical tests and highly ambiguous or unspecific codes. 

**Gotchas and Ambiguities:**
*   Codes like `-aerobivi`, `projekti1`, and `annosvoim` are very difficult to interpret without broader context. The leading hyphen in `-aerobivi` suggests it's part of another test, but what that test is remains unknown. `projekti` is clearly a placeholder.
*   The `ctgc` suffix (`-omactgc`, `hpvpapctgc`) is a recurring unknown. Documenting such local suffixes would be highly beneficial; it likely indicates a specific molecular test panel (e.g., for Chlamydia/Gonorrhea, which would resolve `-omactgc`).
*   The test `cladosp.he` (row 6687) with unit `mm` was a great puzzle. Recognizing `Cladosporium` as an allergen led to the hypothesis of a skin prick test, where `mm` measures the wheal diameter. This correctly changes the `has_property` to `Length` and `has_system` to `^Patient`, a completely different interpretation from the serum antibody test in row 6688. The `UNIT` column was indispensable here.

**Data Strengths:**
*   The presence of both quantitative (with `UNIT` and `deciles`) and qualitative/narrative (high `p_missing`, no `UNIT`) variants for the same analyte (`asetoni`, `uraatti`, `valproaatti`) is a powerful pattern. It confirms the component and system, and allows for confident mapping of both versions.
*   The `LongName` for `ts-abortti` was crucial. It identified the code not as a simple lab test but as a pathology dissection report, leading to a more appropriate mapping (`Gross findings`, `Finding` property, `Nar` scale).
*   The `prefix_meaning` column is consistently useful for determining the `has_system` axis.

# Group 89

This group consists almost entirely of screening tests (`seulonta`). The main challenge was distinguishing between codes representing a panel order versus a single test result.

*   **Panel vs. Single Test:** Most codes with `seul` (screening) and `p_missing` near 100% were identified as panels (e.g., prenatal screening `s-tr1seul`, urine chemical screen `u-kemseul`, donor screening `luov.seul.`). This is a critical distinction as panel codes should have most axes empty.
*   **Data Quality Gotcha:** The most significant finding was in row 7037 (`u-kemseul`). The metadata showed `p_missing=100` (suggesting no numeric results), but also provided `deciles`. The deciles `[...1.01, 1.02...4.17...]` were a perfect match for urine specific gravity readings from a dipstick, assuming a typo in the `p_missing` value. This allowed me to map this row to a specific component (`Specific gravity`) of the `U-Kemseul` panel, while all other `u-kemseul` rows represent the panel itself. This highlights the need to cross-validate all provided data points, as a single column can be misleading.
*   **Ambiguity:** Some codes like `hoikemseul` and `hörsel` were too abbreviated or misspelled to be interpreted confidently and were left unmapped.
*   **Context is Key:** The grouping of similar codes was essential. For example, `s-äit-seul`, `s-äit-seula`, and `s-äitseul` were clearly variants of the same maternal screening panel. `oma-u-kemseul` clarified that `oma-kemseu` was also a urine test.

# Group 105

This group was a textbook example of panel-component ambiguity, where results for individual components of a blood count are reported under the code for the parent panel. The grouping of rows was extremely helpful. Seeing `b-pvk`, `b-pvk+t`, `b-pvk+tkd` followed by the explicit components like `b-pvk+tkd,hb` made it possible to confidently infer the components for the ambiguous rows by comparing units and decile distributions.

Gotchas included:
1.  Distinguishing components with the same unit: `g/l` can be Hemoglobin or MCHC, and `e9/l` can be Leukocytes or Platelets. The `deciles` column was essential for disambiguation.
2.  Distinguishing properties for the same unit: `%` is used for `Number Fraction` (leukocyte diffs) and `Ratio` (RDW-CV). The component identity determines the property.
3.  The unit `osuus` means 'fraction' and corresponds to Hematocrit with property `Volume Fraction`.
4.  A significant number of rows represent panel orders, identifiable by high `p_missing`, no units, or a unit of `paketti` (package). These are correctly mapped as `is_panel: true` with empty axes.
5.  Many test codes are concatenated or truncated (`b-pvkt`, `b-pvktkdr`), but their high `p_missing` rate confirms they are used as panel order codes.

This exercise highlights the importance of having `deciles` to interpret quantitative results correctly when the test code itself is ambiguous.

# Group 106

This group was centered on bacteriology tests (`Bakteeri`). The main challenge was distinguishing between the many different types of tests hiding under similar names, especially in the large `U-Bakt` (Urine Bacteria) section.

**Gotchas and Ambiguities:**
*   **Qualitative vs. Quantitative Cultures:** The code `U-BaktVi` (urine culture) appeared in multiple rows with conflicting data. Some had 100% missing values (implying nominal results like 'E. coli' or 'No growth'), while others had deciles suggesting quantitative colony counts (CFU/mL). Row 8716, with 99.99% `p_missing` but also deciles, was a perfect candidate for the `OrdQn` scale. The presence of a unit like `e6/l` on a culture test (`-vi`) is strange; `e6/l` typically indicates a flow cytometry particle count, whereas cultures yield CFU. I interpreted this as a local convention for reporting quantitative culture results.
*   **Panels:** The `LongName` was essential for identifying panels. `F-BaktVi1`, `F-BaktVi2`, and `F-BaktVi3` were clearly described as bundles of specific pathogens. `Pu-BaktVi1` (aerobic + anaerobic culture) was also identified as a panel. Without the `LongName`, this would have been a guess.
*   **Conflicting Information:** For `Pp-BaktNh` (row 8681), the `LongName` indicated a quantitative test, but `p_missing` was 100%. I trusted the observed data over the name, mapping it as qualitative (`Nom`). This highlights the importance of using all available columns to cross-validate.
*   **Method Inference:** For common tests like a vaginal or CSF stain (`-vr`), inferring `Gram stain` felt safe. For urine bacteria counts (`U-Bakt` with low `p_missing`), `Automated count` (flow cytometry) is the modern standard. For qualitative stick tests, `Test strip` is appropriate. For others, leaving Method empty was the safer choice.

**Improvements:**
*   More reliable `p_missing` calculation would be very helpful. In row 8691, `p_missing` was 100% despite the `deciles` field being populated, suggesting that non-numeric text results might not have been correctly accounted for when calculating missingness. Distinguishing between NULL and text would clarify whether a test is `Nar`/`Nom` or simply has missing data.

# Group 110

This group was overwhelmingly composed of immunophenotyping (flow cytometry) results for lymphocyte subsets. The structure of the local codes was quite consistent, which helped interpretation. The pattern `<system>-<parent population>-<marker>` allowed for detailed component naming, for example differentiating between absolute counts in blood (`B-T-CD4`) and fractional counts of lymphocytes (`Ly-T-CD4`).

The main ambiguities were the non-standard prefixes `La-` and `So-`. For `La-`, the unit `e6/kg` on row 9039 was a crucial clue, strongly suggesting a leukapheresis product for stem cell transplantation and pointing to `^Patient` as the system. For other `La-` codes, I left the system empty as the specimen type (e.g., the apheresis bag) does not have a standard OMOP representation. The `So-` prefix remains unknown.

There were several data quality issues. For example, row 9080 had `p_missing=100` but also a full set of `deciles`, and row 9030 had no unit but deciles that clearly matched the `e9/l` unit of its sibling row. I used the deciles to override the `p_missing` or missing `UNIT` information in these cases, which felt like the correct interpretation. The `S-GT-CDT` code was likely a typo or local variant for `S-CDT-T`, which could be confirmed with access to a more comprehensive code mapping table.

# Group 111

This group was dominated by COVID-19 related tests, identifiable by abbreviations like `cv19`, `ag` (antigen), `ab` (antibody), and `nho` (nucleic acid, qualitative). A key challenge was handling rows for antigen tests (`-cv19ag`, rows 9096-9105) that listed nonsensical quantitative units (`g/l`, `mmol/l`). Given the high `p_missing` on the main variant (row 9106) and the nature of these tests, I classified them all as qualitative (`Ord`) with a `Presence or Threshold` property, treating the units as data source errors.

The `LongName` field was very helpful, for example, confirming that `-cv19ag` with numeric suffixes (e.g., `-cv19ag0`) referred to specific manufacturer kits, and that `S-cv19sab` was indeed a spike protein antibody test. The code `cv19sekv` was a strong hint for sequencing, allowing for a more specific mapping (`Nom` scale, `Molecular genetics` method). 

Spotting the outlier `p-c1qabg` (rows 9129-9130), a Complement C1q antibody test mistakenly grouped by string similarity, was crucial and highlighted the need to evaluate each row on its own merits without over-relying on the group's theme. Finally, the recurring pattern of a test appearing in both quantitative (`Qn` with units/deciles) and qualitative (`Ord` with no unit and high `p_missing`) forms was prominent and required careful distinction.

# Group 121

This group was dominated by molecular genetics tests, identifiable by the `-d` (DNA test) suffix, methods like `pcr` and `fish` in the name, and explicit `LongName`s. The high `p_missing` values (100%) were key to identifying these as qualitative (`Ord`), nominal (`Nom`), or narrative (`Nar`) tests, even when the name suggested quantitation.

Key ambiguities:
1.  **`Qn` vs. `Nar`**: For tests like `b-bcr-qr` (quantitative BCR-ABL), the `LongName` and `TEST_NAME` suffix (`qr`, `kvant`) strongly imply `Qn` scale and a `Number Ratio` property, despite `p_missing` being 100%. This is a common real-world data issue where non-detected results are not stored as numeric zeros. I chose to trust the test's intent and map it as `Qn`.
2.  **`Nom` vs. `Nar`**: For genetic tests, I used `Nom` for simple genotyping (e.g., Factor V Leiden, Apolipoprotein E) where the result is one of a few categories. I used `Nar` for tests involving sequencing or screening for multiple unknown mutations (e.g., `b-brcay-d`, `b-ldlre-d`), as the result is a complex descriptive report.
3.  **Panels vs. Single Tests**: Codes like `b-farma-d` (pharmacogenetics), `b-fvfii-d` (Factor V & II), and `b-ngs-d` (Next-Gen Sequencing) were identified as panels because they bundle multiple distinct analytes. The `LongName` was decisive for some, like `b-varfa-d` (VKORC1 and CYP2C9). `bl-bal-1` (cell study) was also classed as a panel as it implies a differential count.
4.  **Opaque Codes**: Several codes like `b-aso2-qd` and `b-auria10` remained opaque. `Auria` points to a biobank, so I classified `b-auria10` as a probable panel/study code. `aso2-qd` was uninterpretable without further context.

# Group 126

This group predominantly features glucose measurements, many of which are part of a glucose challenge test (indicated by suffixes `-r`, `-bel`, `-ras` and timings like `0min`, `1h`, `2h`). A key challenge was the almost complete absence of system prefixes (like `P-` or `B-`), which prevented the assignment of the `has_system` axis for most rows. The exceptions were point-of-care tests (`vieri`), where `Blood capillary` is a safe inference for the system and `Test strip` for the method.

The codes `-gluk-tbr` and `-gluk-tir` were unmappable due to non-standard suffixes and no associated `LongName`. I could infer `Mass Fraction` from the `%` unit but not the `has_component`.

Data quality issues like missing units were common, but the `deciles` column was invaluable for confidently inferring `Substance Concentration` from the value distribution. The `p_missing` rate was a critical indicator; a 100% rate for codes with `valm` (preparation) suffix strongly suggested they were narrative status codes about the patient (`System: ^Patient`, `Scale: Nar`), not specimen results.

# Group 129

This group was composed entirely of patient-level investigations (`Pt-` prefix), which are almost always panels or complex procedures. The key was recognizing abbreviations for common procedures: `spiro` for spirometry, `sper` for semen analysis (confirmed by `LongName`), `sydänuä` for echocardiogram, and `st-temp` for thermal threshold test. This allowed me to confidently mark most rows as `is_panel: true` and assign a generic component name for the panel (e.g., "Spirometry study"). The `has_system` was consistently `^Patient`.

The main ambiguity was the meaning of the many suffixes on the `spiro` codes (e.g., `-id`, `-idl`, `-ido`). Without `LongName`s for these specific variants, I couldn't differentiate them further, but the general classification as a spirometry panel holds. The presence of `UNIT` = 'form' on some rows (10842, 10848) and 100% missing values for most supported the interpretation that these codes represent the entire report/document (`has_scale_type: Doc`), not a single numeric value.

# Group 160

This was a straightforward group covering three common liver enzymes: Alanine aminotransferase (ALT), Aspartate aminotransferase (AST), and Gamma-glutamyl transferase (GGT). The `U/l` unit made identifying the property as `Catalytic Concentration` easy.

**Gotchas and Ambiguities:**
*   **Ambiguous System:** For rows without a system prefix (e.g., 12996, 13000), I inferred the system as `Serum or Plasma`. This is a safe and informative choice because the group contains explicit `P-` (Plasma) and `S-` (Serum) variants, indicating the unprefixed version is likely used ambiguously in source systems.
*   **Data Quality vs. Scale:** The main challenge was interpreting rows like 13007, 13009, and 13015, which lacked a `UNIT` but had `deciles` and high `p_missing`. The presence of deciles is definitive proof that the test is fundamentally quantitative (`Qn`). The high percentage of missing numeric values points to data quality issues (e.g., results recorded as text like 'Cancelled' or 'Hemolyzed') rather than the test being narrative. I correctly classified these as `Qn` and inferred the property from sibling rows.
*   **Explicit System in Name:** Row 12998 (`alaniiniaminotransferaasi,plasmasta`) provided a useful confirmation, where the system was spelled out in the name itself, reinforcing the value of parsing the full test name.

**Suggestions for Improvement:**
To better distinguish true narrative results from data quality problems, it would be invaluable to have a sample of the non-numeric values for rows with high `p_missing`.

# Group 161

This group highlighted several interesting challenges. The distinction between monounsaturated (`kertatyydyttymätön`) and polyunsaturated (`monityydyttymätön`) fatty acids was a key linguistic point requiring specific Finnish knowledge. The main difficulty was interpreting the `p_missing` and `deciles` columns to assign a `has_scale_type`. I used a tiered logic: `Qn` for records with low `p_missing`, `OrdQn` for those with high `p_missing` but available `deciles` (like rows 13018, 13028), and `Ord` or `Nar` for records with very high or 100% `p_missing` and no deciles. This shows that a single test concept can have multiple result reporting patterns in the wild. Additionally, some codes like `p-omagluk,,potilasmittaringlukoosi` (13049) contained contradictory information (`p-` for plasma vs. `potilasmittari` for capillary blood), forcing an interpretation of which part of the string was more likely to be correct versus a data entry error. Lastly, identifying patient self-monitoring methods (`ihopisto`, `sensori`) and mapping them to appropriate LOINC systems (`Blood capillary`, `^Patient`) and methods (`Test strip`, `Continuous glucose monitoring`) was a key step.

# Group 162

This group was characterized by a high number of common chemistry and hematology tests, often with many variations in naming (`alkalinenfosfataasi`, `punasolujen kokojakauma`). Seeing the same test with different prefixes (e.g., `ab-`, `cb-`, `vb-`, `p-` for bicarbonates) and with/without a prefix was helpful for confirming the component and highlighting the importance of the system.

An ambiguity arose with `P-Urea, resirkulaatio` (13138), where the name suggests a ratio ('recirculation') but the unit (`mmol/l`) and values indicate a concentration. I mapped it as a Urea concentration, assuming the name refers to the *purpose* of the measurement (to calculate recirculation) rather than the reported quantity itself. This is a common source of confusion in source data.

Another subtle point was with the leukocyte differential counts (13115-13122). The `L-` prefix (`prefix_meaning`: Leukocyte) refers to the category of the component, but the correct LOINC system is `White Blood Cells`, not `Blood`. This is a convention that needs to be known.

The `(fe-folaat)` hint in the name for Folate (13094) was crucial. Without it, the very high deciles would have been puzzling. Cross-referencing deciles with typical reference ranges for different specimen types (serum vs. erythrocyte folate) proved to be a valuable sanity check.

# Group 167

This group was dominated by component tests (`osatutkimus`), which made it straightforward to set `is_panel` to `false`. The parenthetical information, such as `osatutkimus(b-diffi)` or `osatutkimus s-prot-fr`, was extremely helpful in determining the context (e.g., automated differential count, protein electrophoresis) and thus the correct method (`Automated count`, `Electrophoresis`).

The main ambiguities arose from different ways of specifying the same test. For instance, neutrophil counts appeared as `b-neut`, `l-neut`, and `neutrofiiliset,konediffi()`. Distinguishing between absolute (`e9/l`, `Number Concentration`) and relative (`%`, `Number Fraction`) counts was crucial and required looking at both the `UNIT` and sometimes clues in the name like `absol.arvot` (absolute values). The prefixes `B-` (Blood), `E-` (Erythrocyte), and `L-` (Leukocyte) were key to assigning the correct `has_system`.

The M-component tests (`s-m-komponentti`) were interesting, with `valetietue` ("dummy record") in the name. The mix of quantitative (`g/l`) and narrative (`p_missing`=100%) rows for the same component suggests a pattern where a numeric value is given if an M-protein band is found, and a narrative/empty result otherwise. This pattern of paired quantitative/narrative rows for the same test is common and was handled by assigning `Qn` or `Nar` scale types accordingly.

