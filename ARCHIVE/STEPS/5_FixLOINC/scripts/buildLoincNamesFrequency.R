#
# Builds the LOINC name frequency reference table.
#
# Joins the already-curated Finnish code -> OMOP mappings
# (ReferenceMappings/lab_data_summary.csv) to the OMOP vocabulary
# (0_GetMeasurementOmopData/measurement_concept_attributes.tsv) on concept_id,
# then counts how often each LOINC CONCEPT is actually used in Finnish lab
# data -- by number of local codes and by number of records.
#
# The result is a prior over whole LOINC concepts, and it serves two purposes:
#
#   1. 4_FindLOINC embeds its head as worked examples, so the model can
#      see the exact Long Common Name spelling of the concepts Finland really
#      uses before it writes its own guess.
#   2. 5_FixLOINC attaches these counts to its Hecate candidates, so
#      when several real LOINC concepts fit a row equally well, the model can
#      break the tie on established Finnish usage instead of guessing.
#
# Only status == "APPROVED" rows are counted. Those are the human-verified
# mappings; UNCHECKED ones would add volume but also feed unverified (possibly
# wrong) concept assignments into what is meant to be a trustworthy prior.
#
# The concept NAME is taken from the OMOP vocabulary, not from the reference
# file's own OMOP_CONCEPT_NAME column: the vocabulary is the authority on how a
# concept is spelled today, and the spelling is the whole point of the table.
#
# This is a reference-table builder, not part of the step's per-run action:
# it writes into DATA/SourceLabelingData/ alongside the other curated lookup
# tables (code_prefixes.tsv, code_suffixes.tsv) and only needs re-running when
# the reference mappings or the OMOP vocabulary snapshot change.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
referenceFile <- args[1]
omopAttributesFile <- args[2]
outFile <- args[3]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  referenceFile = ", referenceFile)
ParallelLogger::logInfo("  omopAttributesFile = ", omopAttributesFile)
ParallelLogger::logInfo("  outFile = ", outFile)

#
# --- Input -------------------------------------------------------------
#
# lab_data_summary.csv comes from outside this project, so it keeps readr's
# default missing-value handling. Despite the .csv name it is tab-separated.
reference <- readr::read_tsv(referenceFile, col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(reference), " rows from ", referenceFile)

# na = "" per development/STYLE.md: written by this project.
omopAttributes <- readr::read_tsv(
  omopAttributesFile, na = "",
  col_types = readr::cols(.default = readr::col_character())
)
ParallelLogger::logInfo("Read ", nrow(omopAttributes), " rows from ", omopAttributesFile)

#
# --- Action -------------------------------------------------------------
#
approved <- reference |>
  dplyr::filter(
    .data$status == "APPROVED",
    !is.na(.data$OMOP_CONCEPT_ID), .data$OMOP_CONCEPT_ID != "", .data$OMOP_CONCEPT_ID != "NA"
  ) |>
  dplyr::mutate(n_records_num = suppressWarnings(as.numeric(.data$n_records)))
ParallelLogger::logInfo("Kept ", nrow(approved), " APPROVED reference rows with a concept_id (",
                        dplyr::n_distinct(approved$OMOP_CONCEPT_ID), " distinct concepts)")

joined <- approved |>
  dplyr::inner_join(
    omopAttributes |> dplyr::select(concept_id, concept_name, vocabulary_id),
    by = c("OMOP_CONCEPT_ID" = "concept_id")
  )
nDropped <- nrow(approved) - nrow(joined)
if (nDropped > 0) {
  ParallelLogger::logWarn(nDropped, " APPROVED row(s) reference a concept_id that is not in the ",
                          "OMOP attributes table; dropping them")
}

result <- joined |>
  dplyr::group_by(concept_id = .data$OMOP_CONCEPT_ID) |>
  dplyr::summarise(
    concept_name = dplyr::first(.data$concept_name),
    vocabulary_id = dplyr::first(.data$vocabulary_id),
    n_codes = dplyr::n(),
    n_events = sum(.data$n_records_num, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::arrange(dplyr::desc(.data$n_events), dplyr::desc(.data$n_codes)) |>
  dplyr::select(concept_id, concept_name, vocabulary_id, n_codes, n_events)

ParallelLogger::logInfo("Counted ", nrow(result), " distinct concepts covering ",
                        format(sum(result$n_events), big.mark = ","), " records")
ParallelLogger::logInfo("  the 100 most used cover ",
                        sprintf("%.1f%%", 100 * sum(utils::head(result$n_events, 100)) / sum(result$n_events)),
                        " of those records")

#
# --- Output -------------------------------------------------------------
#
dir.create(dirname(outFile), recursive = TRUE, showWarnings = FALSE)
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
