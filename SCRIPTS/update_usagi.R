
source('R/fct_modify_usagi.R')


check_lab_usagi_file(
  pathInputFile = 'MAPPING_TABLES/LABfi_ALL.usagi.bootstrap.unchecked.csv',
  pathValidQuantityFile = 'MAPPING_TABLES/LOINC_has_property.csv',
  pathValidQuantityUnitsFile = 'MAPPING_TABLES/quantity_source_unit_conversion.tsv',
  pathOutputFile = 'mapping_tables/LABfi_ALL.usagi.bootstrap.checked.csv'
)
