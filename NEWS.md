# Kanta Harmonisation v3.0.0
- Refactoring of the codebase
    - New dashboard
    - Connected to CDM db
- Updated Usagi Files
- Updated the Kanta summary to the updated release of data (this introduces new missing mappings)

# Kanta Harmonisation v2.1.0
- Changed 19 SNOMED codes to LOINC 
- Marked b-trombot (Thrombophilia screening test) as having no mapping 
- Corrected values originally reported as mmol/l to harmonized umol/l 
- Mapped all INR measurements to 3032080 instead of 3022217 
- Investigated mapping issue for myasthenia gravis Rarer autoantibody code; lacked enough rows to choose between 3041276 and 40760548 
- Consolidated two OMOP codes (42870588, 40760892) for complete blood count under 40760892 
- Fixed incorrect creatinine units (mmol/l instead of umol/l); transformed values by multiplying by 1000 

Details: Fixing errors reported in KANTA LAB DATA CORRECTIONS LOG (snapshot 17.1.2024) #38

# Kanta Harmonisation v2.0.1
- hotfix empty value in `LABfi_ALL.usagi.csv` for `ADD_INFO:measurementUnit` for 2 rows

# Kanta Harmonisation v2.0.0

Major changes :
- Accept all codes in measurement domain even if they are SNOMED
- Codes with 'ERROR; Mapping: cannot map without unit, multiple targets' are mapped to the most common unit, for codes with n events over 5000

Minor changes:
- Added mappings made by MP with Claude AI

# Kanta Harmonisation v1.3.0

Major changes :

- Added abbreviation with no unit combinations from FinnGen missing in LABfi_ALL.usagi.csv
- Accept all the classes of the LOINC as far as they are measurement domain
- Accept quantities 'Finding', 'Presence or identity' and 'Presense or threshold' to have NA units
- Accept 'Presense or threshold' estimate unit to be interchangeable with NA unit

Minor changes:

- Added few new mappings for panes from Elisa 
- change 'u/field' to 'hpf'  in UNITSfi.usagi.csv
- unit conversion to the top test with unit
- added abnormaliy colum distribution to viewer

# Kanta Harmonisation v1.2.0

- Added new mappings from FinOMOP for the missing code with no unis

#Kanta Harmonisation v1.1.0

Major changes :

- Added 2816 new mappings to LABfi_ALL.usagi.csv for lab codes with no unit, these were created from the existing mappings if all lab codes with different units mapped to same conceptId
- modified check_lab_usagi_file, to create automatically mappings to lab codes with no units 

# Kanta Harmonisation v1.0.0

Major changes :

- Update to work with summary of the real Finngen counts

Minor changes:

- Sam fixes in the usagi file 

# Kanta Harmonisation v0.3.0

- Updates by Sam, mostly 'ERROR; Units: Units dont match quantity'


# Kanta Harmonisation v0.2.0

- Updates by Tarja, completed unmapped using mapped as reference


#  Kanta Harmonisation v0.1.0

- LABfi usagi files from FinOMOP
- Fixed UNITSfi usagi deom FinOMOP
- Fixed maps by Tarja Laitines  
