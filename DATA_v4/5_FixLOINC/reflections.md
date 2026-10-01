# Group 7

This group was straightforward to map. The test names were clear variations of 'tissue transglutaminase antibodies', specifying either IgA or IgG isotypes. The `S-` prefix or the word `seerumista` consistently indicated a Serum specimen. The unit `U/mL` matched the `[Units/volume]` property. For rows without a unit, this property could be safely inferred as this is the standard quantitative test format. The candidate list was excellent, containing the specific IgA and IgG concepts with the correct property and system, which were also high-ranking Top 2000 codes. For the two rows where the isotype was not specified, I inferred IgA as it's the primary screening test for celiac disease, mapping them with medium certainty. No candidates were missing.

# Group 14

This group consisted entirely of C-reactive protein (CRP) tests. The candidate list was comprehensive, allowing for clear differentiation based on specimen (Blood, Serum/Plasma, Capillary), method (standard, high-sensitivity, rapid), and property (Mass/volume).

**Key success factors:**
*   The Finnish qualifiers were very informative: `pika`, `pikatesti`, and `vieritesti` all clearly indicated a rapid/point-of-care test, mapping well to the 'Rapid immunoassay' concept. `herkkä` was a direct translation for 'High sensitivity'. Prefixes (`B-`, `P-`, `S-`, `cP-`) and specimen words (`veri`, `plasma`) were crucial for system assignment.
*   The `value_deciles` were essential. They allowed mapping of rows 99 and 105 to the high-sensitivity concept based on the low values, even when the term `herkkä` was missing from the name. They also confirmed the property as `[Mass/volume]` for many rows lacking a unit.

**Challenges and unmapped rows:**
*   A large number of rows were left unmapped. This was consistently due to a lack of quantitative information (`evidence_level` was `name` or had an uninformative unit). As per instructions, without a unit or values, it was impossible to distinguish between `[Mass/volume]` and `[Moles/volume]` candidates. This reflects a limitation in the source data for those specific records, not a failure of the mapping process or vocabulary.

Overall, the mapping for this group was successful where the data allowed, with clear evidence driving the choice of specific LOINC concepts.

# Group 20

This group was mostly straightforward, containing two distinct types of tests: microbiology NAA panels and EKG panels. The microbiology tests, both from stool (`F-`) and CSF (`Li-`), were well-defined by their names, including specimen and method (`nukl.haponos`), allowing for high-certainty mapping to specific NAA concepts. For example, the large block of `Li-` tests (124-133) formed a clear meningitis/encephalitis panel and mapped perfectly.

The EKG tests were more problematic. The basic `12 lead EKG panel` was a clear match for many rows. However, more specific EKG tests could not be mapped because the candidate list was insufficient. Rows 144-145 specified 'atrial fibrillation screening' (`eteisvärinänseulonta`), and rows 146-150 specified 'includes computer analysis' (`sisältäen tietokoneanalyysin`). No candidates for atrial fibrillation or for an EKG panel with interpretation were provided, forcing me to leave these rows unmapped. The `loinc_name_guess` for these was good (`12 lead EKG with interpretation panel`), but the actual concept was missing from the search results.

# Group 21

This group was straightforward to map. The Finnish names were clear and consistently distinguished between 'Transferrin iron saturation' (`rautakyllästeisyys` or `saturaatio`) and 'soluble Transferrin receptor' (`transferriinireseptori, liukoinen`).

The candidate list was excellent, providing the exact concepts needed. For iron saturation, I chose the top-2000 concept `3009814` with `[Molar fraction]` as it's the standard for this measurement reported in `%`. For the soluble transferrin receptor, `3015399` with `[Mass/volume]` was a perfect match for the rows with `mg/l` units.

Most rows had sufficient evidence (unit and/or values) to confirm the property. Some rows reported saturation as a decimal fraction (values 0-1) rather than a percentage, but this still maps to the same fraction concept.

Only one row, `168`, was unmappable due to a direct conflict between its name (a single result) and its unit (`paketti`, meaning panel/package).

# Group 33

This group contained three distinct types of tests: MRSA cultures, drug abuse screens, and ambulatory EKG (Holter) studies. The mappings were mostly straightforward.

For the MRSA cultures, candidates were available for specific body sites like Nose (`nenästä`) and Throat (`nielusta`), which allowed for precise mappings. However, for the site Perineum (`perineumista`), no specific candidate was available, forcing a mapping to the more general `Specimen` concept. This highlights a limitation in the candidate list where less common but still specific sites are missing.

For the drug screens, a 5-drug panel was perfectly matched. However, several local codes specified a 6-drug panel, for which no specific LOINC concept was in the candidate list. These were mapped to a generic `Drugs of abuse panel`, which is correct but loses the specific number of analytes.

The EKG rows were clearly Holter monitor studies and were mapped to the appropriate panel concept.

One row (183) for a genetic test was left unmapped. The Finnish name was very specific, describing an analysis for both sequence variations and copy number variations. No single candidate concept covered both aspects, and mapping to a concept covering only one would be incorrect and misleading.

# Group 34

This group covered various Streptococcus tests, primarily qualitative detection. The local codes were generally specific and allowed for high-confidence mapping. Key terms like `viljely` (culture), `nukleiinihaponosoitus` (NAA), `antigeeni` (antigen), and `vieritesti` (rapid test) were crucial for selecting the right method. Specimen information was also usually clear, either from a prefix (`Ps-`, `Fl-`) or an explicit word (`nielusta`, `fluori`). When specimen was not specified, I correctly defaulted to a LOINC concept with `System = Specimen`. Some ambiguity arose when the local code did not specify details like 'probe vs non-probe' for NAA tests, leading to 'medium' certainty. For 'antigeeni' tests without an explicit 'rapid' qualifier, I mapped to the rapid test concept as this reflects common practice for Strep A throat swabs, which felt justified by a related row (211) that did specify `vierithoitoy` (point-of-care). The candidate list was comprehensive for this group.

# Group 37

This group contained a wide variety of tests, from routine chemistry and hematology to microbiology, molecular diagnostics, and procedural codes. The Finnish names are generally very descriptive, which made mapping straightforward for many rows, especially when combined with unit and value data. 

**Successes:**
- Most common laboratory tests (glucose, electrolytes, creatinine, blood gases, urinalysis components) were easily mapped using a combination of name, specimen prefix (`B-`, `P-`, `U-`), and units/values.
- Specific microbiology and molecular tests (MRSA, HPV, NT-proBNP) were also well-defined in the Finnish codes and had good matches in the candidate list.
- Panel codes for blood gases, CBC, and urinalysis were correctly identified and mapped.

**Challenges & Unmapped Rows:**
- **Administrative/Billing/Procedural Codes:** Several rows (218, 222-225, 274, 275, 295-297, 313-315) were not laboratory observations but rather codes for procedures, billing, or complex studies (e.g., 'Bone density, 2 sites'). These cannot be mapped to a single LOINC result concept and were left empty.
- **Missing Candidates:** Some tests had no suitable candidate. For example, the test for 'other pathogenic HPV' (row 221) is a common reporting category, but no LOINC concept for it was in the list. Similarly, a generic MRD test in bone marrow (row 236) and percentage-based flow cytometry results (rows 281, 307) lacked matching candidates with the correct property (fraction/ratio vs. absolute count).
- **Specificity Mismatch:** For `fp-kollageenii:nbeta-karboksiterminaalinentelopeptidi` (row 252), the Finnish name specified the beta-isomer of CTX, which was not present in the candidate LOINC names, leading to a `medium` certainty mapping to the more generic CTX concept.

# Group 42

This large group covered a wide range of common laboratory tests, primarily identified by their Finnish abbreviations. Mapping was generally straightforward for well-defined analytes where units and values were present (e.g., `p-na`, `s-alat`, `p-acth`). The provided `LongName` and prefix/suffix meanings were very helpful.

Several challenges arose:
1.  **Ambiguous codes:** Some codes like `p-fs`, `p-la1`, `p-la2`, `p-rvvt-l` were too generic to map to a specific coagulation test, and the candidate list lacked general 'screening' concepts for these.
2.  **Missing candidates:** Some specific concepts were missing, such as Sodium pre-dialysis (`p-naed.`) and Prolactin in moles/volume. This prevented mapping otherwise clear rows.
3.  **Panels vs. Components:** Many rows were clearly panel/order codes (e.g., `p-nak`, `sp-pak`, `papa`). Mapping these to panel concepts was successful. However, some procedural panels (`pef-pa`, `pt-vp-ple`) lacked a good match in the candidate list.
4.  **Data quality:** A few rows had suspect units (`p-alat` in `umol/l`, `p-laite` in `ug/l`). I mapped them with medium/low certainty where the evidence strongly suggested a typo, but it highlights the risk of relying on incorrect source data.
5.  **`name` only evidence:** A significant number of rows had only a name. For analytes with multiple LOINC properties (e.g., mass vs. moles vs. activity), these could not be mapped, leading to many unmapped rows. This is the correct approach, as guessing the property is unsafe.

# Group 43

This group was generally straightforward. Most codes were common chemistry tests where the Finnish abbreviation (e.g., `Ca`, `Cl`, `C3`, `CK`, `CEA`) was transparent. The specimen prefixes (`S-`, `P-`, `B-`, `dU-`, `Pf-`, etc.) were also standard and easy to interpret. The main difficulty, and the reason for the large number of unmapped rows, was the lack of quantitative information (units or values) for many entries. This made it impossible to distinguish between properties like Mass/volume and Moles/volume. This is an issue with the source data rather than the mapping process. The candidate list was excellent and contained the correct concept for nearly all mappable rows. One minor gap was the absence of a `Presence` concept for Cobalt in Urine (for row 568, `u-co`, unit 'form'). The code `ts-cc` was unmappable due to being ambiguous and likely representing a histology/cytology finding.

# Group 44

This group contained a mix of common chemistry and immunology tests, most of which were straightforward to map. The Finnish abbreviations (`5hiaa`, `ace`, `afp`, `hcg`, `dhea`, etc.) were clear and well-supported by the provided `LongName` and `UNIT` data.

The main difficulties arose from missing concepts in the candidate list:
*   **Platelet function tests**: Codes `b-adp` and `b-aspi` with `unit=auc` (Area Under Curve) had no matching property in the candidates. Similarly, `b-vasp` (VASP phosphorylation) had no corresponding LOINC concept at all in the list.
*   **Panels and ambiguous codes**: `p-hae`/`s-hae` (Hereditary Angioedema panel) and `p-hepg` (Heparin) were unmappable because the candidates were either for a different test type (genetic vs. protein) or too specific (LMW vs. unfractionated heparin) for an ambiguous code.
*   **Specific analytes**: `s-tati` (Tumor-associated trypsin inhibitor) had no specific concept; the available `Inter alpha trypsin inhibitor` is a precursor and not an exact match.
*   **Uninterpretable codes**: `s-kem` was completely opaque.

In one case (`s-ena`), the data strongly suggested a `[Ratio]` property, which was absent from the candidates. For the `Ts-res` (receptor study) code, I chose a combined `ER+PR` concept as a pragmatic, if imperfect, match in the absence of a true panel concept.

Overall, the provided evidence (especially units and values) was crucial for distinguishing between properties like `[Mass/volume]`, `[Moles/volume]`, `[Units/volume]`, and `[Titer]`.

# Group 51

This group consisted entirely of nucleic acid amplification tests (`-nho` suffix), which made property and method mapping straightforward (`[Presence]` by NAA). Most codes were clearly interpretable abbreviations for specific pathogens.

A significant number of rows could not be mapped due to shortcomings in the candidate list. Specifically:
- Generic organism tests in specific specimens (e.g., `li-baktnho` for bacteria in CSF, `f-baktnho` for bacteria in feces, `resbaktnho` for bacteria in respiratory specimens) lacked matching LOINC candidates.
- Very generic codes like `f-paranho` (parasites in feces) or `bparanho` (parasites in blood) likely represent local panels and have no single corresponding LOINC concept.
- A multiplex test (`-boppnho` for Bordetella pertussis + parapertussis) was clearly indicated by the code but had no matching candidate.

The search strategy should be improved to find candidates for these more complex or specimen-specific generic tests if they exist in LOINC (e.g., 'Bacteria DNA [Presence] in CSF...'). If such concepts do not exist, these codes are correctly unmappable to a single LOINC.

# Group 68

This group contained two distinct sets of tests: microbiology tests for Streptococcus from throat swabs (`Ps-` prefix) and serology tests for Streptococcus pneumoniae antibodies in serum (`S-` prefix). The mapping was generally successful where evidence was available.

For the throat swabs, it was important to distinguish between culture (`-vi`, `-cult`), antigen detection (`-ag`, `-o`), and nucleic acid tests (`-nho`). Most could be mapped confidently. I distinguished between generic Strep A antigen (`3033319`) and rapid antigen (`21491660`), assigning the latter only when the code explicitly suggested it (e.g., `ps-straagp`).

For the S. pneumoniae serology, mapping depended entirely on being able to determine the property (quantity type). Rows with units like `mg/l` or `ug/mlgmc` were mapped to `[Mass/volume]` concepts. Rows with the unit `fmiau/ml` were mapped to `[Units/volume]` concepts when a suitable candidate was available. Several rows with this unit could not be mapped because the candidate list lacked a corresponding `[Units/volume]` concept for that specific serotype. Rows that had value deciles but no unit were successfully mapped by inferring the property from the magnitude of the values. Finally, a significant number of serology rows had no unit or value data, making it impossible to choose between mass and arbitrary unit concentrations; these were correctly left unmapped.

# Group 70

This group was a mix of straightforward mappings and several unmappable codes. The numerous `talt` and `talteen` codes were clearly administrative (sample storage) and were not mapped. The `i-stat` point-of-care tests were easy to map as the components were clear and the `Blood` specimen was appropriate. The large number of testosterone variants (`s-testo`, `s-testo-v`, `s-testo-vl`, etc.) required careful attention to suffixes (`-v` for free, `-vl` for free calculated), units (`nmol/l`, `pmol/l`, `%`), and values to distinguish between total, free, free calculated, and free fraction. 

Several codes could not be mapped due to gaps in the candidate list:
- `fp-gastpan`, `s-pisto1`, `s-pisto2`: These were panels for which no specific panel concept was available.
- `fs-gastr17`, `s-gastr17`: These were for Gastrin-17 in `pmol/l`, requiring a `[Moles/volume]` property. The only candidate had a `[Mass/volume]` property, which was incorrect.
- `s-ustekab`: A qualitative antibody test was needed, but only a quantitative (`[Mass/volume]`) candidate was available.

Some mappings had minor limitations due to the candidates, e.g., mapping `s-hstesto` (high sensitivity) and `s-testoms` (mass spectrometry) to the generic testosterone concept because more specific candidates were absent. The ambiguous code `s-statrae` was also unmappable.

# Group 73

This was a large and diverse group. Many codes were clearly identifiable laboratory tests (Vitamin D variants, Cystatin C, LD isoenzymes, Quetiapine, Salmonella Widal panel) and were mapped with high confidence. The candidate list was excellent for these. A significant number of codes were unmappable as they appeared to be administrative, internal, or procedural codes (e.g., `-kskäynt`, `-selvtyö`, `dnauut1`, `sjukhus`, `s-käsmak`). The search failed for `audit` and `audit-c` (rows 893-895); the correct LOINC concepts for these common questionnaires were not retrieved. The code `s-o4.5.12` for Salmonella Typhimurium O-antigen could only be mapped to a less specific 'Salmonella typhimurium Ab' concept, as a specific O-antigen concept was not available in the candidate list.

# Group 74

This group was mostly straightforward, covering common chemistry tests like amylase, alkaline phosphatase, albumin, and aldosterone. The Finnish naming system with prefixes for specimen (S-, P-, dU-, as-, pf-) and suffixes for qualifiers (-p, -m, -luu, -p, -s) was very consistent and helpful for mapping.

Most rows could be mapped with high confidence, especially those with units and values that confirmed the property. Where units/values were missing, mappings were made with lower certainty based on the name alone.

A few rows were unmappable:
- Rows with uninterpretable names (`s-kudosab`, `s-ngmuut`, `sp-suld`).
- Rows with nonsensical values that contradicted the component and specimen, suggesting data errors (`s-oaldos`, `s-valdos`).
- Rows where the component was clear but the required specific concept was missing from the candidate list (e.g., `s-scl-t` for Scl-70 Ab, `s-gliade` where Ig class was needed).
- One row (`s-adaliab`) was likely qualitative, but a `[Presence]` candidate was not available, preventing a confident mapping.
- `saline` was correctly identified as not a lab test.

The candidate list was generally very good and comprehensive for this group. The main limitation was the lack of a few specific antibody tests (Scl-70, qualitative Adalimumab Ab).

# Group 79

This was a large but relatively straightforward group focused on glucose measurements. The national codes were well-structured, allowing for clear identification of specimen (B-, P-, cB-, U-, fP-), timing in glucose tolerance tests (e.g., -1h, -2h, -120), and test type (e.g., Pt-gluk-r for panels). Most quantitative tests used mmol/l, aligning well with LOINC's `[Moles/volume]` property.

The main challenges were:
1.  **Contradictory evidence for qualitative tests**: Several codes with the qualitative suffix `-O` (e.g., `b-gluk-o`, `p-gluk-o`) had quantitative units or values. For `b-gluk-o`, `value_missing_p` was 100%, suggesting the values/units were data errors, so I mapped based on the `-O` suffix. For `p-gluk-o` (1193), the values seemed real, so I mapped it as quantitative, treating the `-O` as a local coding error.
2.  **Missing candidates**: The list lacked concepts for `Glucose [Presence] in Serum or Plasma` and `Fasting glucose [Presence] in Serum or Plasma`. This left rows like 1138, 1194, 1153, and 1154 unmapped.
3.  **Ambiguous panels**: Several `Pt-gluk-r...` codes for glucose tolerance test panels were too generic (e.g., 'long test') or used unclear suffixes (e.g., `-r8`, `-sd`) to be confidently mapped to a specific duration (2h, 3h, etc.), so they were left unmapped.
4.  **Baseline vs. Fasting**: I standardized on using the `Fasting glucose` concept (3018251) for all baseline (0h) samples in a GTT context, as this is the required patient state and it's a Top2000 concept, preferred over the more generic `--baseline` concept.

Overall, the component (glucose, glucagon), specimen, property, and timing were usually clear from the combination of the Finnish code, units, and values.

# Group 84

This group was dominated by `Pt-` (patient) codes, which represent a wide variety of concepts: individual results (FIB-4, weight), test panels (ACTH stim, lactose tolerance), imaging procedures (PET, SPECT), other procedures (pacemaker evaluation, actigraphy), and administrative items (consultations, patient transport, isolation). 

The candidate list was sufficient for standard lab tests like coagulation assays and some common scores/calculations (FIB-4, TTR). However, it lacked concepts for many of the procedures and panels, especially for imaging (PET scans), specific physiological tests (actigraphy, galactose half-life), and skin allergy testing. Several specific ratios (GT/CDT, ADA fluid/serum) were also missing. A large number of codes were unmappable because they were either uninterpretable, too generic, or clearly administrative rather than clinical.

# Group 85

This group was a mix of clearly identifiable tests, generic/administrative codes, and tests where the correct LOINC concept was missing from the candidate list. 

**Successfully mapped:**
- `p-lupusak` was clearly Lupus Anticoagulant, and the interpretation concept was a good fit for the overall result.
- The various `pt-audio` codes were well-matched to the general `Diagnostic audiology results panel`.
- Bone density (`pt-luutih`/`pt-luutil`) and stress echo (`pt-rasukg`) had perfect panel matches.

**Unmapped due to ambiguity/genericity:**
- `p-pbmcbio` was contradictory.
- `ps-nieluag` was underspecified (missing the antigen name).
- `pt-kudsop` (histocompatibility) was too generic for the specific HLA panels offered.
- Several codes like `patlislaus` and `pt-lisälau` were clearly administrative codes for 'additional reports' with no direct test equivalent.

**Unmapped due to missing candidates:**
- The search failed to retrieve appropriate concepts for several clear tests: `pt-audit` (AUDIT score), `pt-luuspeg` (Bone SPECT), `pt-luustog` (Bone Scan), and `puheaudio` (Speech audiometry). The `loinc_name_guess` was often correct, but the subsequent search did not provide the right target, highlighting a weakness in the search step for these specific terms.

# Group 87

This group was dominated by histopathology codes (`Ts-PAD...`) and one Papanicolaou smear code (`Pt-PAPA...`).
*   The numerous variations of `Ts-PAD` (histopathology on tissue) were mapped to a single generic concept for microscopic observation of tissue with H&E stain (`3011173`). This assumes H&E is the default unspecified stain, which is standard pathology practice. Suffixes indicating specific tissue types (e.g., `-colo` for colon, `-gast` for stomach) could not be mapped to more specific LOINC concepts as none were present in the candidate list. The mapping is still correct at the general tissue level.
*   Specific methods were mappable when candidates were available: `ts-pad-em` (electron microscopy) and `ts-pad-if` (immunofluorescence) were mapped successfully.
*   Several key pathology methods were unmappable due to a deficient candidate list. Codes for immunohistochemistry (`-ih`), in situ hybridization (`-ish`), FISH (`-fish`), frozen section (`-pika`), and gross/macroscopic observation (`-makr`) all had clear local names but no corresponding LOINC concept was retrieved. The relevant LOINC codes would be `8122-3` (...by Immune stain for IHC), `8124-9` (...by In situ hybridization for ISH), `8123-1` (...by FISH), `8121-5` (...by Frozen section), and `33729-3` (Gross description... for macroscopic). The search query generation or the search itself seems to have failed for these common pathology terms.
*   The Pap smear (`Pt-PAPA-1`) was successfully mapped to `Microscopic observation [Identifier] in Cervix by Cyto stain` (`3025378`).
*   A qualitative amyloid test (`ts-aa-o`) was also successfully mapped (`3011035`).

The main issue was the incomplete candidate list for common pathology procedures. Otherwise, the mapping was straightforward.

# Group 89

This was a large but straightforward group focused on ionized calcium. The Finnish codes were very systematic, clearly indicating the specimen (Arterial, Venous, Capillary blood; Serum; Plasma; Dialysis fluid) and whether the result was adjusted to pH 7.4. The candidate list was excellent and covered almost all variations perfectly.

The main points of ambiguity were:
1.  Codes specifying a specific plasma type (Arterial, Venous, Capillary plasma, e.g., `ap-ca-ion`, `vp-ca-ion`). Since the candidate list lacked these specific LOINC concepts, I consistently mapped them to the more general but appropriate `... in Serum or Plasma` concept. This is a reasonable abstraction.
2.  The `fb-nh4-ion` code (Ammonium ion in Blood). The candidate list forced a choice between the correct analyte (`Ammonium ion` in Plasma) and the correct specimen (`Ammonia` in Blood). Given the specimen prefix `B-` is a strong indicator, I chose the concept for Blood, accepting the slight analyte name mismatch, but with medium certainty.
3.  Some prefixes like `mB-` were not in the provided `prefix_meaning` column. I mapped them to the most generic specimen type that fit (`Blood` instead of `Mixed venous blood`) to be safe.

Overall, the mapping was very successful, with most rows mapped with high certainty.

# Group 105

This group was dominated by coagulation tests. I could map most of them successfully, especially the coagulation factors (VII, VIII, IX, XI, XII, XIII) where candidates with the `actual/normal` property were available to match the `%` unit. The von Willebrand factor tests were also well-covered.

There were several significant gaps in the candidate list. The most striking was the complete absence of a basic aPTT concept with a `Time` property, making it impossible to map `p-aptt` and its variants (rows 1558-1562, 1564-1565). Similarly, concepts for ADAMTS13 activity (1547-1548), Factor II activity (1572-1573), and recombinant Factor VIII activity (1588-1590) were missing, preventing mapping of these clearly defined local codes. These are common tests, and their absence suggests a limitation in the initial search query generation or the search process itself.

I made a more specific mapping for the DOACs Apixaban (1549-1550) and Rivaroxaban (1551-1552) based on the local code `afxa` (anti-Factor Xa), choosing candidates with the `Chromogenic method`. This is more precise than a generic mass concentration concept.

The lupus anticoagulant (LA) and dRVVT codes (`p-fs-mix`, `p-fsl-mix`, `p-fsl/fs`, `p-la1-mix`, etc.) were challenging due to the cryptic local names, but by looking at them as a group, I could infer their meaning (screen, confirm, mix, ratio) and map them to appropriate dRVVT-related concepts.

One minor issue was mapping `p-pg1/pg2` (plasma) to a serum-only concept, which I did with medium certainty, noting the specimen mismatch.

# Group 106

This group contained a wide variety of tests, many of which were clearly identifiable by their standard Finnish abbreviations and prefixes (e.g., `B-`, `P-`, `S-`, `Li-`, `Pf-`). The presence of units and value distributions was crucial for confirming the property (Moles/volume vs Mass/volume) and, in some cases, the specimen (e.g., `uraatti`).

Several rows were left unmapped due to ambiguity. 
- Cryptic or mangled codes like `-omactgc`, `hpvpapctgc`, and `hpvrefctgc` were difficult to interpret with certainty. 
- Generic panel codes like `p-hyyttek` (coagulation factors) and `p-vuotot` (bleeding tendency) could not be matched to the specific panel concepts in the candidate list. 
- Several rows for lupus anticoagulant testing (`p-laaptva`, `p-luakptt`, `p-luakrvv`) were unmappable because the candidates did not include concepts for the specific reported results (e.g., screening ratios), focusing instead on panels or confirmation tests.
- Administrative codes (`f-projekti`, `p-haglund`) were correctly identified as unmappable.

For many tests, rows without units or values could not be mapped because both Molar and Mass concepts existed (e.g., Haptoglobin, Lactate). However, for analytes like Potassium and Sodium, where molar units are overwhelmingly standard, a mapping was made with medium confidence even without explicit evidence of property.

# Group 110

This group consisted primarily of microbiology culture codes, many of which were clearly identifiable from their abbreviations (e.g., `-gcvi` for Gonococcus culture, `-mrsavi` for MRSA culture). Most codes were successfully mapped with high certainty. 

Several challenges arose: 
1.  **Missing specific candidates:** For some common tests, the candidate list was missing the most precise concept. For example, `ex-tbvivr` (TB smear and culture from sputum) had no corresponding panel in the list. Similarly, `u-mrsavi` (MRSA from urine) and `ns-staurvi` (S. aureus from nose) had no specimen-specific candidates. A broader search might have found these.
2.  **Genus vs. Species:** For Mycobacterium tuberculosis cultures (`-tbvi`, `ex-tbvi`), the `LongName` specified *tuberculosis*, but the best available candidate was for *Mycobacterium sp*. I mapped to the genus-level concept as a compromise.
3.  **Ambiguous codes:** A few codes like `-em-bl`, `-ervr`, and `-respvt` were too cryptic or generic to map reliably without more information on the test method or components. 
4.  **Non-lab codes:** One code (`1.savuk`) was for a patient-reported observation (cigarettes smoked) and was correctly left unmapped as it's not a laboratory test and had no fitting LOINC code in the provided list.

# Group 111

This group contained a wide variety of tests, including tumor markers (CA 12-5, 15-3, 19-9), C-peptide, C-reactive protein (CRP), hCG, complement, CK isoenzymes, and several pharmacogenetic tests (CYP genes). Mapping was generally successful and straightforward, especially for the common chemistry tests where specimen, analyte, and property were clear from the Finnish code and unit.

Several challenges were noted:
1.  **Missing Concepts**: The candidate list lacked concepts for `CYP3A5` (solo), `CYP4F2`, and a ratio of beta-HCG to total HCG (`-hcgbsuh`). These rows could not be mapped.
2.  **Ambiguous Suffixes**: The suffix `-o` is meant to be qualitative, but for CRP tests (e.g., `b-crp-o`, `s-crp-o`), it often appeared on rows with quantitative units and values. In these cases, the quantitative evidence was prioritized over the suffix, but for rows with only the name, the suffix was followed, leading to different mappings for the same code. This reflects real-world variability where a test might be used both qualitatively and quantitatively.
3.  **Vague Suffixes**: Many codes had suffixes like `-hy`, `-lb`, `-os`, `/d`, `-tth` which appear to be local lab or administrative codes. These were ignored in favor of the core test name.
4.  **Specimen Mapping**: `B-` (Blood) codes for CRP were mapped to the `Serum, Plasma or Blood` LOINC concept, as a specific `Blood` concept for mass concentration wasn't available and this is the recommended broader term.

# Group 121

This group was dominated by urinalysis tests, including routine chemistry, drug screens, and microscopic sediment analysis. The mappings were generally straightforward. Many rows lacked units and values, making it impossible to determine the property (e.g., mass concentration vs. mass ratio, or count/volume vs. count/area); these were left unmapped.

The `-o` suffix for qualitative tests was consistently mapped to screening concepts (`...by Screen method` or `...by Test strip`) where available, as this is more specific than a simple `[Presence]` concept. For drug screens (`huum-`), I mapped the generic screens and the 5-panel screen, but could not map local panels (`-10`, `-4a`, `-6a`) or combined drug/medication panels (`-huuml-`) as no corresponding concepts were in the candidate list.

The distinction between manual microscopy (`#/area`) and automated microscopy (`#/volume`) was handled based on the units (`u/field` vs `e6/l`). Codes for Albumin/Creatinine ratio were mapped to the `Microalbumin/Creatinine [Mass Ratio]` concept (3001802), which is in the LOINC Top 2000 and represents the most common clinical use case for this test.

# Group 126

This was a large and complex group. The primary difficulty was the candidate list's omission of the standard LOINC concept for HbA1c reported in IFCC units (`mmol/mol`), which has a `[Substance Ratio]` property. The `b-ghba1c` and `b-hba1c` codes are used for both NGSP (`%`) and IFCC (`mmol/mol`) units. While I could confidently map the rows with `%` units to the `[Mass Fraction]` concept (3004410), all rows with `mmol/mol` units or values indicative of `mmol/mol` had to be left unmapped. This affected a very large number of rows (e.g., 2109, 2130, 2163). A secondary issue was with some specific methods, like Hemoglobin by IEF (`b-hb-ief`) or HbF by Flow Cytometry (`b-hbf-fc`), for which no corresponding candidates were available. The HLA typing section was also challenging due to the mix of highly specific and very generic local codes, but the candidate list was sufficient for the most clearly defined ones (e.g., those specifying high resolution or a specific allele like for Abacavir sensitivity). Finally, one code (`b-hkr`) was used for two different analytes (Hematocrit and MCV), which I had to disambiguate using the units and value ranges.

# Group 129

This group was large and covered two main areas: lactate measurements and bacteriology. 

**Lactate tests** were generally easy to map. The Finnish prefixes (`aB`, `vB`, `fP`, `Li`, etc.) corresponded well to LOINC specimens (Arterial blood, Venous blood, Plasma, CSF). The unit `mmol/l` and value distributions reliably indicated the `[Moles/volume]` property. Rows without units or values were left unmapped as the property (moles vs. mass) could not be determined.

**Bacteriology tests** were more complex. 
- **Cultures (`-vi`)**: These were mostly straightforward, mapping to 'Bacteria identified in [Specimen] by Culture'. Specimen prefixes (`B-`, `Li-`, `Ex-`, `Pu-`, etc.) were key. Some culture panels (`f-baktvi1`) had exact LOINC matches, while others (`f-baktvi2`) did not. For `pu-baktvi1/2`, the `LongName` provided crucial detail about 'deep' vs 'surface' pus, allowing mapping to 'Abscess' and 'Wound' respectively.
- **Stains (`-vr`)**: These were difficult. The candidate list often lacked generic stain concepts. I mapped `li-baktvr` (CSF) and `pf-baktvr` (pleural) to their respective 'Microscopic observation by Gram stain' concepts, as Gram stain is the standard method in these contexts. However, more generic codes like `-baktvr` were unmappable.
- **Subcultures (`-jvi`)**: Codes for subculture (e.g., `b-baktjvi`, `u-baktjvi`) are common in the source data but represent a laboratory workflow step (re-culturing from a primary positive plate) that doesn't have a direct equivalent LOINC concept for a reportable result. These were left unmapped.
- **Urine bacteriology**: This was a varied set. I distinguished between quantitative automated counts (`u-bakt` with values or `e6/l` unit), qualitative screens (`u-baktseu`), microscopy of sediment (`u-sakka,bakt`), and cultures (`u-baktvi`). The evidence in each row (unit, values, name qualifiers) was essential for differentiation.

Overall, the candidate list was very good for the common tests but had gaps for less common specimens (e.g., nucleic acid test in periodontal pocket) or methods (generic stains, subcultures). The provided `LongName` and prefix/suffix meanings were invaluable.

# Group 155

This group was a mix of individual analytes, panels, procedural codes, and ambiguous names. Most of the standard chemistry and hematology tests were easily mapped to their top-2000 LOINC equivalents, especially when units and values were present (e.g., the `perusterveyspaketti` components, NT-proBNP, Urate). The many variations for Red Cell Distribution Width (RDW) and Specific Gravity were consistently mapped to the appropriate LOINC concepts based on units (`%` for RDW ratio) and method qualifiers (`stix`, `vieritesti` for specific gravity). 

Several codes were unmappable because they were administrative or procedural (e.g., `näytteenotto` for sampling, `talteen` for storing, `konsultaatiopyyntö` for consultation). Some were clinical ordering panels without a direct LOINC equivalent in the candidate list (e.g., `verenpainetauti,erotusdiagnostiikka`). A few were too generic to be safely mapped (e.g., `mittaustulos`). 

The candidate list had a few gaps. There was no concept for point-of-care HbA1c (row 2417), preventing a map for a very specific local code. Similarly, a panel for only respiratory bacteria by NAA was missing (row 2478). For RDW, the concepts were a bit confusing; I chose the one with the `[Ratio]` property for all the `%`-unit rows, but it's a known area of mapping difficulty in LOINC. For `virtsan solut` (urine cells), no specific LOINC for total cells in urine was present, forcing a fallback to a generic `Body fluid` concept with low certainty.

# Group 156

This group was mostly straightforward, with many common chemistry tests (creatinine, thyroid hormones, urea) and some microbiology cultures. The Finnish names were generally clear and mapped well to standard LOINC concepts. The presence of units and value deciles for most rows was extremely helpful in confirming the property (e.g., Moles/volume vs Mass/volume).

Mapping challenges:
*   Rows without units or values could not be mapped, as the property (e.g., Moles vs Mass vs Units) was ambiguous. This affected a significant minority of rows.
*   Panel requests were sometimes tricky. `proteiini, fraktiot` (protein fractions) mapped well to the protein electrophoresis panel. However, `immunofiksaatio` (immunofixation, row 2534) and `sieni, viljely ja natiivi` (fungus culture and microscopy, row 2597) did not have corresponding panel concepts in the candidate list, so they were left unmapped.
*   The generic `hiiva, viljely, limakalvo` (yeast, culture, mucous membrane, row 2533) had to be mapped to a less specific 'Fungus in Specimen' concept due to a lack of more precise candidates for yeast or mucous membrane.

The candidate list was comprehensive for single analytes. The primary reason for not mapping a row was the lack of quantitative information (`UNIT` or `value_deciles`) in the source data for that row.

# Group 162

This was a diverse group with a mix of routine chemistry, hematology, genetics, and cytology. The mappings were generally successful. Many local codes mapped well to specific, Top 2000 LOINC concepts, especially for common hematology (Eosinophils, Neutrophils) and genetic tests (F5, F2, JAK2, LCT). 

The main challenge was the lack of appropriate candidates for some tests. Specifically:
- Cytology tests for bronchial fluid (rows 2639, 2640) and pleural fluid (row 2667) could not be mapped because the candidate list only contained quantitative cell counts, not general cytology/pathology review concepts for those specimens.
- Vitamin K2 tests (rows 2655-2658) for menaquinone-4 and menaquinone-7 had no matching candidates; the available concept was for Vitamin K3 (menadione).
- A panel for Vitamin K1 and K2 (row 2652) was also missing a candidate.

For Borrelia confirmation tests (2671-2674), the local name specified a 'confirmation test' (`varmistustutkimus`), which strongly implies immunoblot. However, no quantitative immunoblot candidate was available. I chose the concept with the correct component/property/system but an unspecified method, which felt like the safest and most accurate choice given the options.

For the TSH reflex test (row 2679), no true reflex LOINC was available, so I mapped it to the panel of the involved analytes (TSH and Free T4) as a pragmatic solution.

