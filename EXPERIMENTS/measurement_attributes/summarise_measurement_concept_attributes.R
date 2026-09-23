#
# summarise_measurement_concept_attributes.R
#
# Reads EXPERIMENTS/measurement_attributes/output/measurement_concept_attributes.tsv
# (produced by pull_measurement_concept_attributes.R) and writes a markdown summary with:
#   - overall table stats: n rows, missingness per column, and how many concepts are
#     missing ALL 6 core attributes (broken down by vocabulary_id, LOINC vs SNOMED vs other)
#   - one chapter per attribute column (+ is_panel), with a short explanation of what the
#     attribute means, its missingness, number of unique values, and the top 10 most used
#     values
#

#
# --- Libraries --------------------------------------------------------------
#
library(dplyr)
library(readr)
library(tidyr)
library(purrr)

#
# --- Configuration -----------------------------------------------------------
#
pathToInputTSV  <- "EXPERIMENTS/measurement_attributes/output/measurement_concept_attributes.tsv"
pathToSummaryMD <- "EXPERIMENTS/measurement_attributes/output/measurement_concept_attributes_summary.md"

#
# --- Read data ----------------------------------------------------------------
#
# Read every column as character: the attribute columns are free-text concept names and
# is_panel is "TRUE"/"FALSE" text, so there is no numeric/logical type to guess and this
# avoids readr mis-guessing a column's type from its first rows.
data <- readr::read_tsv(pathToInputTSV, col_types = readr::cols(.default = readr::col_character()))

nRows <- nrow(data)
nCols <- ncol(data)

# the 6 core LOINC axes pulled by pull_measurement_concept_attributes.R (excludes
# concept_id / concept_code / concept_name / vocabulary_id / is_panel, which are never "attributes")
coreAttributeColumns <- c(
    "has_component", "has_property", "has_method",
    "has_scale_type", "has_system", "has_time_aspect"
)

# short explanation of what each column means and how it relates to a lab measurement,
# shown at the top of that column's chapter (see EXPERIMENTS/measurement_attributes/ATTRIBUTES.md
# for the full write-up)
columnDescriptions <- c(
    vocabulary_id = "The source vocabulary the concept comes from (e.g. LOINC, SNOMED). LOINC concepts are lab test protocols and are the ones expected to carry the 6 core attributes; SNOMED concepts in the Measurement domain are mostly clinical findings/observables and rarely carry them.",
    is_panel = "Whether the concept is a panel that bundles several individual component tests (e.g. a respiratory pathogen panel) rather than representing one reportable result itself. Panels typically have no values for the 6 core attributes, since those describe the panel's components, not the panel.",
    has_component = "The analyte/substance being measured (e.g. Glucose, Protein, Hemoglobin) — the core identity of what the test measures.",
    has_property = "The kind of quantity reported (e.g. Mass Concentration, Presence, Titer) — what kind of value the result represents, independent of unit.",
    has_method = "The analytical method or instrument principle used (e.g. Test strip, Immunoassay, Automated count). The same component/system/property can still differ by method, and therefore by expected precision or reference range.",
    has_scale_type = "The measurement scale of the result (Qn = Quantitative, Ord = Ordinal, Nom = Nominal, Nar = Narrative, Doc = Document, ...) — tells you whether to expect a number, a category, or free text as the result.",
    has_system = "The specimen or body system the sample was taken from (e.g. Serum or Plasma, Urine, Blood) — the specimen type, critical for not mixing e.g. serum and urine results for the same analyte.",
    has_time_aspect = "The timing of the collection (e.g. Point in time (spot), 24 hours, Timed) — distinguishes a spot sample from a timed/cumulative collection for the same analyte."
)

#
# --- Helpers -------------------------------------------------------------------
#
.formatPct <- function(x) {
    sprintf("%.1f%%", 100 * x)
}

# escape markdown table-breaking characters in a value for display
.escapeForMarkdown <- function(x) {
    x |>
        gsub("\\|", "\\\\|", x = _) |>
        gsub("\\r?\\n", " ", x = _)
}

.missingnessTable <- function(data) {
    tibble::tibble(column = names(data)) |>
        dplyr::mutate(
            n_missing = purrr::map_int(column, ~ sum(is.na(data[[.x]]))),
            pct_missing = n_missing / nrow(data),
            n_non_missing = nrow(data) - n_missing,
            n_unique = purrr::map_int(column, ~ dplyr::n_distinct(data[[.x]], na.rm = TRUE))
        )
}

.top10Table <- function(data, column, n = 10) {
    data |>
        dplyr::filter(!is.na(.data[[column]])) |>
        dplyr::count(.data[[column]], name = "n", sort = TRUE) |>
        dplyr::slice_head(n = n) |>
        dplyr::rename(value = 1) |>
        dplyr::mutate(
            pct_of_non_missing = n / sum(!is.na(data[[column]])),
            value = .escapeForMarkdown(value)
        )
}

.markdownTable <- function(df) {
    header <- paste0("| ", paste(names(df), collapse = " | "), " |")
    sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
    rows <- apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
    paste(c(header, sep, rows), collapse = "\n")
}

#
# --- Overall table stats --------------------------------------------------------
#
overallMissingness <- .missingnessTable(data)

overallMissingnessDisplay <- overallMissingness |>
    dplyr::transmute(
        column,
        n_missing,
        pct_missing = .formatPct(pct_missing),
        n_non_missing,
        n_unique
    )

# concepts missing ALL 6 core attributes, broken down by vocabulary_id (LOINC vs SNOMED vs
# any other vocabulary present in the Measurement domain)
missingAllAttributes <- data |>
    dplyr::mutate(missing_all = dplyr::if_all(dplyr::all_of(coreAttributeColumns), is.na))

nMissingAll <- sum(missingAllAttributes$missing_all)
pctMissingAll <- nMissingAll / nRows

missingAllByVocabulary <- missingAllAttributes |>
    dplyr::group_by(vocabulary_id) |>
    dplyr::summarise(
        n_codes = dplyr::n(),
        all_attributes = sum(missing_all),
        .groups = "drop"
    ) |>
    dplyr::mutate(percentage_of_all_attributes = .formatPct(all_attributes / n_codes)) |>
    dplyr::arrange(dplyr::desc(n_codes))

#
# --- Per-attribute chapters ------------------------------------------------------
#
attributeColumns <- setdiff(names(data), c("concept_id", "concept_code", "concept_name", "vocabulary_id"))

chapters <- purrr::map_chr(attributeColumns, function(colName) {
    stats <- overallMissingness |> dplyr::filter(.data$column == colName)

    top10 <- .top10Table(data, colName) |>
        dplyr::transmute(
            value,
            n,
            pct_of_non_missing = .formatPct(pct_of_non_missing)
        )

    paste0(
        "## `", colName, "`\n\n",
        columnDescriptions[[colName]], "\n\n",
        "- Missing: ", stats$n_missing, " / ", nRows, " (", .formatPct(stats$pct_missing), ")\n",
        "- Non-missing: ", stats$n_non_missing, "\n",
        "- Unique values: ", stats$n_unique, "\n\n",
        "**Top ", nrow(top10), " most used values:**\n\n",
        .markdownTable(top10), "\n"
    )
})

#
# --- Assemble markdown ------------------------------------------------------------
#
md <- paste0(
    "# Measurement concept attributes: data summary\n\n",
    "Summary of `", pathToInputTSV, "`, generated by `summarise_measurement_concept_attributes.R`.\n\n",
    "## Overall table stats\n\n",
    "- Rows (concepts): ", nRows, "\n",
    "- Columns: ", nCols, "\n\n",
    "**Missingness per column:**\n\n",
    .markdownTable(overallMissingnessDisplay), "\n\n",
    "**Concepts missing all 6 core attributes** (`", paste(coreAttributeColumns, collapse = "`, `"), "`):\n\n",
    "- ", nMissingAll, " / ", nRows, " (", .formatPct(pctMissingAll), ")\n\n",
    "By vocabulary — total codes, how many are missing all 6 core attributes, and what percentage that is:\n\n",
    .markdownTable(missingAllByVocabulary), "\n\n",
    paste(chapters, collapse = "\n")
)

readr::write_lines(md, pathToSummaryMD)
message("Wrote summary for ", nRows, " rows / ", nCols, " columns to: ", pathToSummaryMD)
