# Manteinace of the harmonisation tables for Kanta laboratory codes, units, and values

This repository contains several tables used for the harmonisation Kanta laboratory data, but also scripts to validate the tables correctness and aid the harmonisation process. 


## Background

Mapping a diagnose code to a harmonizing code is relatively straight forward, as the diagnose code has only one component.
Eg. `ICD-10` code `I10` for `Essential (primary) hypertension` maps to `SNOMED CT` code `320128`, for `Essential hypertension`.
However, harmonizing a laboratory test is more complex, as it has three components, test code, unit, and value.
Eg, `s-dmklots` is a lab code that measures `Norclozapine in serum`, maps to `LOINC` code `14851-0`, for `Norclozapine [Moles/volume] in Serum or Plasma`, units may be `µmol/L`, `µmol/mL`, etc, and the value may be `100`, `0.1`, etc.
 
This presents two challenges:

- The combination of test code, unit and values that appears in the source data is very large, Eg `s-dmklots`+`µmol/L`+`100`, `S-dmklots`+`umol/L`+`100`, `sdmklots`+`mmol/l`+`0.1`, etc
- Not all combinations of test code, unit and values are valid, Eg `s-dmklots`+`µmol/L`+`100` is valid, but `s-dmklots`+`kg/L`+`100` is not valid, and hence should be fixed or not harmonised.

To solve the former, rather than having one mapping table, like in the case of diagnoses, we have several tables that harmonise the different components separately or combined.
To solve the latter, we have validation tables and scripts that checks if the combination of test code, unit and value is valid.

## Usage

This repository can be used in two modes:

### For harmonising the source data. 

In this mode, the harmonisation tables are read-only. The tables are read by the scripts in [FINNGEN/kanta_lab_preprocessing](https://github.com/FINNGEN/kanta_lab_preprocessing) and used to harmonise the source data after a pre cleaning process. 

Details on how to use in [doc/preprocessing.md](doc/preprocessing.md).

### For maintaining the harmonisation tables.

In this mode, the harmonisation tables may be edited. 
It takes a summary of the source data, with the counts of test code and unit combinations, and the percentile distribution of the values.
This summary data undergoes the same harmonisation process than above, and outputs a summary with the status of the harmonisation for each test code and unit combinations. 

The summary data is then used to update the harmnisation tables, by adding new mappings or correcting existing ones.

Details of this mode in and [doc/harmonisation.md](doc/harmonisation.md)

The following link shows the current status of the mappings: 

[MappingStatusDashboard](https://finngen.github.io/kanta_lab_harmonisation_public/)

