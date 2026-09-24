# Group 7

The main correction in this group was for `has_component`. The initial values like `Transglutaminase IgA Ab` were correctly identified as referring to tissue transglutaminase tests, and the candidate list provided the exact OMOP terms `Tissue Transglutaminase IgA` and `Tissue Transglutaminase IgG`, which I applied based on the local test names. For the less specific `s-transglutaminaasivasta-aineet` (rows 21-22), which omits `kudos` (tissue), I chose the best available candidate `Tissue transglutaminase Ab`.

The `has_property` values (`Arbitrary Concentration`, `Presence or Threshold`) were already correct OMOP terms and required no changes.

For `has_system`, I confirmed `Serum` for tests with the `S-` prefix or "seerumista" in the name. For rows without an explicit system defined in the local code (e.g., rows 1, 2, 4, 5, 8), I left `has_system` empty as instructed, because the ideal LOINC term `Serum or Plasma` was not in the candidate list. This was the correct action under the rules, but a future process might benefit from having `Serum or Plasma` as a candidate for ambiguous blood chemistry tests.

# Group 14

This group covered variations of the C-reactive protein (CRP) test. The previous pass was highly accurate, and all the generated axis labels were already exact, case-sensitive matches to OMOP vocabulary terms. Consequently, no corrections were needed. My work was to verify this by checking each `current` value against its corresponding `possible fix` in the candidate lists. The logic was consistent: `has_system` was correctly inferred from prefixes (`p-` for Plasma, `s-` for Serum, `b-` for Blood, `cp-` for Blood capillary) and left empty when no prefix was present. `has_method` was correctly assigned based on keywords like `pika`, `vieritesti` (for 'Rapid immunoassay'), and `herkkä` (for 'Immunoassay'). The candidate lists provided were sufficient and contained all necessary terms.

# Group 20

This group contained a large number of microbiology and EKG tests. Several axes were cleared due to limitations in the candidate lists. For `has_method`, common EKG terms like `12 lead` and `Monitor` were not in the candidate list and had to be cleared. For `has_component`, the candidate list was missing terms for clinically significant targets like `Escherichia coli enterohemorrhagic` (EHEC) and `EKG monitoring for atrial fibrillation`, forcing these to be cleared. Similarly, a combined component for `Shigella` and enteroinvasive `E. coli` (EIEC) was missing, making the provided candidate (`Escherichia coli enteroinvasive`) incomplete for tests that detect both. On the other hand, for several nucleic acid tests (CMV, VZV), I was able to improve specificity by choosing the `... DNA` component. Similar improvements were made for `Campylobacter` and `Salmonella` by choosing the `... sp` variant, and for `Cryptococcus` by using the combined `...gattii+neoformans` term, which better reflects OMOP's syntax.

# Group 21

In this group, two primary corrections were made. First, the `has_component` value 'Transferrin.iron saturation', a non-existent OMOP term, was corrected to the proper term `Transferrin saturation` based on the candidate list. Second, the `has_property` value 'Mass Fraction' was corrected to its proper OMOP cased form, `Mass fraction`. This capitalization issue is a perfect example of why this review step is critical, as a near-miss string fails automated mapping. The `has_system` axis values were already correctly inferred from the Finnish test code prefixes (`p-` for Plasma, `s-` for Serum) and were left unchanged. The candidate lists provided were sufficient for all necessary corrections.

# Group 33

The main correction in this group was to the `has_component` axis for all MRSA-related tests (e.g., rows 183-186). The initial free-text value `Staphylococcus aureus methicillin resistant` was changed to the standard OMOP term `Methicillin resistant Staphylococcus aureus`, as suggested by the candidate list and supported by high usage in curated Finnish data. The `has_system` value `Perineum` for rows 186, 195, and 196 was removed because the candidate list correctly indicated it is not a valid OMOP term. For the ECG tests (rows 198-200), I changed the component from `Electrocardiogram` to `ECG`. Although `Electrocardiogram` is a valid LOINC term, it was not present in the candidate list of fixes, and the strict instruction is to pick from the list. The local code `pt-ekg` also supports using the abbreviation `ECG`. Most other axes were already correct and required no changes.

# Group 34

This was a microbiology group focused on Streptococcus species. The main corrections involved standardizing component names. 

*   For rows testing for beta-hemolytic strep (206-212, 216-217), I corrected `Streptococcus.beta hemolytic` to the proper OMOP term `Streptococcus.beta-hemolytic` from the candidate list.
*   For Group A Strep antigen tests (rows 213, 215), I changed `Streptococcus pyogenes antigen` to the standard LOINC abbreviation `Streptococcus pyogenes Ag`.
*   A notable issue arose with the system axis for rows 205 and 218. The local codes `fl-` and `fluori` clearly indicate `Vaginal fluid`. However, the candidate list for the current value `Vaginal fluid` only offered `Genital fluid` as a fix. While `Vaginal fluid` is a valid LOINC system, it was absent from the candidates. Following instructions, I chose the provided candidate `Genital fluid` over leaving the axis empty, as it's a correct, albeit less specific, term. This suggests a potential gap or configuration issue in the semantic search that generated the candidates.

# Group 37

This group contained a wide variety of tests, from point-of-care chemistry to complex molecular genetics and patient-level studies. Several corrections were made by selecting more precise OMOP terms from the candidate lists, such as `Natriuretic peptide.B N-Terminal Prohormone` to `Natriuretic peptide.B prohormone N-Terminal`, `HIV 1+2 Ag+Ab` to `HIV 1+2 Ab+HIV1 p24 Ag` for modern combo tests, and `Sleep study` to `Polysomnography study`.

A systematic error was identified and corrected: all `pH` measurements (rows 257, 258, 327) were incorrectly assigned the property `Logarithmic scale`, which is not a valid OMOP term. I changed this to `Substance Concentration`, the standard OMOP property for pH. 

The candidate lists were unhelpful for components representing ratios (e.g., CD4+ or CD8+ T-cell fractions, rows 313, 314) or very specific analytes without a common LOINC equivalent (e.g., Amphetamine enantiomers, row 323). In these cases, the component was cleared to avoid mapping to an incorrect term. Similarly, some methods like `Karyotype` and `Cell block` had no OMOP candidates and were cleared. Row 317, which was initially empty, was populated based on its name and its similarity to other histology rows (296, 318).

# Group 42

This group involved several standard chemistry and coagulation tests. A number of corrections were made to align with precise OMOP vocabulary terms. Common fixes included updating `component` names to their standard LOINC form (e.g., `Gamma-glutamyltransferase` to `Gamma glutamyl transferase`, `Thyroxine.free` to `Thyroxine free`, `Antithrombin III` to `Antithrombin`). For cardiac markers like Troponin I and T, the more specific `Troponin I.cardiac` and `Troponin T.cardiac` were chosen. I also corrected `Adrenocorticotropic hormone` to its common synonym `Corticotropin`.

A key systematic correction was removing the `Time` property for coagulation tests (e.g., `p-la1`, row 397) because `Time` is not a valid OMOP property term; the unit `s` is sufficient evidence of a time-based measurement, but without a candidate term, the property axis must be cleared. For a dialysis fluid measurement (`di-na`, row 353), I corrected the system from `Dialysate` to the OMOP term `Dialysis fluid`. Finally, for some unidentifiable codes like `p-ked.` (row 395), I cleared all axes to avoid making an unsubstantiated mapping.

# Group 43

This group contained a wide variety of tests, including immunoassays, endocrinology, and therapeutic drug monitoring. The candidate lists were generally very helpful. I made several corrections to the `has_component` axis:

*   I corrected several chemical names to their standard OMOP forms, such as `5-Hydroxyindoleacetic acid` to `5-Hydroxyindoleacetate` (rows 493-496, 518-519) and removed parenthetical abbreviations like `(DHEA)` to match the exact OMOP term (rows 546-549).
*   For free fatty acids (`fs-ffa`, `s-ffa`), the OMOP term `Fatty acids.nonesterified` was a better match than the other candidates (rows 500-501, 561).
*   For Saccharomyces cerevisiae antibodies (`s-asca`), the candidate `Baker's yeast (Saccharomyces cerevisiae) Ab` was a clear improvement (rows 536-537).
*   For a few tests (`s-amh`, `s-tati`, `b-vasp`), no suitable component candidate was available, so I correctly left the component field empty. This is an area for improvement, as these are common tests and a candidate should exist.
*   For platelet aggregation tests measured in `auc` (rows 487, 489), the property `Arbitrary unit` had no candidates. I used `Arbitrary Concentration` as the most reasonable available choice.

# Group 44

This group required several corrections based on the candidate lists. I changed `Natriuretic peptide.B` to `Natriuretic peptide B` (row 613-615) and `Neuron specific enolase` to `Enolase.neuron specific` (644-645) as these are the correct OMOP terms. I also corrected `Aminolevulinate` to `Delta aminolevulinate` (665) and `Collagen type I N-terminal telopeptide` to `Collagen crosslinked N-telopeptide` (678-681) based on the long names and common abbreviations (NTx). The `has_property` for 24-hour urine collections (mmol unit) was changed from `Substance` to the more specific `Substance Content`.

The candidate lists were unhelpful in several cases. For `Follicle stimulating hormone` (e.g., 616), no candidate was provided, forcing me to clear the component even though `Follitropin` is the likely OMOP term. Similarly, `Umbilical cord blood serum` (608-609) and `Secretion` (651-652) were missing from the `has_system` candidates, and `Potassium hydroxide preparation` (598) and `Calculus (stone) analysis` (682-683) were missing from the `has_component` candidates, resulting in data loss. The property list for `pH` was empty, a surprising omission for such a common term; I retained `pH` as it is certainly a valid OMOP property. The `Narrative` property was consistently unmapped and I cleared it in all instances.

# Group 51

This group primarily contained microbiology tests, mostly for viral antigens and antibodies. The corrections were concentrated in the `has_component` axis. Many `current` values were descriptive near-misses of the official OMOP term, such as using '... antigen' instead of '... Ag' or '... IgG antibody' instead of '... IgG'. A notable correction was `Infliximab` to `inFLIXimab`, which required paying close attention to case sensitivity. 

The candidate lists were unhelpful for a few codes. `Coronavirus antigen` (row 730) and some virus combinations (e.g., `-coinrsv`, row 713) had no suggestions, forcing me to clear the component. The `Pharyngeal secretion` system (e.g., rows 760-762) also lacked a suitable candidate, so I cleared the system for those rows. Additionally, I cleared the component for concepts that are not analytes, such as `Embryo transfer` (row 729) and `Inflammation` (row 741), as they do not fit the LOINC component model.

# Group 68

In this group, numerous corrections were made to align with the provided candidate OMOP terms. Spelling and punctuation fixes were common, such as `Soluble fms-like tyrosine kinase 1` to `Soluble fms-like tyrosine kinase-1` (row 929) and `Mass Fraction` to `Mass fraction` (row 885). More substantive component changes included standardizing allergen-related components (e.g., `Dog (Canis familiaris) dander IgE Ab` to `Dog dander IgE` on row 916) and improving specificity (e.g., `Scleroderma-70 Ab` to `SCL-70 extractable nuclear Ab` on row 928).

The candidate lists were unhelpful for a few `has_system` values; `Pancreatic fluid` (row 832) and `Secretion` (row 941) had no suitable OMOP replacement and were cleared. The component `Desmethylclozapine` (rows 906-909) also lacked a correct candidate, with the provided options being for a different drug, so the component was cleared. For two ambiguous aldosterone codes (`s-oaldos` and `s-valdos`, rows 920 and 937), the component was also cleared due to extremely high and implausible decile values.

`Ascitic fluid` was correctly mapped to the OMOP term `Peritoneal fluid` (rows 809, 810) and `Sperm` to `Spermatozoa` (row 943) based on the candidate lists. `Catalytic Activity Fraction` was consistently changed to the more common `Catalytic Fraction` (rows 845, 868).

# Group 70

This group was characterized by a mix of drug monitoring, serology, allergy testing, and some unspecific or panel codes. 

Several corrections involved standardizing component names. Antibody tests like `Cardiolipin IgG Ab` and `Parvovirus B19 IgG Ab` were refined to the more standard OMOP forms `Cardiolipin IgG` and `Parvovirus B19 IgG`. Drug names like `Carbamazepine` were corrected to `carBAMazepine`. Allergen IgE tests were successfully mapped to their more specific forms including the Latin binomial names, e.g., `Peanut IgE Ab` to `Peanut (Arachis hypogaea) IgE`.

The candidate lists had significant gaps. Common analytes like `Paraprotein` and `Beta carotene` had no suitable candidates, forcing me to clear the component. Similarly, the common property `Time` was missing from the candidates list, as was `Histology` as a method. This suggests the semantic search underlying the candidate generation needs improvement for certain terms.

Case corrections were common for properties, such as `Mass content` to `Mass Content` and `Mass Fraction` to `Mass fraction`, underscoring the need for exact string matching.

Finally, a large number of rows (e.g., `s-vara`, `s-pakaste...`) had no component and seemed to represent administrative codes or panels, which were correctly left mostly unmapped.

# Group 73

This group consisted entirely of nucleic acid amplification tests (`-nho` suffix) for respiratory viruses. The `has_property` (`Presence or Threshold`) and `has_method` (`Nucleic acid amplification with probe detection`) were already correct and confirmed as valid OMOP terms.

The main corrections were to the `has_component` axis. For RNA viruses detected by NAAT, the most specific component is `[Virus] RNA`. Based on the candidate lists and their high usage in Finnish reference data, I updated most components to include the 'RNA' suffix (e.g., `Influenza virus B` became `Influenza virus B RNA`). This was not possible for `Influenza virus A` or the generic `Parainfluenza virus`, as the `... RNA` version was missing from their candidate lists, so I retained the valid, albeit less specific, term. For `Influenza virus A variant` (row 1115), I chose `Influenza virus A subtype` as the best semantic match for 'variantti' from the candidates.

A significant omission is the `has_system` axis, which was empty for all rows. These are respiratory tests, so the system is likely `Nasopharynx` or a similar term. Since this was blank and no candidates were provided, I was required to leave it empty, which represents a loss of information.

# Group 74

This group consisted entirely of qualitative nucleic acid amplification tests (`-Nho`). The `has_property` (`Presence or Threshold`) and `has_method` (`Nucleic acid amplification with probe detection`) were consistent and correct across the board. The `has_system` axis was also correctly inferred from the test code prefixes (`f-`, `li-`, `s-`) in the prior pass, requiring no changes. 

The main corrections involved the `has_component` axis for four coronavirus tests (rows 1153-1156). The original values, e.g., `Coronavirus 229E`, were near-misses; I corrected them to the exact OMOP terms, `Human coronavirus 229E`, as suggested by the candidate list. This is a perfect example of the value of this correction step. Rows flagged as panels (`is_panel: true`) correctly had their component axes left empty, as did one row with an ambiguous test code (`-bopanho`), which I left unchanged.

# Group 79

This group consisted primarily of urine tests, which were mostly correctly mapped by the previous pass. The existing axis values were almost all valid OMOP terms. I made three specific corrections:

1.  **Row 1170 (`u-a1mikre`):** The initial pass incorrectly identified this as an `Albumin/Creatinine` ratio. The test code clearly indicates Alpha-1-Microglobulin (`a1mi`). I corrected `has_component` to `Alpha-1-Microglobulin/Creatinine`, which was fortunately available in the candidate list for the incorrect value.
2.  **Row 1214 (`u-solut,muut`):** The component was `Cells.other`, which is not a valid OMOP term and had no candidates. I changed this to the generic but valid component `Other`, which fits the Finnish term `muut` (other).
3.  **Row 1199 (`u-happamuus`):** The candidate list for the property `pH` was empty. However, `pH` is a valid OMOP property, and the deciles (`6.5`-`8.0`) confirm this is a pH measurement. I retained the `pH` property, noting this gap in the candidate list generation.

Overall, the candidate lists were effective, but the process has a weakness when the initial free-text value is completely wrong for a specific row, as seen with row 1170. It relies on the correct term coincidentally being a semantic match for the wrong term.

# Group 84

This group consisted entirely of codes related to specimen collection, processing, and transport logistics rather than analytical results. The corrections were mostly straightforward. The non-OMOP term `Specimen collection procedure`, used for many Finnish codes like `näytteenotto` (specimen collection), was consistently corrected to the valid OMOP term `Specimen collection`. Similarly, `Specimen processing` was corrected to `Specimen preparation`.

The candidate lists had two notable gaps. First, for `näytekulje` (`Specimen transport`), no suitable candidate was found, forcing me to clear the component. Second, and more critically, for row 1236 (`ottotapa` with unit `h`), the data strongly implies a measurement of time duration (`has_component`: Time, `has_scale_type`: Qn). The property should be `Time`, but no candidate was provided for this value. Following the instructions, I had to leave the property empty, resulting in an incomplete mapping that contradicts the evidence.

# Group 85

Corrections mainly involved standardizing component names to their more complete or conventional OMOP forms (e.g., `Coronavirus...` to `Human coronavirus...`, `Cladosporium herbarum Ab.IgE` to `Cladosporium herbarum IgE`). I also refined generic `Candida` to `Candida sp` and `Microscopy` to the more specific `Light microscopy`. A significant issue was the absence of candidates for several correct concepts, forcing me to clear fields that were likely correct in spirit but not in vocabulary. `Dissection` (row 1273), `Skin test` (row 1248), and `Cervical specimen` (rows 1258, 1259) all lacked OMOP term candidates. Critically, `Urine` was also missing from the system candidate list, preventing its assignment to row 1274 despite a clear `U-` prefix in the test code. For coronavirus tests (rows 1251-1254), I chose `Respiratory system specimen` over the current `Respiratory specimen` based on its higher use in curated Finnish data.

# Group 89

This group primarily consists of screening tests (`seulonta`), many of which are panels. Most of the existing axis values were already exact OMOP terms and required no changes. The main correction was for `row_id` 1287 (`rhdnegseul`), where the `has_component` was `Red blood cell antibody`. The candidate search found no suitable OMOP terms, so I cleared the field as per instructions. While the concept is clear (RBC antibody screen), the provided string is not a valid OMOP term, and without a candidate, it's better left empty. The remaining rows were either correctly defined panels (mostly empty axes) or had correct, existing axis values that were validated against the candidate lists.

# Group 105

This group consisted entirely of hematology tests, mostly components of a complete blood count (CBC), prefixed with `B-` for Blood. The candidate lists were excellent and contained the correct OMOP terms for almost all rows.

The main corrections involved replacing near-miss component names with their canonical OMOP counterparts. Specifically:

*   `Erythrocyte mean volume` was consistently corrected to `Erythrocyte mean corpuscular volume` for Mean Corpuscular Volume (MCV) measurements (e.g., rows 1308, 1325, 1364, 1390).
*   For Immature Granulocytes (IG), I differentiated based on the property. `Immature granulocytes/leukocytes` was corrected to `Granulocytes.immature/Leukocytes` for the fraction (`%`, `Number Fraction`, row 1352) and to `Immature granulocytes` for the absolute count (`e9/l`, `Number Concentration`, row 1353). This distinction is crucial for correct LOINC mapping.
*   For one ambiguous row (1307, `b-pvk` with unit `e9/l`), I inferred the component to be `Leukocytes` based on the common use of that unit for WBC counts in a basic blood count panel.

Many rows were left with empty components because the test code (e.g., `b-pvk`) and unit (e.g., `%`) were too generic to identify a specific analyte, which is the correct outcome for ambiguous data.

# Group 106

This group consisted entirely of bacteriology tests. The initial axis assignments were largely correct, and most values were already valid OMOP terms. My corrections focused on the `has_system` axis. I corrected `Bronchoalveolar lavage fluid` to the valid term `Bronchoalveolar lavage` (row 1412), and `Dialysis fluid.peritoneal` to `Dialysis fluid peritoneal` (row 1427). A significant issue was the candidate lists failing to provide exact matches for valid OMOP terms. For `Gingival crevicular fluid` (row 1429), no candidate was found, so I had to clear the field as per instructions. For `Vaginal fluid` (rows 1423, 1424), the only candidate was the more general term `Genital fluid`, which I used. This highlights a limitation where the candidate list can force a loss of specificity or a complete omission of a correct value.

# Group 110

This group consisted entirely of immunophenotyping tests (CD markers). I standardized the component names based on whether they were absolute counts (e.g., `CD19 cells`) or fractions. For fractions of lymphocytes (`ly-` prefix), I used the `Cells.X/Lymphocytes` component where candidates existed and had usage data (`CD3`, `CD4`, `CD8`). Where they didn't (`CD19`, `CD16/56`), I used the simpler cell name component.

The most significant issue was the `has_system` axis. For the many tests that were fractions of lymphocytes (`ly-` prefix), the prior pass correctly inferred the system as `Lymphocytes`. However, `Lymphocytes` is not a valid OMOP system term, and the candidate list provided no alternatives. As instructed, I had to clear this axis. Ideally, the system should be `Blood`, with the denominator captured in the component (e.g., `Cells.CD4/Lymphocytes`), but I could not add `Blood` without it being in the candidate list for `Lymphocytes`.

Additionally, one property, `Number per Mass`, had no candidates and was cleared (row 1509). Two rows (1556-1557) were completely unmapped and remained so.

# Group 111

This group consisted almost entirely of COVID-19 related tests. The main task was to correct the `has_component` axis from descriptive, free-text values like `SARS-CoV-2 IgG antibody` to their standard OMOP forms, such as `SARS-CoV-2 (COVID-19) IgG`. The candidate lists were effective for this, with high usage statistics confirming the choices. The `property`, `method`, and `system` axes were already correct and did not require changes. A notable challenge was the `SARS-CoV-2 spike protein antibody` test (`s-cv19sab`). The candidate list lacked an ideal component like `SARS-CoV-2 (COVID-19) spike protein Ab`. I chose `SARS-CoV-2 (COVID-19) spike protein`, treating the spike protein as the component against which antibodies are measured, which is a plausible LOINC pattern but less direct. Similarly, for `Complement C1q antibody.IgG`, the best available candidate `Complement C1q Ab` lost the IgG specificity, highlighting a minor gap in the provided candidates.

# Group 121

This group largely contained molecular genetics, cytogenetics, and hematopathology tests. Many `has_component` values for gene tests were either already correct OMOP terms or were corrected to a more standard format (e.g., `BRCA1 and BRCA2 genes` to `BRCA1+BRCA2 gene`). However, for several genetic tests (e.g., `Coagulation factor V gene`, `Alpha-1-antitrypsin gene`), the candidate lists only offered OMOP terms for the resulting protein, not the gene itself. As no correct candidate was available, I cleared these components, highlighting a weakness in the candidate generation. The `has_method` axis required systematic corrections: `Fluorescence...` was corrected to `Fluorescent...`, and general `Nucleic acid amplification` was specified as `... with probe detection` for relevant PCR tests. Similarly, `Bronchoalveolar lavage fluid` was consistently corrected to the OMOP term `Bronchoalveolar lavage`.

# Group 126

This group primarily consists of glucose measurements. Most axis values were already correct OMOP terms with 1.000 similarity scores. I made two corrections to `has_component`:

*   For `row_id` 1710 (`-gluk-tbr`, Time Below Range), the candidate list for `Glucose time below range` was empty, so I correctly cleared the component.
*   For `row_id` 1711 (`-gluk-tir`, Time In Range), I selected `Glucose measurements in range` as the most appropriate candidate over the panel option, since `is_panel` was false and the unit was `%` (Time Fraction).

The most significant issue was the candidate list for the `has_system` axis. It was missing `Serum or Plasma`, which is the standard system for most routine venous blood glucose tests (like OGTTs) where the local code doesn't specify serum or plasma explicitly. This forced me to leave the `has_system` axis empty for a large number of rows (e.g., 1713, 1715-1718, etc.), as the provided options (`^Patient`, `Blood capillary`, `Plasma`) were not appropriate. Including `Serum or Plasma` in the candidate list for such groups would greatly improve mapping accuracy.

# Group 129

This group largely consisted of clinical procedures performed on the patient, identified by the `Pt-` prefix and correctly assigned `^Patient` as the system. For `Spirometry` and `Semen analysis`, the provided candidates included more specific `... panel` terms (`Spirometry panel`, `Semen analysis panel`). I adopted these as they were a better fit for the data, which had `is_panel=TRUE` and Finnish long names indicating comprehensive examinations. The main difficulty was the absence of any candidate OMOP terms for several valid clinical concepts, including `Echocardiography`, `Myocardial perfusion study`, `Spirometry with bronchodilator`, and `Thermal sensory testing`. These concepts were clearly identifiable from the Finnish codes but had to be cleared from the `has_component` axis due to the lack of a valid term to map to, as per the instructions.

# Group 160

This group concerned three common liver enzymes: ALAT, ASAT, and GT. The `has_property` (`Catalytic Concentration`) and `has_system` (`Plasma`, `Serum`, `Serum or Plasma`) axes were already correct and corresponded perfectly to the test names, prefixes, and units. The only required correction was on the `has_component` axis for Gamma-glutamyl transferase. The previous pass had used `gamma-Glutamyl transferase`, and I corrected this to the exact OMOP term `Gamma glutamyl transferase` based on the candidate list. This correction affected six rows (1775, 1777, 1778, 1783, 1784, 1789). The candidate lists were sufficient for all necessary corrections.

# Group 161

Most mappings in this group were already correct and only required validation. A few minor corrections were made for precise OMOP terminology. For `C-peptide` (rows 1827-1829), the term was changed to the correct OMOP spelling `C peptide`. For a leukocyte count (row 1811), the system `White Blood Cells` was corrected to the lowercase `White blood cells`. In one case of a nucleic acid test (row 1798), `Chlamydia pneumoniae` was updated to the taxonomically newer `Chlamydophila pneumoniae` as suggested by the candidate list and used in LOINC for the analyte itself (as opposed to antibody tests). The candidate generation process failed for the common components `Follicle stimulating hormone` and `Luteinizing hormone`, providing no suggestions. I retained the existing values as they are the correct OMOP terms, but this gap in the candidate list is a significant weakness.

# Group 162

This was a fairly large and diverse group. A significant number of corrections involved selecting a more specific or correctly formatted component from the candidate list, such as changing `Bicarbonate.standard` to `Bicarbonate^^standard` and `25-Hydroxyvitamin D2+D3` to `25-Hydroxyvitamin D3+25-Hydroxyvitamin D2`. A simple but crucial fix was correcting the capitalization of `Mass Fraction` to `Mass fraction` for PSA ratio tests (e.g., row 1910). The candidate lists were unhelpful for several clear concepts (e.g., `Kt/V`, `Urea recirculation`, `Erythroblasts`), forcing me to leave the component axis empty as per instructions. The most problematic case was `Bilirubin.direct` (row 1902), where the test is clearly for conjugated bilirubin, but the only candidate was `Bilirubin` (total), which is incorrect. This resulted in data loss, as clearing the component was the only valid action. For `25-Hydroxyvitamin D` (row 1857), I made an informed choice to use the total (D2+D3) component, as this is standard clinical practice for an unspecified vitamin D test. The prefixes in the Finnish codes (`fP-`, `S-`, `B-`) were very helpful in confirming or choosing the `has_system` axis.

# Group 167

This group largely consisted of hematology differential counts and serum protein electrophoresis fractions. Most initial mappings were already correct and exact OMOP terms. The main corrections were:

1.  **System case correction**: For several rows with an 'L-' prefix (e.g., `l-baso`, `l-neut`), the system was `White Blood Cells`. The candidate list provided `White blood cells`, which is the correct OMOP capitalization. I applied this fix to rows 1956, 1962, 1965, 1968, and 1971.
2.  **Missing Component Candidate**: For M-protein (`s-m-komponentti`, rows 1980-1984), the candidate list for the component `M-protein` was empty. Since a valid OMOP term could not be found in the provided list, I had to clear the `has_component` field for these rows, as per instructions.
3.  **Candidate List Gap**: For `Erythroblasts` (rows 1950-1952), the `current` value was correct, but the candidate search failed to find `Erythroblasts` as a possible fix for itself, instead offering only more specific or related terms. I retained the `current` value as it is the most logical and correct component, assuming a gap in the candidate generation process.

