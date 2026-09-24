# Group 7

This group was straightforward, centered on tissue transglutaminase (tTG) antibodies. The main distinctions were between IgA and IgG isotypes, and between quantitative (`Qn`, `Arbitrary Concentration`, `U/ml`) and qualitative (`Ord`, `Presence or Threshold`) results. The presence of both a quantitative and a qualitative version for the same test name (e.g., rows 364/365, 376/377) is a common pattern, likely representing the order code (qualitative) and the result code (quantitative). A key gotcha was deciding on the system for rows without an 'S-' prefix or 'seerumista'. I correctly left the system empty as per instructions, even though serum is the standard specimen. The terms `(keliakia)` and `osatutk` were contextual and did not indicate a panel code, but rather a single test as part of a larger clinical investigation. The `LongName` column being empty for all rows was unhelpful; having it populated would have confirmed the component and possibly clarified the unspecified immunoglobulin class in rows 384-385.

# Group 14

This group consists entirely of variations of C-reactive protein (CRP) tests. The main challenges were handling numerous local naming conventions and data quality issues.

**Ambiguities & Gotchas:**
*   A significant conflict occurred with test names containing `(kval)` (e.g., row 1016), suggesting a qualitative test, while the associated data (`UNIT` of `mg/l` and numeric `deciles`) were clearly quantitative. I prioritized the quantitative data over the name fragment, inferring that `(kval)` was a misleading local convention.
*   The prefix `cp-` combined with `ihopiston` (skin prick) in the name (row 1008) strongly implied a capillary blood sample, which I mapped to `Blood capillary`. This is an inference, as `cp-` is not a standard national prefix.
*   Qualifiers like "pika" (rapid), "vieritesti" (point-of-care), and "herkkä" (sensitive) were mapped to methods (`Rapid immunoassay` and `Immunoassay`). This adds valuable detail that distinguishes the tests, which is appropriate for LOINC mapping.

**Data Quality Issues:**
*   There were several data quality problems: typos (`resktiivinen`), uninformative units (`1`), and contradictory metadata (row 1001 had `p_missing: 100` but also a full set of `deciles`). In these cases, I relied on context from sibling rows and trusted the `deciles` data when present.

**Process Improvements:**
*   Providing the official `LongName` for every code would be extremely helpful, especially to resolve conflicts like the `(kval)` issue.
*   A glossary of non-standard prefixes and local abbreviations encountered in the source data (like `cp-`) would improve mapping accuracy.

# Group 20

This group contained two distinct types of tests: various ECG recordings and microbiological pathogen detections. The ECG tests were mostly variations of a 12-lead resting ECG, where additional text described the context (e.g., 'patient-taken', 'includes computer analysis') rather than the core test. I mapped these to a single concept for the study ('EKG study', `Doc` scale), adding 'with interpretation' to the method where specified. One ECG row (1296) with `UNIT`=1 was an exception, likely a flag for procedure completion, which I mapped to a `Nom` scale.

The microbiology tests were identifiable by pathogen name. The abbreviation 'nukl.haponos.' was a crucial clue for 'Nucleic acid amplification with probe detection'. I assumed the typo 'nho' was also an indicator for this method. The consistent `n` counts for the fecal and CSF pathogen groups strongly suggest they originate from multiplex PCR panels, confirming that each row represents a single component result (`is_panel: false`). The main limitation was the frequent absence of a specimen prefix (`F-`, `Li-`), which forced me to leave the `has_system` axis empty for several pathogen tests.

# Group 21

This group was straightforward as it contained only two distinct analytes: 'Transferrin.iron saturation' and 'Transferrin receptor.soluble'. The main ambiguities arose from missing or inconsistent data, which I handled as follows:

*   **Synonyms**: 'rautakyllästeisyys' and 'rautasaturaatio' were correctly identified as synonyms for iron saturation.
*   **Units**: Rows with `%` units and deciles 1-100 were clearly `Mass Fraction`. Sibling rows with no unit but deciles 0-1 were interpreted as the same test, just reported as a fraction instead of a percentage, mapping to the same `Mass Fraction` property. The unit `osuus` ('share'/'fraction') confirmed this interpretation.
*   **System**: I relied on prefixes (`fP-`, `fS-`, `P-`, `S-`) and explicit text (`seerumista` meaning 'from serum') to determine the system. When no information was present, I correctly left the `has_system` axis empty. The messy `TEST_NAME` in row 1319 was parsed by focusing on the primary prefix `p-`.
*   **Method**: For Transferrin Iron Saturation, I inferred the `Calculated` method, as this is standard practice and helps distinguish it from directly measured analytes. For Transferrin Receptor, I correctly left the method empty as per instructions, since it's not specified in the code.
*   **Panels**: The Finnish word `paketti` in the unit column for row 1327 was a clear and helpful signal to mark it as a panel.
*   **Data Quality**: Rows with `p_missing` at 100% were treated as instances of the test with no result data; component and system could often be inferred, but property and scale were left empty. For row 1312, with 84% missing values, I assigned `Nar` as the most likely scale.

# Group 33

This group contained a mix of microbiology cultures, drug screening panels, genetic tests, and physiological monitoring (ECG). The free-text but descriptive nature of the `TEST_NAME`s was essential for mapping.

**Gotchas and Ambiguities:**
*   **MRSA Cultures:** The terms 'viljely nenästä' (culture from nose), 'nielusta' (from throat), and 'perineumista' (from perineum) were key to identifying the `has_system` axis. The grouping of truncated versions (e.g., `...viljelyne`) with the full text was crucial for confirmation.
*   **Drug Screens:** The listing of multiple analytes in parentheses (e.g., `amfet, bents, opiaat...`) is a classic indicator of a panel (`is_panel: true`), for which component-level axes should be left empty.
*   **Genetic Test (1816):** The name "study of base changes...of predefined gene exons...by NGS method" is very generic. While I could infer `has_property: Finding`, `has_scale_type: Nar`, and `has_method: Molecular genetics`, the core `has_component` remains unknown ('predefined gene' is not a specific analyte). This is an inherent limitation when local codes are descriptive of a process rather than a specific target.
*   **ECG Holter:** The `Pt-` prefix was a clear signal for `has_system: ^Patient`. The time aspect was explicitly mentioned in the name ('24h'/'48h'), making it easy to map. These are good examples of non-specimen-based investigations.

# Group 34

This group covered microbiological tests for Streptococcus. The main challenge was handling truncated or prefix-less test names. For rows with missing prefixes (e.g., 1846, 1848, 1849), I adhered to the instruction to leave `has_system` empty, even though clinical context strongly implies a specific specimen (like throat for S. pyogenes). The presence of `nielusta` (from the throat) in row 1845 was crucial for assigning a system to an otherwise prefix-less code. The `prefix_meaning` column was essential for decoding `Ps-` as Pharyngeal secretion (`Throat`) and `Fl-` as Vaginal discharge (`Vaginal fluid`). Row 1847's `fluori` was a good example of a localism/typo that became clear through context from row 1834. I distinguished between culture (`viljely`), antigen (`antigeeni`), and nucleic acid (`nukleiinihappo`) tests, assigning methods and properties accordingly. For the vague term `osoituskoe` (detection test) in row 1850, I left the method empty as it's ambiguous between antigen and NAAT.

# Group 37

This group was extremely diverse, containing everything from administrative codes and technical placeholders to complex procedures, microbiology, point-of-care tests, and standard chemistry. The `TEST_NAME` fields were often long and descriptive, which was very helpful. Many codes lacked standard prefixes (like `S-` or `P-`), requiring inference or leaving the `has_system` axis blank.

A major gotcha was the presence of many administrative codes (e.g., `lisämaks...`, `lisävastaus...`, `hpv...apututkimus...`) that represent billing or data transfer actions rather than clinical measurements. These needed to be identified and left with empty axes. Similarly, many codes clearly represented panels or complex procedures (e.g., `täydellinenverenkuva`, `pt-` codes, histology, drug screens), which required setting `is_panel: true` and mapping at the procedure level rather than component level.

There were also inconsistencies, such as the `T-` prefix (for Thrombocytes) being used for lymphocyte subset tests (rows 1985, 1986), which required ignoring the prefix based on the component name. The unit for Creatinine in row 1945 was incorrectly listed as `mmol/l` when the deciles clearly indicated `umol/l`. Being able to use the deciles to correct for unit errors was crucial. Having the official `LongName` for more rows would have been beneficial for disambiguation, especially for the many panel/procedure codes.

# Group 42

This group was a very diverse mix of tests, from basic electrolytes (`Na`) to coagulation factors (`AT3`, `FV`, `FX`), hormones (`ACTH`), cardiac markers (`TnI`, `TnT`), and patient measurements (`PEF`).

**Gotchas and Ambiguities:**
*   **Prefixes:** `aP-` (arterial plasma) and `cP-` (capillary plasma) were inferred but aren't standard OMOP Systems. I mapped `aP-Lakt` to `Blood arterial` (row 2488), as this is a common sample for blood gas analyzers which report lactate, but for `aP-Na` I stayed with the safer `Plasma` (row 2493). This inconsistency reflects the ambiguity. A clearer rule for when to generalize a specific specimen type (arterial plasma) to its parent (plasma) vs. its source (arterial blood) would be helpful.
*   **Panels vs. Single tests:** Codes like `ap-nak`, `p-k+na`, `p-k-na`, `p-k,na`, `p-k/na` were clearly panels for Sodium and Potassium. It's interesting to see the many different local conventions for denoting a panel (`+`, `-`, `/`, or just concatenating abbreviations).
*   **Unusual Units:** `P-GT` in `mg/ml` (row 2533) is highly suspect for an enzyme usually measured by activity (`U/l`), especially given the tiny `n=8` compared to the `U/l` version with `n=820k`. I mapped it as `Mass Concentration` but it is almost certainly a data error. `ap-na` with units `%`, `kPa`, `°c` are also clear errors.
*   **Obscure Abbreviations:** `p-fs` (row 2527), `p-ked.` (2543), and `p-kjd.` (2544) were unidentifiable from the information given. I could only map the property based on the unit `s` for `p-fs`, but not the component.
*   **Suffixes:** The `pa` suffix on `p-k-pa` (2541) with a meaning of 'long-term' was confusing for a spot potassium test. I ignored it for the time aspect, assuming it's a local convention not reflected in LOINC's `has_time_aspect`.

# Group 43

This group contained many hormone and antibody tests, often with both quantitative/semi-quantitative (`titre`, `nmol/l`, etc.) and qualitative (no unit, `p_missing` >95%) variants, which is a common pattern. Correctly identifying these pairs was a key task. A few codes were highly ambiguous and likely represent panels (`fs-apot`, `s-kem`, `ts-res`); marking these as panels based on the vague name and 100% missing values is a reasonable inference. 

A recurring data quality issue was the contradiction between `p_missing=100` and the presence of `deciles` (e.g., rows 2723, 2730). In these cases, I trusted the `deciles` as definitive proof of a quantitative test, assuming the `p_missing` value was calculated incorrectly. The code `-ana` (row 2630) with a leading hyphen is a minor data entry anomaly, but the `LongName` resolved the ambiguity.

`S-ENA` (row 2703) was a tricky case: ENA is typically a panel, but the presence of deciles strongly suggests it was recorded as a quantitative screening test (e.g., a ratio result), so I mapped it as a single test rather than a panel.

# Group 44

This group was characterized by a large number of common chemistry tests, many of which had parallel entries for Serum (S-), Plasma (P-), Fasting Serum (fS-), and Fasting Plasma (fP-). The distinction between `Substance` property for 24-hour collections (unit `mmol`) and `Substance Concentration` for spot collections (unit `mmol/l`) was important. The `dU-` prefix was a clear indicator for `24 hours` time aspect.

A recurring pattern was a quantitative test row followed by a row for the same test with no unit and very high `p_missing`. I've consistently mapped these as `Nar` (Narrative) scale, assuming they capture non-numeric results, comments, or cancellations. The large number of urine drug screens (e.g., `U-AMP`, `U-BUP`) were straightforward to identify as qualitative (`Ord`, `Presence or Threshold`).

Ambiguities included:
*   Codes like `b-bio` or `s-bio`: Component is unknown, but the `B-` and `S-` prefixes at least give the system.
*   `p-fsl`: The unit `s` strongly suggests a time-based property, but the component is not identifiable from the abbreviation.
*   `vp-dop`: This is clearly a Doppler blood pressure measurement, but the source data's lack of numeric values (`p_missing` 100%) is strange for such a measurement. I mapped it based on its fundamental nature (`Qn`), but the data quality is suspect.

# Group 51

This group was dominated by microbiology antigen and antibody tests. The main challenges were:

1.  **Ambiguous System**: Many codes began with a `-` prefix, making the specimen system unknowable. These are likely respiratory samples like nasopharyngeal swabs, but this is an unprovable assumption. I have left the `has_system` axis empty as instructed.
2.  **Panels vs. Multiplex Tests**: Codes like `-infabag` (Influenza A+B) or `-infrsv` (Influenza+RSV) are ambiguous. They could be orderable panels bundling separate results, or single multiplex assays that detect multiple targets. I treated them as single tests with a combined component (e.g., `Influenza virus A+B antigen`), setting `is_panel` to `false`. In contrast, codes with `-pak` (package) or covering a broad category like `-rvirag` (respiratory viruses) were more clearly panels and I marked them as `is_panel: true`.
3.  **Data Contradiction**: Several rows (e.g., 3511, 3515) had `p_missing`=100% yet also had deciles. This common data quality issue suggests a field is used for both coded qualitative results (e.g., '1' for positive) and true quantitative values. Using the `OrdQn` scale is an effective way to represent this ambiguity. The property was inferred from sibling rows with clear units (`Ratio` or `Arbitrary Concentration`).
4.  **Obscure Abbreviations**: Some test codes like `-bokaag` (Bocavirus) or `-micfaeg` (Mycophenolic acid glucuronide) required educated guesses based on common microbiological or pharmacological terms. The presence of `LongName` for many rows was invaluable for confirming these interpretations.

# Group 68

This group was dominated by variations of a few common tests (Amylase, Alkaline phosphatase, Aldosterone) across different specimens and with minor spelling differences. The `LongName` and `prefix_meaning` columns were invaluable for resolving these.

Gotchas and Ambiguities:
*   Several codes (`s-aaldos`, `s-oaldos`, `s-valdos`) looked like Aldosterone (`aldos`) but had decile values that were orders of magnitude different from typical Aldosterone levels. Without a `LongName`, the true component remains unknown, forcing me to either make a questionable guess or leave the component empty. I've noted the discrepancy in my thinking but mapped them as Aldosterone for some, and left others empty where values were too extreme.
*   The distinction between a panel code and a result code was sometimes blurry. Codes ending in `-is` (isoenzymes) or clearly referring to multiple analytes (`s-adalipa`) were identified as panels. Some of these panel codes paradoxically had quantitative results attached (`S-AFOS-IS` with `U/L`), likely due to source data entry errors. I classified these as panels regardless.
*   A significant number of rows had `p_missing` near 100% but also had a full set of `deciles`. This is a recurring data quality issue. My approach is to trust the `deciles` and map the test as quantitative (`Qn`) with the property suggested by the sibling rows' units. The `p_missing` value seems unreliable in these cases.
*   For protein electrophoresis fractions (`s-alfa-1`), I explicitly added `Electrophoresis` as the method, as it's fundamental to the interpretation of these tests.
*   Row 5351 (`s-dmklots` with no unit) had bimodal deciles, suggesting results from two different units (nmol/L and umol/L) were combined. This makes it impossible to assign a single valid property, so I left it blank.

# Group 70

This group was characterized by a large number of specific antibody tests (Cardiolipin, various allergens), therapeutic drug monitoring (Carbamazepine, Valproate), and administrative or panel codes. The `LongName` field was invaluable for resolving abbreviations like `s-kardabg` and `s-maapähe`.

**Gotchas & Ambiguities:**
*   A significant number of codes were administrative (e.g., `b-vara`, `s-pakaste`), indicated by terms like `vara` (reservation) or `pakaste` (frozen). Identifying these as non-tests is crucial.
*   Many codes were clearly panels (`paketti`), such as `s-makspak` (liver panel) or `u-partik` (urine sediment/particles). These are correctly marked as `is_panel: true` with most axes left blank.
*   The distinction between quantitative (`Qn`) and qualitative/narrative (`Ord`/`Nar`) versions of the same test was very common, usually differentiated by the presence of a unit and a low `p_missing` versus no unit and a high `p_missing`. However, several rows (e.g., 5464, 5470) had contradictory data: `p_missing` of 100% but `deciles` present. In these cases, I trusted the `p_missing` and lack of unit to indicate a non-quantitative result (`Nar` or `Ord`).
*   Some abbreviations were very obscure (`b-nakkrea`, `u-rakkoai`) and could not be mapped without a `LongName` or more context. I left the component empty in these cases.
*   The same analyte could appear under slightly different abbreviations (e.g., `s-parapäe` and `s-parpäh` for Brazil nut), highlighting the need for robust synonym matching.

# Group 73

This group was characterized by nucleic acid tests for respiratory viruses. The suffix `-nho` was a consistent and reliable indicator of a qualitative (`-O`) nucleic acid (`-Nh`) test, making it easy to infer the `has_property` (Presence or Threshold), `has_scale_type` (Ord), and `has_method` (Nucleic acid amplification with probe detection).

The main challenge was the complete absence of specimen prefixes (`has_system`), with many codes starting with a hyphen. This is a significant data gap, as the specimen (e.g., Nasopharyngeal swab, Bronchoalveolar lavage) is clinically important. I correctly left `has_system` empty as per instructions.

Several codes were clearly typos (`-inabnhoho`, `hinfnho`), but the grouping and `LongName` entries for similar codes made them easy to resolve. A few codes (`-hinnho`, `-tintnho`) were too ambiguous to map a component. The code `-inabrsnho` was confidently identified as a panel for Influenza A, B, and RSV, a common respiratory panel, which highlights the need to recognize multi-analyte abbreviations.

# Group 74

This group was characterized by the `-nho` suffix, a consistent and strong indicator for a qualitative nucleic acid test. This made assigning Property (`Presence or Threshold`), Scale (`Ord`), and Method (`Nucleic acid amplification with probe detection`) straightforward and consistent across the group, an interpretation confirmed by the available `LongName`s (`nukleiinihappo (kval)`) and the 100% `p_missing` values.

The main challenges were:
1.  **Ambiguous abbreviations**: The code `-bopanho` (row 5809) could not be confidently resolved to an analyte as it could be a typo for either pertussis (`bopenho`) or parapertussis (`bparnho`), so its component was left empty. In contrast, `-boppnho` (row 5812) was interpreted as a combined test for `Bordetella pertussis+parapertussis` based on common microbiology test panels.
2.  **Panel identification**: Tests for broad categories like 'Parasites' (`f-paranho`), 'Respiratory bacteria' (`resbaktnho`), or 'Bacteria' (`-rbaktnho`) are likely multiplex panels. I have marked them as `is_panel: true`. This is an inference based on the plural nature of the component, as the data doesn't explicitly distinguish between a multiplex panel order and a multiplex test reporting a single combined finding.
3.  **Missing systems**: A large number of tests, particularly the coronavirus strains, lacked a system prefix. While they are almost certainly from respiratory specimens, this cannot be proven from the data, so the `has_system` axis was correctly left empty. Non-standard prefixes like `res-` and `r-` strongly suggest a respiratory system, but without a formal mapping, it is safer to omit the system.

# Group 79

This group was mostly focused on urine albumin, creatinine, and their ratio, along with other urine tests. The prefixes `cU-` (collected urine) and `nU-` (night urine) were crucial for determining the `has_time_aspect`. For `cU-` with unit `ug/min`, I inferred a `Mass Rate` property but couldn't specify a duration. For `nU-`, `Night time` seemed appropriate. The various spellings for albumin/creatinine ratio (`-kre`, `-krea`, `/kre`) were easy to normalize, especially with the `LongName` confirming the meaning for `u-albkre`.

The most ambiguous cases were the concatenated `TEST_NAME`s like `u-alb/kre,u-alb`. Here, the `deciles` were the only way to disambiguate. For example, in row 6271 the deciles matched an albumin concentration, not a ratio. This reliance on numeric distributions is powerful but also brittle if the data is sparse. The `u-alvhu...` codes were uninterpretable and correctly left mostly blank.

A slight ambiguity arose with qualitative urine tests (`u-alb-o`). While the `-O` suffix clearly points to an ordinal test, the method is almost always a test strip. I added `Test strip` as the method, which is a slight violation of the 'only when specified' rule, but highly probable and clinically relevant. For the `u-sakka` (sediment) tests, I inferred `Number Concentration` and `SemiQn` from the context of microscopy counts per field, which seems reasonable.

# Group 84

This group was composed almost entirely of procedural or administrative codes related to sample collection (`näytteenotto`), handling (`käsittely`), or transport (`kuljetus`). The key was recognizing this from the Finnish terms and the universal lack of units and numeric values (`p_missing`≈100%). These codes represent events or actions, not measurements. The appropriate LOINC mapping for such concepts often uses `Finding` or `Type` as the property and `Nar` as the scale, which I've applied consistently. The one significant anomaly was row 6675 (`ottotapa`), which, despite its name meaning 'collection method', had quantitative data with the unit 'h' (hours). I inferred this to be a measurement of time associated with the collection, likely mislabeled. Its sibling row 6676 with the same name but no data confirmed the expected narrative nature of `ottotapa`, strengthening the case that row 6675 is an exception. Having `LongName`s from the national codebook would have been unhelpful here, as these are clearly local/administrative codes.

# Group 85

This group contained a wide variety of test types, including standard chemistry, microbiology, allergy testing, and molecular diagnostics. The presence of sibling rows with and without units (e.g., `p-uraatti`) was a very strong and useful pattern for distinguishing quantitative (`Qn`) from qualitative/narrative (`Ord`/`Nar`) versions of the same test. The `cladosp.he` triplet (rows 6687-6689) was a perfect example of a single allergen being tested in three completely different ways (skin prick, quantitative IgE, qualitative IgE), requiring careful attention to units and context to assign the correct property and system. The most ambiguous codes were those with the `-ctgc` suffix (`u-omactgc`, `hpvpapctgc`). While `ctgc` strongly suggests a nucleic acid test, possibly for Chlamydia/Gonorrhea, `u-omactgc` was too opaque and had 100% missing values, making it safer to classify as a panel. For the `corona` and `hpv` tests, I had to infer the system (`Respiratory specimen`, `Cervical specimen`) from common clinical practice, which is a calculated risk but likely correct. Finally, `ts-abortti` was clearly a pathology procedure, best mapped as a narrative finding from a dissection, rather than a standard lab test.

# Group 89

This group consisted almost entirely of screening tests, identifiable by the `seul` or `seula` morpheme. The primary challenge was determining whether a screening code represented a single test or a panel. For most, such as maternal screening (`s-äit-seul`, `s-tr1seul`) and urine chemical screening (`u-kemseul`), 'panel' was the obvious interpretation. The `LongName` and prefixes (`S-`, `U-`) were invaluable for confirming these interpretations.

There were several data quality issues and ambiguities. Row 7037 (`u-kemseul`) presented a contradiction, showing 100% missing values but also providing deciles. The decile values (e.g., `1.02`, `5.87`) strongly suggest that results for individual components of the urine dipstick panel (like specific gravity and pH) are being stored under the panel's code. While I mapped the code itself as a panel, this points to a common data practice that complicates analysis. Codes like `hoikemseul` (7015) were uninterpretable due to their obscurity. Finally, non-laboratory tests like hearing (`hörsel`) and vision (`näköseula`) screening required mapping to the `^Patient` system, which was an inference based on the test name.

# Group 105

This group, centered on Finnish blood count panels (`B-PVK`, `B-TVK`), exemplifies the challenge of mapping panel codes. The key was distinguishing between rows representing the panel order itself versus rows representing individual component results reported under the panel code.

**Gotchas and Ambiguities:**
*   **Panel vs. Component:** A very large number of rows had `p_missing` = 100% or a unit of `paketti`. These were clearly panel orders (`is_panel: true`). Rows with numeric data under the same panel code were treated as individual components (`is_panel: false`), with the component inferred from the `UNIT` and `deciles` (e.g., `g/l` with deciles ~140 is Hemoglobin; `fl` is MCV).
*   **Ambiguous Components:** When a panel code was used with an ambiguous unit like `%` (e.g., row 8571), the component could not be determined with certainty, as it could be any of several leukocyte fractions.
*   **Unclear Units:** The unit `form` (rows 8561, 8578, 8643) is not standard and its meaning could not be determined.
*   **Data Entry Errors:** Row 8626 had the unit `eg/l`, which is a clear typo for `E9/l`.

**Helpful Information:**
*   The `LongName` for the panels was extremely useful (e.g., for `B-PVK+TKD`, confirming it includes an automated differential).
*   The most helpful pattern was `b-pvk+tkd,[component]` (e.g., `b-pvk+tkd,neut`). This explicitly names the component, removing all ambiguity. This is excellent coding practice.
*   Suffixes on panel codes like `%l` for lymphocytes (row 8573) or `%m` for monocytes (row 8574) were also very useful for disambiguation.

# Group 106

This group, centered on bacteriology, demonstrates several common challenges in lab code mapping. The primary distinction is between different methodologies for detecting bacteria: direct automated counting (`U-Bakt` with unit `E6/l`), microscopic examination (`-Vr` suffix, `Finding` property), and culture (`-Vi` suffix). 

Gotchas included:
1.  **Panels vs. single tests**: Codes for antibiotic sensitivity (`-he`) and specific pathogen panels (`F-BaktVi1/2/3`) were identified as panels, which is crucial for correct mapping. A generic culture request (`-BaktVi`) is a single test, but leads to follow-up tests like identification (`-Lm`) and sensitivity (`-He`).
2.  **Ambiguous scale**: The same test code, like `U-BaktVi`, can yield qualitative (`no growth`), nominal (`E. coli`), or quantitative (`1e5 CFU/ml`) results. This is evident in row 8716, where high `p_missing` suggests most results are not numeric, but the deciles show large quantitative values. The `OrdQn` scale is the appropriate choice here.
3.  **Method vs. Property**: It's important to distinguish between quantitative particle counts (e.g., from flow cytometry) and quantitative culture counts (colony forming units). While both can be represented with `Number Concentration`, their methods (`Automated count` vs. `Culture`) are different.
4.  **Localisms and typos**: Suffixes like `-b`, `-bv`, `-vtk` and typos like `u-bakt.` are common. Inferring their meaning relies heavily on context from surrounding, cleaner codes and the data profile (units, deciles).

The `LongName` and decoded prefix/suffix columns were invaluable, particularly for identifying panels and specific methods like dip-slide culture (`aluslasiviljely`). Without them, mapping would be far less accurate.

# Group 110

This group predominantly featured lymphocyte surface marker (CD marker) tests, crucial for immunology and hematology. The key challenge was differentiating between absolute counts (in Blood, units E6/L or E9/L) and relative fractions (as a % of Lymphocytes). The `TEST_NAME` prefixes (`B-` vs. `Ly-`) and units (`%` vs. `E9/L`) were vital clues. Many codes were synonyms or typographical variants for the same test (e.g., `ly-cd4`, `ly-t-cd4`, `ly-cd4-t`), which the grouping made easier to identify. 

Several prefixes, `la-` and `so-`, were unknown, forcing me to leave the `has_system` axis empty. A glossary of these local prefixes would be immensely helpful. The `s-gt-cdt` code was an interesting 'red herring', appearing to be a CD marker test but actually being a chemistry test (Carbohydrate-Deficient Transferrin), identifiable by its `%` unit and typical value range. This highlights the risk of relying solely on code patterns. Finally, an inconsistency in row 9080 (`p_missing: 100%` but deciles present) required a judgment call to trust the deciles over the missingness flag.

# Group 111

This group was dominated by COVID-19 related tests, primarily antigen (`-ag`), nucleic acid (`-nho`), and antibody (`-ab`). The main challenge was severe data quality issues, especially for rows 9096-9105 (`-cv19ag`). The `LongName` clearly identifies this as an antigen test, which should be qualitative (`Ord`) or semi-quantitative. However, these rows have quantitative units like `mmol/l`, `g/l`, `fl`, etc., which are biologically impossible for this analyte. This suggests a code collision where `-cv19ag` was misused for other lab tests, or a major data pipeline error. I mapped them literally based on the unit, but the combination of component and property/unit is nonsensical.

The presence of `LongName` entries specifying the exact commercial test kit (e.g., Panbio, Flowflex for rows 9107-9112) was very helpful. This allowed confident assignment of `Test strip` or `Immunoassay` as the method. Similarly, `-cv19sekv` (row 9127) clearly pointed to `Sequencing` as a method.

The group also contained a clear non-COVID test, `p-c1qabg` (rows 9129-9130), which was easy to identify from its code and `LongName`. One code, `cldinho` (row 9121), was completely uninterpretable and I had to leave it blank. Finally, the absence of a system prefix for most antigen and NAAT tests is a major limitation, as the specimen (e.g., Nasopharynx, Saliva, Nose) is a critical part of the LOINC code; this axis had to be left empty in most cases.

# Group 121

This group was dominated by molecular genetics and hematopathology tests, identifiable by prefixes (`B-`, `Bm-`) and suffixes/abbreviations (`-d`, `pcr`, `fish`, gene names). The `LongName` was crucial for confirming the identity of many tests, especially for resolving gene abbreviations like `FII`, `FV`, `HFE`, and `Lakt`.

A key pattern was that almost all tests had `p_missing=100`, indicating they are not typically reported as numbers. This points towards scales like `Nom` (e.g., for genotypes), `Nar` (for descriptive findings like morphology or FISH results), or `Ord` (for presence/absence). For tests marked as quantitative (`-qr`, `kvant`), the `p_missing=100` is a gotcha; it suggests that a numeric result is only given when the analyte is detected. The scale `OrdQn` is perfect for these cases.

Disambiguating single tests from panels was a major task. Codes combining multiple analytes (`b-fvfii-d`), specifying broad methods (`b-fishhem`), or having generic names (`b-farma-d`) were classified as panels. This distinction is subtle but important.

Several codes remained ambiguous due to non-standard or unclear abbreviations (e.g., `-ctr-d`, `b-aso2-qd`, `b-blapcr`). Without `LongName` or more context, mapping these is impossible. The abbreviation `BL` for bronchoalveolar lavage was a new one, distinct from the common `B` for blood.

# Group 126

This group was overwhelmingly composed of glucose measurements, most of which appear to be individual time points from a glucose tolerance test (GTT). The various suffixes and abbreviations (`r`, `ras`, `0`, `1h`, `120min`) all point to this. A key decision was to map the `has_time_aspect` for all these individual results as `Point in time (spot)`, as the time marker (e.g., '2h') specifies the point in a challenge protocol, not the duration of sample collection.

The main ambiguity was the specimen type (`has_system`), as most local codes lacked a prefix like `P-` or `B-`. I left it empty for most, but inferred `Plasma` from `-vp` (`veriplasma`) and `Blood capillary` from `vieri` (bedside), which also suggested the `Test strip` method. The two codes ending in `-tbr` and `-tir` with a unit of `%` were interesting. I interpreted these as Continuous Glucose Monitoring (CGM) metrics ('Time Below Range' and 'Time In Range'), which required creating a more descriptive component and using the `Time Fraction` property and `^Patient` system. The codes ending in `valm` (`valmis`/ready) with 100% missing values were identified as procedural flags rather than measurable tests and mapped accordingly with empty axes. Having the official `LongName` would have confirmed these interpretations and resolved the specimen ambiguity.

# Group 129

This group was dominated by `Pt-` prefixed codes, indicating patient-level procedures rather than specimen-based tests. The primary challenge was distinguishing between a single narrative result (`Doc`/`Nar` scale) and a panel (`is_panel: true`). I chose to use `is_panel: true` for codes that represent an order for a complex study with multiple separately interpretable results, such as spirometry, comprehensive semen analysis, and cardiac imaging. The `LongName`s, when available, were crucial for this (`Pt-Siemennestetutkimus, laaja` for comprehensive semen analysis). For spirometry (`fvsp...`, `spiro...`) and cardiac (`syd...`) tests, the abbreviations strongly implied complex procedures, and the high `p_missing` and `form` units supported that these are not single quantitative results. I classified them as panels representing the entire study. A minor ambiguity exists: even panels can have a component (e.g., "Spirometry study"). I added this where reasonable but kept other axes empty as is standard for panels. The cryptic suffixes (`-id`, `-idl`, `-ido`, `-io`) on the spirometry codes could not be resolved, but grouping them as spirometry panels is a safe and likely correct generalization.

# Group 160

This group was straightforward, containing three common liver enzymes: Alanine aminotransferase (ALAT), Aspartate aminotransferase (ASAT), and gamma-Glutamyl transferase (GGT). The component names were clear and the unit `U/L` consistently pointed to the `Catalytic Concentration` property.

The main challenge was handling rows with missing units and high `p_missing`. The `deciles` column was crucial here. Row 13007, for example, had over 74% missing values but also had deciles, which confirmed it was a quantitative (`Qn`) test. In contrast, rows like 13009 and 13011 had high `p_missing` and no deciles, so the scale type was correctly left undetermined.

This highlights a data quality issue: many records for these standard quantitative tests lack a numeric value. The presence of both explicit prefixes (`P-`, `S-`) and non-prefixed names for the same analyte shows the variability in source data coding; correctly interpreting the non-prefixed versions as `Serum or Plasma` is important. The use of full Finnish names (e.g., `alaniiniaminotransferaasi`) instead of only abbreviations made component identification unambiguous.

# Group 161

This group contained several clear patterns. The pairing of quantitative rows with units and low `p_missing` against qualitative/narrative rows for the same analyte with no unit and high `p_missing` was very helpful in assigning `Qn` vs `Ord`/`Nar` scales. 

Gotchas and ambiguities included:
- Method identifiers like `nukleiin` (nucleic acid), `nukle`, and `ag` (antigen) were embedded in the `TEST_NAME` rather than appearing as a standard suffix (like `-Nh` or `-Ag`), requiring parsing of the whole string. 
- Timed/challenge tests (e.g., `2 tuntia aterian jälkeen` for glucose) require knowing the LOINC convention that the time aspect is usually `Point in time (spot)`, while the timing detail is part of the component name (which is beyond this mapping task). 
- The test `p-omagluk,,potilasmittaringlukoosi` (row 13049) had a conflicting prefix `p-` (Plasma) with the name `potilasmittari` (patient meter), which typically uses capillary blood. I mapped based on the explicit prefix but noted the ambiguity.
- Differentiating Finnish terms like `kertatyydyttymätön` (monounsaturated) and `monityydyttymätön` (polyunsaturated) required specific domain knowledge of chemistry terminology in Finnish.
- Identifying panels like `ulosteenripulivirukset,nukle` (stool diarrhea viruses) relies on recognizing the plural `virukset` and the general nature of the name.

# Group 162

This group contained a mix of standard chemistry, hematology, panels, and some non-lab procedures. The grouping by string similarity worked well, for example by bringing together multiple spellings of 'Alkaline phosphatase' and 'Punasolujen kokojakauma' (RDW).

**Ambiguities and Gotchas:**
*   **Row 13138 (`p-urea,resirkulaatio`):** This was the most difficult. The name 'resirkulaatio' implies a ratio (property `Ratio`), typically reported as a percentage. However, the recorded unit was `mmol/l` and the `deciles` (4.65-23.14) are typical for a standard urea concentration, not a ratio. This is a clear data quality conflict. I chose to map based on the specific test name (`Urea recirculation`, property `Ratio`), assuming the unit and values were incorrectly recorded. Access to original result strings (e.g., '15%') would have resolved this.
*   **Row 13094 (`folaatti(fe-folaat)`):** The `fE` prefix isn't standard, but inferring `E` as Erythrocytes was key. The very high decile values confirmed this was RBC Folate, not serum Folate, demonstrating the utility of the `deciles` column for disambiguation.
*   **Panels:** Identifying panels was straightforward due to keywords like `paketti` (package), `erittelylaskenta` (differential count), `isoentsyymit` (isoenzymes), and multi-analyte names (`korona-rs-influenssa`). Marking `is_panel: true` and leaving other axes empty is the correct approach for these.
*   **System for hematology:** For the `L-` prefixed differential counts (e.g. `l-basofiilit`), the system is `Blood` rather than `White Blood Cells`, as the count is performed on a blood sample. The `E-` prefix for RDW correctly points to `Red Blood Cells` as the system of interest.

# Group 167

This group was dominated by components of hematology differential counts and serum protein electrophoresis. The phrase `osatutkimus` ('sub-test' or 'component study') in many `TEST_NAME`s was a clear indicator that these are not panels.

Key gotchas and patterns:
*   **Method Inference**: The term `konediffi` ('machine differential') was a direct signal to use the `Automated count` method. Similarly, `s-prot-fr` and the `-Fr` suffix ('fractions') pointed clearly to `Electrophoresis` for the protein tests.
*   **Paired Quantitative/Narrative Results**: The `S-M-komponentti` (M-protein) tests demonstrated a common pattern where a single analyte has both a quantitative result (in `g/l`) and a separate entry for narrative findings (identity of the protein, comments), which appeared here as a row with 100% missing values and no unit. Mapping the quantitative row to `Qn`/`Mass Concentration` and the narrative row to `Nar`/`Presence or Identity` is crucial.
*   **Absolute vs. Relative Counts**: The data clearly distinguished between absolute counts (e.g., `B-Neut`, `e9/l`, `Number Concentration`) and relative counts (`L-Neut`, `%`, `Number Fraction`). The component name must reflect this (`Neutrophils` vs. `Neutrophils/Leukocytes`).
*   **System Ambiguity (`B-` vs `L-`)**: The prefixes `B-` (Blood) and `L-` (Leukocyte) were used for similar components (e.g., `B-Neut` vs `L-Neut`). I interpreted `B-` as system `Blood` and `L-` as system `White Blood Cells`, which is a finer distinction but supported by the source data. This reflects local coding conventions that may not always have a direct parallel in LOINC's more standardized system axis, but is important to capture.

