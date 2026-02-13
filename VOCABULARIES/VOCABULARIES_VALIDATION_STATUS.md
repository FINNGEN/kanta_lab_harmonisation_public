# Vocabularies Validation Status

This is an automatically generated log file by ROMOPMappingTools to detect changes by the github diffs, DO NOT EDIT.

ROMOPMappingTools version: 2.1.2

### Summary

|context   | SUCCESS| WARNING| ERROR|
|:---------|-------:|-------:|-----:|
|LABfi_ALL |      32|       4|     0|

### Full log

|context   |type    |step                                                           |message                                                                                   |
|:---------|:-------|:--------------------------------------------------------------|:-----------------------------------------------------------------------------------------|
|LABfi_ALL |SUCCESS |Missing default columns                                        |                                                                                          |
|LABfi_ALL |SUCCESS |SourceCode is empty                                            |                                                                                          |
|LABfi_ALL |SUCCESS |SourceCode and conceptId are not unique                        |                                                                                          |
|LABfi_ALL |SUCCESS |SourceCode is more than 50 characters                          |                                                                                          |
|LABfi_ALL |SUCCESS |SourceName is empty                                            |                                                                                          |
|LABfi_ALL |SUCCESS |SourceName is more than 255 characters                         |                                                                                          |
|LABfi_ALL |SUCCESS |SourceFrequency is not empty                                   |                                                                                          |
|LABfi_ALL |SUCCESS |MappingStatus is empty                                         |                                                                                          |
|LABfi_ALL |SUCCESS |MappingStatus is not valid                                     |                                                                                          |
|LABfi_ALL |SUCCESS |APPROVED mappingStatus conceptId is 0                          |                                                                                          |
|LABfi_ALL |SUCCESS |APPROVED mappingStatus with concepts outdated                  |                                                                                          |
|LABfi_ALL |SUCCESS |Not APPROVED mappingStatus with concepts outdated              |                                                                                          |
|LABfi_ALL |SUCCESS |Missing C&CR columns                                           |                                                                                          |
|LABfi_ALL |SUCCESS |SourceConceptId is empty                                       |                                                                                          |
|LABfi_ALL |SUCCESS |SourceConceptId is not a number on the range                   |                                                                                          |
|LABfi_ALL |SUCCESS |SourceConceptClass is empty                                    |                                                                                          |
|LABfi_ALL |SUCCESS |SourceConceptClass is more than 20 characters                  |                                                                                          |
|LABfi_ALL |SUCCESS |SourceDomain is empty                                          |                                                                                          |
|LABfi_ALL |SUCCESS |SourceDomain is not a valid domain                             |                                                                                          |
|LABfi_ALL |SUCCESS |Not APPROVED mappingStatus with valid domain combination       |                                                                                          |
|LABfi_ALL |SUCCESS |APPROVED mappingStatus with valid domain combination           |                                                                                          |
|LABfi_ALL |SUCCESS |Missing date columns                                           |                                                                                          |
|LABfi_ALL |SUCCESS |SourceValidStartDate is after SourceValidEndDate               |                                                                                          |
|LABfi_ALL |SUCCESS |Missing parent columns                                         |                                                                                          |
|LABfi_ALL |SUCCESS |Invalid parent concept code                                    |                                                                                          |
|LABfi_ALL |SUCCESS |LAB: Invalid lab source name format                            |                                                                                          |
|LABfi_ALL |SUCCESS |LAB: APPROVED Invalid lab unit                                 |                                                                                          |
|LABfi_ALL |WARNING |LAB: not APPROVED Invalid lab unit                             |Found 622 not APPROVED lab source codes where unit is not in validUnitsList or is NA      |
|LABfi_ALL |WARNING |LAB: Invalid lab mapped domain                                 |Found 10 mapped lab source codes where domain is not 'Measurement'                        |
|LABfi_ALL |SUCCESS |LAB: APPROVED Invalid lab quantity                             |                                                                                          |
|LABfi_ALL |WARNING |LAB: not APPROVED Invalid lab quantity                         |Found 514 not APPROVED lab source codes where test unit does not agree with omop_quantity |
|LABfi_ALL |WARNING |LAB: TestName with same quantity maps to different concept ids |Found 4 codes with testName with same quantity maps to different concept ids              |
|LABfi_ALL |SUCCESS |Missing required columns                                       |                                                                                          |
|LABfi_ALL |SUCCESS |TEST_NAME_ABBREVIATION source_unit_clean is unique             |                                                                                          |
|LABfi_ALL |SUCCESS |TEST_NAME_ABBREVIATION is empty                                |                                                                                          |
|LABfi_ALL |SUCCESS |TEST_NAME_ABBREVIATION source_unit_clean_fix pair valid        |                                                                                          |


