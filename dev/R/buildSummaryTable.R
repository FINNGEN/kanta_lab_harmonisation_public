.summaryTable <- function(summary, devMode = FALSE, localMode = TRUE) {
    summary |> checkmate::assert_tibble()

    # Define color mapping for test outcomes
    outcome_color_map <- c(
        "NA" = "#D3D3D3", # light gray
        "N" = "#808080", # medium-dark gray
        "A" = "#CD853F", # orange-brown (peru)
        "AA" = "#DEB887", # light orange/beige (burlywood)
        "L" = "#9370DB", # medium purple
        "LL" = "#DDA0DD", # light purple (plum)
        "H" = "#DC143C", # red (crimson)
        "HH" = "#8B0000" # dark red/maroon
    )

    valueSource_color_map <- c(
        "Missing" = "#D3D3D3",
        "Extracted" = "#808080",
        "Source" = "#0000FF"
    )

    if (devMode == TRUE) {
        summary <- summary |>
            dplyr::sample_n(size = 100)
    }

    # select local or remote columns
    if (localMode == TRUE) {
        summary <- summary |>
            dplyr::rename(
                OMOP_CONCEPT_ID = local_OMOP_CONCEPT_ID,
                OMOP_CONCEPT_NAME = local_OMOP_CONCEPT_NAME,
                OMOP_QUANTITY = local_OMOP_QUANTITY,
                MEASUREMENT_UNIT = local_MEASUREMENT_UNIT,
                MEASUREMENT_UNIT_HARMONIZED = local_MEASUREMENT_UNIT_HARMONIZED,
                CONVERSION_FACTOR = local_CONVERSION_FACTOR,
                decile_MEASUREMENT_VALUE_HARMONIZED = local_decile_MEASUREMENT_VALUE_HARMONIZED
            )
    } else {
        summary <- summary |>
            dplyr::rename(
                OMOP_CONCEPT_ID = remote_OMOP_CONCEPT_ID,
                OMOP_CONCEPT_NAME = local_OMOP_CONCEPT_NAME,
                OMOP_QUANTITY = remote_OMOP_QUANTITY,
                MEASUREMENT_UNIT = remote_MEASUREMENT_UNIT,
                MEASUREMENT_UNIT_HARMONIZED = remote_MEASUREMENT_UNIT_HARMONIZED,
                CONVERSION_FACTOR = remote_CONVERSION_FACTOR,
                decile_MEASUREMENT_VALUE_HARMONIZED = remote_decile_MEASUREMENT_VALUE_HARMONIZED
            )
    }

    toplot <- summary |>
        dplyr::mutate(
            tmpMU = dplyr::coalesce(MEASUREMENT_UNIT, ""),
            tmpMUPrefix = dplyr::coalesce(MEASUREMENT_UNIT_PREFIX, ""),
            tmpMUHarmonized = dplyr::coalesce(MEASUREMENT_UNIT_HARMONIZED, ""),
            tmpMUHarmonizedTarget = dplyr::coalesce(local_MEASUREMENT_UNIT_HARMONIZED_target, ""),
            valueUnitChange = paste0(
                dplyr::if_else(tmpMUHarmonized == tmpMUHarmonizedTarget, "", '<span style="color: red;">MISSING:</span> <br>'),
                dplyr::if_else(tmpMU == tmpMUHarmonizedTarget, "", paste0(tmpMU, " -> ", tmpMUHarmonizedTarget, "<br>")),
                dplyr::if_else(is.na(CONVERSION_FACTOR), "", paste0("*", CONVERSION_FACTOR))
            ),
            valueUnitChange = dplyr::if_else(is.na(decile_MEASUREMENT_VALUE_HARMONIZED), "", valueUnitChange),
            unitChange = dplyr::if_else(tmpMUPrefix == tmpMU, "", paste0(tmpMUPrefix, " -> ", tmpMU)),
        ) |>
        dplyr::select(-tmpMU, -tmpMUHarmonized, -tmpMUPrefix, -tmpMUHarmonizedTarget    ) |>
        dplyr::transmute(
            status = status,
            conceptId = OMOP_CONCEPT_ID,
            conceptName = OMOP_CONCEPT_NAME,
            omopQuantity = OMOP_QUANTITY,
            unitChange = unitChange,
            testId = paste0(TEST_NAME, " [", dplyr::if_else(is.na(MEASUREMENT_UNIT), "", MEASUREMENT_UNIT), "]", dplyr::if_else(IS_EXTRACTED, " (Extracted)", "")),
            nPeople = n_subjects,
            nRecords = n_records,
            dValuesSource = distribution_values,
            dOutcomes = distribution_outcomes,
            dMeasurementValue = purrr::map_chr(decile_MEASUREMENT_VALUE, .decileText),
            ksTest = ksTest,
            valueUnitChange = valueUnitChange,
            dMeasurementValueHarmonized = purrr::map_chr(decile_MEASUREMENT_VALUE_HARMONIZED, .decileText),
            ksTestHarmonized = ksTestHarmonized,
            message = message,
            differences = differences
        ) |>
        dplyr::arrange(dplyr::desc(nRecords))


    plot <- toplot |>
        reactable::reactable(
            filterable = TRUE,
            sortable = TRUE,
            searchable = TRUE,
            defaultPageSize = 15,
            showPageSizeOptions = TRUE,
            resizable = TRUE,
            columns = list(
                status = reactable::colDef(
                    name = "Status",
                    minWidth = 100,
                    cell = function(value) {
                        .renderStatus(value)
                    }
                ),
                conceptId = reactable::colDef(
                    name = "OMOP Concept ID",
                    maxWidth = 100
                ),
                conceptName = reactable::colDef(
                    name = "Omop Name",
                    filterMethod = .regexFilter
                ),
                omopQuantity = reactable::colDef(
                    name = "Omop Quantity",
                    maxWidth = 150
                ),
                unitChange = reactable::colDef(
                    name = "Unit change",
                    maxWidth = 100
                ),
                testId = reactable::colDef(
                    name = "TestCode [Unit]",
                    maxWidth = 150,
                    filterMethod = .regexFilter
                ),
                nPeople = reactable::colDef(
                    name = "N people",
                    maxWidth = 80,
                    filterMethod = .numericRangeFilter
                ),
                nRecords = reactable::colDef(
                    name = "N records",
                    maxWidth = 80,
                    filterMethod = .numericRangeFilter
                ),
                dValuesSource = reactable::colDef(
                    name = "Value source",
                    html = TRUE,
                    cell = function(value) {
                        .proportionBarHTML(value, color_map = valueSource_color_map)
                    },
                    minWidth = 50,
                    maxWidth = 100
                ),
                dOutcomes = reactable::colDef(
                    name = "Test outcome",
                    html = TRUE,
                    cell = function(value) {
                        .proportionBarHTML(value, color_map = outcome_color_map)
                    },
                    minWidth = 50,
                    maxWidth = 100
                ),
                dMeasurementValue = reactable::colDef(
                    name = "Decile of measurement value",
                    minWidth = 150
                ),
                ksTest = reactable::colDef(
                    name = "KS(mpl)",
                    html = TRUE,
                    minWidth = 50,
                    cell = function(value) {
                        .renderKSTest(value)
                    },
                    filterMethod = .numericRangeFilter
                ),
                valueUnitChange = reactable::colDef(
                    name = "Value unit<br>harmonisation",
                    html = TRUE,
                    minWidth = 50
                ),
                dMeasurementValueHarmonized = reactable::colDef(
                    name = "Decile of harmonized measurement value",
                    minWidth = 150
                ),
                ksTestHarmonized = reactable::colDef(
                    name = "KS(mpl) harmonized",
                    html = TRUE,
                    minWidth = 50,
                    cell = function(value) {
                        .renderKSTest(value)
                    },
                    filterMethod = .numericRangeFilter
                ),
                message = reactable::colDef(
                    name = "Message",
                    minWidth = 150
                ),
                differences = reactable::colDef(
                    name = "Differences",
                    html = TRUE,
                    minWidth = 150
                )
            )
        )


    plot_with_tooltips <- htmltools::tagList(
        .proportionBarTooltipStyle,
        .proportionBarTooltipScript,
        plot
    )

    return(plot_with_tooltips)
}

.renderStatus <- function(status) {
    checkmate::assert_character(status, len = 1)
    checkmate::assert_choice(status, c("APPROVED", "IGNORED", "UNCHECKED", "FLAGGED", "INVALID_TARGET", "NOT-FOUND"))

    statusToColor <- c(
        "APPROVED" = "#74de74",
        "IGNORED" = "#7b7b7b",
        "UNCHECKED" = "#cccccc",
        "FLAGGED" = "#d75e5e",
        "INVALID_TARGET" = "#fffecc",
        "NOT-FOUND" = "#deb074"
    )

    color <- statusToColor[[status]]

    htmltools::span(
        style = paste0(
            "display: inline-block; padding: 2px 8px; border-radius: 4px; font-weight: bold; ",
            "color: ", color, ";"
        ),
        status
    )
}

.renderKSTest <- function(ksTest) {
    if (is.null(ksTest)) {
        return(htmltools::span(style = "color: #999; font-style: italic;", "NA"))
    }
    ks <- ksTest |>
        dplyr::pull(KS) |>
        round(digits = 2)
    pValue <- ksTest |> dplyr::pull(pValue)
    mplog10pValue <- -log10(pValue) |>
        round(digits = 2)
    bg_color <- ""
    if (!is.null(ks)) {
        if (ks > 0.5) {
            bg_color <- "#ffcccc" # red
        } else if (ks > 0.2) {
            bg_color <- "#ffffcc" # yellow
        } else {
            bg_color <- "#ccffcc" # green
        }
    }
    htmltools::HTML(
        htmltools::HTML(
            paste0(
                '<span style="padding:2px 4px; border-radius:4px;background-color: ', bg_color, ';">',
                "", ks, "<br>(", mplog10pValue, ")",
                "</span>"
            )
        )
    )
}

.decileText <- function(decileTibble) {
    if (is.null(decileTibble) || (tibble::is_tibble(decileTibble) && nrow(decileTibble) == 0)) {
        return("")
    }

    values <- decileTibble |>
        dplyr::arrange(decile) |>
        dplyr::pull(value) |>
        round(digits = 2) |>
        paste0(collapse = ", ")

    paste0("[ ", values, " ]")
}

.proportionBarHTML <- function(proportionsTibble, color_map) {
    # Handle NULL or empty tibble
    if (is.null(proportionsTibble) || (tibble::is_tibble(proportionsTibble) && nrow(proportionsTibble) == 0)) {
        return(htmltools::HTML('<div style="height: 28px;"></div>'))
    }

    # Validate tibble has required columns
    if (!all(c("value", "n") %in% names(proportionsTibble))) {
        stop("Tibble must have columns 'value' and 'n'")
    }

    # Validate color_map is provided
    if (missing(color_map) || is.null(color_map)) {
        stop("color_map must be provided")
    }

    # Define sort order from color map keys
    outcome_order <- names(color_map)

    # Sort outcomes according to predefined order
    proportionsTibble <- proportionsTibble |>
        dplyr::mutate(
            sort_order = dplyr::case_when(
                value %in% outcome_order ~ match(value, outcome_order),
                TRUE ~ Inf
            )
        ) |>
        dplyr::arrange(sort_order) |>
        dplyr::select(-sort_order)

    # Extract category names and counts (now sorted)
    category_names <- proportionsTibble$value
    counts <- proportionsTibble$n

    # Calculate total and proportions
    total_count <- sum(counts, na.rm = TRUE)

    # Handle zero sum
    if (total_count == 0) {
        total_count <- 1
    }

    props <- counts / total_count
    n_categories <- length(category_names)

    # Assign colors based on category names from color_map
    colors <- character(n_categories)
    for (i in seq_len(n_categories)) {
        category_name <- category_names[i]
        if (category_name %in% names(color_map)) {
            colors[i] <- color_map[[category_name]]
        } else {
            # Fallback color for unknown categories
            colors[i] <- "#CCCCCC"
        }
    }

    # Build gradient stops for the bar
    bar_stops <- character(n_categories)
    cumulative_pct <- 0
    for (i in seq_len(n_categories)) {
        pct <- props[i] * 100
        bar_stops[i] <- paste0(colors[i], " ", cumulative_pct, "%, ", colors[i], " ", cumulative_pct + pct, "%")
        cumulative_pct <- cumulative_pct + pct
    }
    bar_gradient <- paste(bar_stops, collapse = ", ")

    # Prepare tooltip data with outcome, percentage, and count
    tooltip_data <- purrr::map_chr(
        seq_len(n_categories),
        function(i) {
            paste0(
                '{"outcome":"', category_names[i], '","pRecords":', round(props[i] * 100, 2), ',"nRecords":', counts[i], ',"color":"', colors[i], '"}'
            )
        }
    )
    tooltip_data_json <- paste0("[", paste(tooltip_data, collapse = ","), "]")

    # Create HTML for one bar with tooltip data
    # Escape quotes in JSON for HTML attribute
    tooltip_data_json_escaped <- gsub('"', "&quot;", tooltip_data_json, fixed = TRUE)
    htmltools::HTML(paste0(
        '<div class="proportion-bar-tooltip" data-tooltip-table="', tooltip_data_json_escaped, '" style="display: flex; flex-direction: column; gap: 4px; width: 100%; overflow: visible; position: relative;">',
        '<div style="height: 12px; width: 100%; background: linear-gradient(to right, ', bar_gradient, '); border-radius: 2px; position: relative; overflow: visible;"></div>',
        "</div>"
    ))
}


# CSS and JavaScript for tooltips that escape cell boundaries
.proportionBarTooltipStyle <- htmltools::tags$style(
    ".proportion-bar-tooltip {
        cursor: pointer;
    }
    .proportion-tooltip {
        position: fixed;
        padding: 6px 10px;
        background-color: rgba(0, 0, 0, 0.9);
        color: white;
        border-radius: 4px;
        font-size: 12px;
        z-index: 99999;
        pointer-events: none;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
        display: none;
    }
    .proportion-tooltip.above::before {
        content: '';
        position: absolute;
        top: -5px;
        left: 50%;
        transform: translateX(-50%);
        width: 0;
        height: 0;
        border: 5px solid transparent;
        border-bottom-color: rgba(0, 0, 0, 0.9);
    }
    .proportion-tooltip.below::before {
        content: '';
        position: absolute;
        bottom: -5px;
        left: 50%;
        transform: translateX(-50%);
        width: 0;
        height: 0;
        border: 5px solid transparent;
        border-top-color: rgba(0, 0, 0, 0.9);
    }"
)

# JavaScript to handle tooltip positioning
.proportionBarTooltipScript <- htmltools::tags$script(
    htmltools::HTML('
    (function() {
        let tooltip = null;

        function createTooltip() {
            if (!tooltip) {
                tooltip = document.createElement("div");
                tooltip.className = "proportion-tooltip";
                document.body.appendChild(tooltip);
            }
            return tooltip;
        }

        function showSimpleTableTooltip(element, simpleData) {
            const tip = createTooltip();

            // Parse JSON data
            let data;
            try {
                data = JSON.parse(simpleData);
            } catch (e) {
                return;
            }

            // Create HTML table with 2 columns
            let tableHTML = "<table style=\\"border-collapse: collapse; width: 100%;\\"><thead><tr><th style=\\"padding: 4px 8px; text-align: right; border-bottom: 1px solid rgba(255,255,255,0.3);\\">% Cases</th><th style=\\"padding: 4px 8px; text-align: right; border-bottom: 1px solid rgba(255,255,255,0.3);\\">% Controls</th></tr></thead><tbody><tr><td style=\\"padding: 4px 8px; text-align: right;\\">" + data.case + "%</td><td style=\\"padding: 4px 8px; text-align: right;\\">" + data.control + "%</td></tr></tbody></table>";

            tip.innerHTML = tableHTML;
            tip.style.display = "block";

            positionTooltip(element, tip);
        }

        function showTableTooltip(element, tableData) {
            const tip = createTooltip();

            // Parse JSON data
            let data;
            try {
                data = JSON.parse(tableData);
            } catch (e) {
                return;
            }

            // Create HTML table with 3 columns: Outcome, pRecords, and nRecords
            let tableHTML = "<table style=\\"border-collapse: collapse; width: 100%;\\"><thead><tr><th style=\\"padding: 4px 8px; text-align: left; border-bottom: 1px solid rgba(255,255,255,0.3);\\">Outcome</th><th style=\\"padding: 4px 8px; text-align: right; border-bottom: 1px solid rgba(255,255,255,0.3);\\">pRecords</th><th style=\\"padding: 4px 8px; text-align: right; border-bottom: 1px solid rgba(255,255,255,0.3);\\">nRecords</th></tr></thead><tbody>";

            for (let i = 0; i < data.length; i++) {
                const outcomeColor = data[i].color || "#ffffff";
                tableHTML += "<tr><td style=\\"padding: 4px 8px; color: " + outcomeColor + ";\\">" + data[i].outcome + "</td><td style=\\"padding: 4px 8px; text-align: right;\\">" + data[i].pRecords + "%</td><td style=\\"padding: 4px 8px; text-align: right;\\">" + data[i].nRecords + "</td></tr>";
            }

            tableHTML += "</tbody></table>";
            tip.innerHTML = tableHTML;
            tip.style.display = "block";

            positionTooltip(element, tip);
        }

        function showBoxplotTooltip(element, boxplotData) {
            const tip = createTooltip();

            // Parse JSON data
            let data;
            try {
                data = JSON.parse(boxplotData);
            } catch (e) {
                return;
            }

            // Create HTML table with measure, Cases, Controls columns
            let tableHTML = "<table style=\\"border-collapse: collapse; width: 100%;\\"><thead><tr><th style=\\"padding: 4px 8px; text-align: left; border-bottom: 1px solid rgba(255,255,255,0.3);\\">Measure</th><th style=\\"padding: 4px 8px; text-align: right; border-bottom: 1px solid rgba(255,255,255,0.3);\\">Cases</th><th style=\\"padding: 4px 8px; text-align: right; border-bottom: 1px solid rgba(255,255,255,0.3);\\">Controls</th></tr></thead><tbody>";

            for (let i = 0; i < data.length; i++) {
                tableHTML += "<tr><td style=\\"padding: 4px 8px;\\">" + data[i].measure + "</td><td style=\\"padding: 4px 8px; text-align: right;\\">" + data[i].case + "</td><td style=\\"padding: 4px 8px; text-align: right;\\">" + data[i].control + "</td></tr>";
            }

            tableHTML += "</tbody></table>";
            tip.innerHTML = tableHTML;
            tip.style.display = "block";

            positionTooltip(element, tip);
        }

        function positionTooltip(element, tip) {
            const rect = element.getBoundingClientRect();
            const tipRect = tip.getBoundingClientRect();

            // Position above the bar, centered horizontally
            let top = rect.top - tipRect.height - 8;
            let left = rect.left + (rect.width / 2) - (tipRect.width / 2);

            // Adjust if tooltip would go off screen
            if (top < 0) {
                // Position below instead
                top = rect.bottom + 8;
                tip.classList.remove("above");
                tip.classList.add("below");
            } else {
                tip.classList.remove("below");
                tip.classList.add("above");
            }

            // Adjust horizontal position if off screen
            if (left < 0) {
                left = 8;
            } else if (left + tipRect.width > window.innerWidth) {
                left = window.innerWidth - tipRect.width - 8;
            }

            tip.style.top = top + "px";
            tip.style.left = left + "px";
        }

        function hideTooltip() {
            if (tooltip) {
                tooltip.style.display = "none";
            }
        }

        // Use event delegation for better performance
        document.addEventListener("mouseover", function(e) {
            const target = e.target.closest(".proportion-bar-tooltip");
            if (target) {
                const boxplotData = target.getAttribute("data-tooltip-boxplot");
                if (boxplotData !== null) {
                    showBoxplotTooltip(target, boxplotData);
                } else {
                    const simpleData = target.getAttribute("data-tooltip-simple");
                    if (simpleData !== null) {
                        showSimpleTableTooltip(target, simpleData);
                    } else {
                        const tableData = target.getAttribute("data-tooltip-table");
                        if (tableData !== null) {
                            showTableTooltip(target, tableData);
                        }
                    }
                }
            }
        });

        document.addEventListener("mouseout", function(e) {
            const target = e.target.closest(".proportion-bar-tooltip");
            if (target) {
                hideTooltip();
            }
        });

        document.addEventListener("mousemove", function(e) {
            const target = e.target.closest(".proportion-bar-tooltip");
            if (target && tooltip && tooltip.style.display === "block") {
                const boxplotData = target.getAttribute("data-tooltip-boxplot");
                if (boxplotData !== null) {
                    showBoxplotTooltip(target, boxplotData);
                } else {
                    const simpleData = target.getAttribute("data-tooltip-simple");
                    if (simpleData !== null) {
                        showSimpleTableTooltip(target, simpleData);
                    } else {
                        const tableData = target.getAttribute("data-tooltip-table");
                        if (tableData !== null) {
                            showTableTooltip(target, tableData);
                        }
                    }
                }
            }
        });
    })();
    ')
)

# JS function to filter by regular expression
.regexFilter <- htmlwidgets::JS(
    "function(rows, columnId, filterValue) {
    try {
      const re = new RegExp(filterValue, 'i');
      return rows.filter(function(row) {
        return re.test(row.values[columnId]);
      });
    } catch (e) {
      return rows;
    }
  }"
)


# JS function to filter numeric values in the reactable columns.
# Supports ranges (e.g., -2--0.5, 1-4), comparison operators (>=, <=, >, <, ==), and bare numbers.
# Returns a list of rows that match the filter.
.numericRangeFilter <- htmlwidgets::JS(
    "function(rows, columnId, filterValue) {
      if (!filterValue) return rows;
      const val = filterValue.trim().toLowerCase();
      if (!val) return rows;

      return rows.filter(row => {
        let rawValue = row.values[columnId];

        //  check if KS is missing (Null, Undefined, or Empty Strings)
        const isMissing = (
            rawValue === null ||
            rawValue === undefined ||
            rawValue === '' ||
            (typeof rawValue === 'object' && (rawValue.KS === undefined || rawValue.KS === null))
        );

        // If user types 'null' or 'na', show ONLY the missing rows
        if (val === 'null' || val === 'na') {
            return isMissing;
        }

        // If data is missing and user is typing a numeric filter, hide it
        if (isMissing) return false;

        // Extract the numeric value for comparison
        let v = (typeof rawValue === 'object') ? rawValue.KS : parseFloat(rawValue);
        if (Number.isNaN(v)) return false;

        // Numeric Range/Operator Logic
        const cleanFilter = val.replace(/\\s+/g, '');
        const EPS = 1e-9;
        const NUM = '-?\\\\d+(?:\\\\.\\\\d+)?(?:[eE][+-]?\\\\d+)?';

        let m;
        // Range: e.g. 0.1-0.5
        if (m = cleanFilter.match(new RegExp(`^(${NUM})-(${NUM})$`))) {
          let min = parseFloat(m[1]), max = parseFloat(m[2]);
          if (min > max) [min, max] = [max, min];
          return v > min - EPS && v < max + EPS;
        }
        // Comparison Operators
        if (m = cleanFilter.match(new RegExp(`^>=(${NUM})$`))) return v >= parseFloat(m[1]) - EPS;
        if (m = cleanFilter.match(new RegExp(`^<=(${NUM})$`))) return v <= parseFloat(m[1]) + EPS;
        if (m = cleanFilter.match(new RegExp(`^>(${NUM})$`)))  return v > parseFloat(m[1]) + EPS;
        if (m = cleanFilter.match(new RegExp(`^<(${NUM})$`)))  return v < parseFloat(m[1]) - EPS;
        if (m = cleanFilter.match(new RegExp(`^=(${NUM})$`)) || cleanFilter.match(new RegExp(`^${NUM}$`))) {
           return Math.abs(v - parseFloat(m[1] || m[0])) < EPS;
        }

        return true;
      });
  }"
)
