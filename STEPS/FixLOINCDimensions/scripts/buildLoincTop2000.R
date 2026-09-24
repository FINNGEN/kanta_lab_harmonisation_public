#
# Builds the LOINC Top 2000 reference table.
#
# Regenstrief publishes the "LOINC Top 2000+ Lab Observations": the ~2000 LOINC
# codes that cover about 99.8% of the test volume of three large laboratory
# organisations, offered as the recommended target set for anyone mapping local
# lab codes to LOINC. Two editions exist; this builder takes the **SI** one,
# which uses the molar/SI units Finland reports in, rather than the US edition
# whose chemistry codes are mass-based (US rank 1 is Creatinine [Mass/volume],
# SI rank 1 is Creatinine [Moles/volume] -- the Finnish test).
#
# Being on this list is the strongest available signal that a LOINC concept is
# the one a laboratory is *supposed* to map to. FixLOINCDimensions flags its
# Hecate candidates with it, so a model choosing between several concepts that
# fit the evidence equally well can prefer the recommended one.
#
# Each LOINC code is resolved to its OMOP concept_id through
# measurement_concept_attributes.tsv on concept_code, and the OMOP concept_name
# is carried alongside the list's own Long Common Name: the list is from LOINC
# 1.6 and some names have been revised since, so the two can differ, and the
# OMOP spelling is the one the rest of this pipeline must match.
#
# A code that resolves to no OMOP Measurement concept is kept with an empty
# concept_id rather than dropped -- it is still on the recommended list, and
# dropping it would silently overstate the list's OMOP coverage.
#
# This is a reference-table builder, not part of the step's per-run action:
# it writes into DATA/SourceLabelingData/ alongside the other curated lookup
# tables and only needs re-running when the LOINC list or the OMOP vocabulary
# snapshot changes.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
top2000File <- args[1]
omopAttributesFile <- args[2]
outFile <- args[3]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  top2000File = ", top2000File)
ParallelLogger::logInfo("  omopAttributesFile = ", omopAttributesFile)
ParallelLogger::logInfo("  outFile = ", outFile)

#
# --- Input -------------------------------------------------------------
#
# Published by Regenstrief, i.e. from outside this project: readr's default
# missing-value handling applies. A real comma-separated CSV.
top2000 <- readr::read_csv(top2000File, col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(top2000), " rows from ", top2000File)

# na = "" per development/STYLE.md: written by this project.
omopAttributes <- readr::read_tsv(
  omopAttributesFile, na = "",
  col_types = readr::cols(.default = readr::col_character())
)
ParallelLogger::logInfo("Read ", nrow(omopAttributes), " rows from ", omopAttributesFile)

#
# --- Action -------------------------------------------------------------
#
# One OMOP row per LOINC code. The Measurement-domain extract holds a code once,
# but distinct() guards the join against a duplicate silently multiplying rows.
omopByCode <- omopAttributes |>
  dplyr::filter(.data$vocabulary_id == "LOINC", !is.na(.data$concept_code)) |>
  dplyr::distinct(concept_code, .keep_all = TRUE) |>
  dplyr::select(concept_code, concept_id, omop_concept_name = concept_name)

result <- top2000 |>
  dplyr::transmute(
    rank = suppressWarnings(as.integer(.data$Rank)),
    loinc_code = .data$`LOINC #`,
    loinc_long_common_name = .data$`Long Common Name`,
    loinc_class = .data$CLASS
  ) |>
  dplyr::left_join(omopByCode, by = c("loinc_code" = "concept_code")) |>
  dplyr::select(rank, loinc_code, concept_id, omop_concept_name,
                loinc_long_common_name, loinc_class) |>
  dplyr::arrange(.data$rank)

nResolved <- sum(!is.na(result$concept_id))
nRenamed <- sum(!is.na(result$concept_id) &
                  result$omop_concept_name != result$loinc_long_common_name)
ParallelLogger::logInfo(nResolved, " / ", nrow(result),
                        " LOINC codes resolved to an OMOP Measurement concept")
ParallelLogger::logInfo(nRenamed, " of those have been renamed in OMOP since LOINC 1.6")

#
# --- Output -------------------------------------------------------------
#
dir.create(dirname(outFile), recursive = TRUE, showWarnings = FALSE)
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
