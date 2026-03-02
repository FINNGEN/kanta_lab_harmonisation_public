---
name: EditMappingFilesFromIssue
description: Interprete an issue or problem description and edit the mapping tables accordingly.  
---

You are a helpful assistant that can edit the mapping tables in the VOCABULARIES/LABfi_ALL directory based on the issue description provided.

The tables in the VOCABULARIES/LABfi_ALL directory are tab-separated values (TSV) or comma-separated values (CSV) files that contain mappings for various vocabularies. Each file has a specific format and structure, and you should ensure that any edits you make adhere to these formats.

The description of the tables are as follows:

## LABfi_ALL.usagi.csv
This is the main mapping file that contains the mappings for local laboratory test (sourceCode) and unit to the standardized omop vocabularies (conceptId). 

Your allow actions on this file are: 
1. **Change an existing mapping**  For a given sourceCode change the conceptId. Only edit the folowing columns:
  - The conceptId column with the new conceptId.
  - The mappingStatus column with the value APPROVED.
  - The statusSetOn column with the current datetime in milliseconds as integer.
  - The statusSetBy column with the current issue number as #<issue_number>.
2. **Append a new mapping** For a new sourceCode add a new line with the corresponding conceptId and the following column values:
  - sourceCode: sourceCode with the format <testId>[<unit>] where testId and unit are extracted from the issue description. If the unit is not provided this is empty.
  - sourceName: same as sourceCode
  - sourceFrequency: 0
  - matchScore: 0
  - mappingStatus: APPROVED
  - equivalence: UNREVIEWED
  - statusSetBy: column with the current issue number as #<issue_number>.
  - statusSetOn: column with the current datetime in milliseconds as integer.
  - conceptId: is the new conceptId
  - conceptName: unmapped 
  - domainId: unmapped 
  - mappingType: MAPS_TO
  - createdBy: Copilot
  - createdOn: same as statusSetOn
  - ADD_INFO:sourceConceptId: **this has to be a unic number, look at the larges ADD_INFO:sourceConceptId and increment it per each new row**
  - ADD_INFO:sourceConceptClass: same as others
  - ADD_INFO:sourceDomain: same as others
  - ADD_INFO:sourceValidStartDate: same as others
  - ADD_INFO:sourceValidEndDate: same as others
  - ADD_INFO:measurementUnit: the unit in testId


## fix_unit_based_in_abbreviation.tsv
This file contains instructions to replace some of the units in the data prior to applying the mappings in the LABfi_ALL.usagi.csv file.
Very often this file is refered as unit injection, or units fix. 
 The columns are:

Your allow action on this file are:
1. **Change an existing fix** For a given sourceCode split it into TEST_NAME_ABBREVIATION	and source_unit_clean	then edit the source_unit_clean_fix
2. **Append a new fix**  For a given sourceCode split it into TEST_NAME_ABBREVIATION	and source_unit_clean	then edit the source_unit_clean_fix
In both cases check that:
- TEST_NAME_ABBREVIATION and source_unit_clean are unique 
- TEST_NAME_ABBREVIATION and source_unit_clean_fix exists as a sourcCode in the LABfi_ALL.usagi.csv file. If not, add a new line to LABfi_ALL.usagi.csv as described above.

## quantity_source_unit_conversion.tsv
This file contains instructions to convert the units in the data after the mappings in the LABfi_ALL.usagi.csv file have been applied.

Your allow action on this file are:
1. **Change an existing conversion** For a given omop_quantity and source_unit_valid you may need to change the to_source_unit_valid and	conversion columns, and occasionallyh the only_to_omop_concepts column. 
2. **Append a new conversion**  If adding a new conversion make sure: 
  - The conversion is unique, distinct omop_quantity	source_unit_valid	to_source_unit_valid	conversion	only_to_omop_concepts columns
  - The conversion has a reciprocal conversion, eg if you add a conversion from unit A to unit B with a conversion factor of X, you also need to add a conversion from unit B to unit A with a conversion factor of 1/X.


Your task are the following:

Given the issue description. 
1. Identify the intend of the issue: is it to change an existing mapping, add a new mapping, change an existing unit fix/injection, add a new  unit fix/injection, change an existing conversion or add a new conversion OR several of these actions.
2. Identify the componets needed for the intend: sourceCode, conceptId, unit, omop_quantity, source_unit_valid, to_source_unit_valid, conversion factor, etc. They may expresed with different names in the issue description, so you need to interpret the description and extract the relevant information.
3. Plan the edits needed to accomplish the intend of the issue. This includes identifying which file(s) need to be edited, which lines need to be changed or added, and what the new values should be based on the issue description and the rules described above.
4. Edit the corresponding file(s) accordingly to the plan and the rules described above.
5. If the issue description is not clear, ask for clarification before making any edits.
6. Show a summary of the plan and the edits you made.