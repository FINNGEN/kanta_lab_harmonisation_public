#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
testnameUnitToConceptidFile <- args[1]
measurementConceptAttributesFile <- args[2]
loincGroupMembershipFile <- args[3]
conceptidTargetUnitFile <- args[4]
quantitySourceUnitConversionFile <- args[5]
outDir <- args[6]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  testnameUnitToConceptidFile = ", testnameUnitToConceptidFile)
ParallelLogger::logInfo("  measurementConceptAttributesFile = ", measurementConceptAttributesFile)
ParallelLogger::logInfo("  loincGroupMembershipFile = ", loincGroupMembershipFile)
ParallelLogger::logInfo("  conceptidTargetUnitFile = ", conceptidTargetUnitFile)
ParallelLogger::logInfo("  quantitySourceUnitConversionFile = ", quantitySourceUnitConversionFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
readTsv <- function(file) {
  # character columns throughout: ids and conversions are joined as text, and a
  # CONVERSION can be a formula in X
  tbl <- readr::read_tsv(file, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
  ParallelLogger::logInfo("Read ", nrow(tbl), " rows from ", file)
  tbl
}
testnameUnitToConceptid <- readTsv(testnameUnitToConceptidFile)
measurementConceptAttributes <- readTsv(measurementConceptAttributesFile)
loincGroupMembership <- readTsv(loincGroupMembershipFile)
conceptidTargetUnit <- readTsv(conceptidTargetUnitFile)
quantitySourceUnitConversion <- readTsv(quantitySourceUnitConversionFile)

#
# --- Action -------------------------------------------------------------
#

# 1. Base: one row per TEST_NAME + MEASUREMENT_UNIT with its concept_id.
result <- testnameUnitToConceptid |>
  dplyr::rename(concept_id = OMOP_ID)

# 2. Append the measurement concept attributes by concept_id.
result <- result |>
  dplyr::left_join(measurementConceptAttributes, by = "concept_id")

# 3. Append the LOINC Group, only group_concept_id. A concept belongs to several
#    Groups, so this adds one row per Group.
result <- result |>
  dplyr::left_join(
    loincGroupMembership |> dplyr::select(concept_id, group_concept_id),
    by = "concept_id",
    relationship = "many-to-many"
  )

# 4. Append the target unit by concept_id (one target unit per concept).
conceptidTargetUnit <- conceptidTargetUnit |>
  dplyr::rename(concept_id = OMOP_ID)
result <- result |>
  dplyr::left_join(conceptidTargetUnit, by = "concept_id")

# 5. Append the conversion by has_property + MEASUREMENT_UNIT + TARGET_UNIT. A rule
#    with ONLY_TO_OMOP_CONCEPTS applies only to that concept_id, and wins over the
#    general rule of the same keys.
conversion <- quantitySourceUnitConversion |>
  dplyr::transmute(
    has_property = `harmonization_omop::OMOP_QUANTITY`,
    MEASUREMENT_UNIT,
    TARGET_UNIT = TO_MEASUREMENT_UNIT,
    CONVERSION,
    ONLY_TO_OMOP_CONCEPTS
  )
conversionGeneral <- conversion |>
  dplyr::filter(is.na(ONLY_TO_OMOP_CONCEPTS)) |>
  dplyr::select(-ONLY_TO_OMOP_CONCEPTS)
conversionConcept <- conversion |>
  dplyr::filter(!is.na(ONLY_TO_OMOP_CONCEPTS)) |>
  tidyr::separate_longer_delim(ONLY_TO_OMOP_CONCEPTS, delim = ";") |>
  dplyr::transmute(
    has_property, MEASUREMENT_UNIT, TARGET_UNIT,
    concept_id = trimws(ONLY_TO_OMOP_CONCEPTS),
    CONVERSION_CONCEPT = CONVERSION
  )
ParallelLogger::logInfo(
  nrow(conversionGeneral), " general conversion rules, ",
  nrow(conversionConcept), " concept-specific conversion rules"
)

result <- result |>
  dplyr::left_join(conversionGeneral, by = c("has_property", "MEASUREMENT_UNIT", "TARGET_UNIT")) |>
  dplyr::left_join(conversionConcept, by = c("has_property", "MEASUREMENT_UNIT", "TARGET_UNIT", "concept_id")) |>
  dplyr::mutate(CONVERSION = dplyr::coalesce(CONVERSION_CONCEPT, CONVERSION)) |>
  dplyr::select(-CONVERSION_CONCEPT) |>
  dplyr::arrange(TEST_NAME, MEASUREMENT_UNIT, group_concept_id)

nPairs <- nrow(dplyr::distinct(result, TEST_NAME, MEASUREMENT_UNIT))
ParallelLogger::logInfo(nPairs, " TEST_NAME/MEASUREMENT_UNIT pairs in ", nrow(result), " rows")
ParallelLogger::logInfo(
  dplyr::n_distinct(result$TEST_NAME[is.na(result$concept_code)], result$MEASUREMENT_UNIT[is.na(result$concept_code)]),
  " pairs whose concept_id is not in measurement_concept_attributes"
)
nNoTarget <- nrow(dplyr::distinct(result |> dplyr::filter(is.na(TARGET_UNIT)), TEST_NAME, MEASUREMENT_UNIT))
ParallelLogger::logWarn(nNoTarget, " pairs have no TARGET_UNIT")
nNoConversion <- nrow(dplyr::distinct(result |> dplyr::filter(!is.na(TARGET_UNIT), is.na(CONVERSION)), TEST_NAME, MEASUREMENT_UNIT))
ParallelLogger::logWarn(nNoConversion, " pairs have a TARGET_UNIT but no CONVERSION")

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "harmonizationTable.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
