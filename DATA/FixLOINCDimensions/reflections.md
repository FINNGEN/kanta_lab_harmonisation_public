# Group 21

In this group, corrections were primarily made to the `has_component` and `has_property` axes. The near-miss paraphrase `Soluble transferrin receptor` was consistently corrected to the precise OMOP term `Transferrin receptor.soluble`, supported by Finnish test names like `p-transferriinireseptori,liukoinen` where `liukoinen` means soluble (e.g., row 166). The most frequent correction was capitalizing `Mass Fraction` to the correct OMOP form `Mass fraction`. This was guided by units (`%`, `osuus`) or decile values that clearly represented a ratio/fraction (e.g., 0.08-0.41 in row 158). The `has_system` axis values (`Plasma`, `Serum`) were already correct and aligned with the national prefixes (`P-`, `S-`, etc.). The candidate lists were effective and provided all necessary terms for this group.

# Group 126

This group was straightforward, focusing almost entirely on glucose measurements. The main correction was for capitalization: changing `Mass Fraction` to the correct OMOP term `Mass fraction` for rows 1710 and 1711, which represent 'time in range' and 'time below range' metrics from continuous glucose monitoring, correctly identified as a property of `Mass fraction` given the '%' unit. The previous pass correctly distinguished between laboratory glucose tests (where `has_system` is appropriately left blank due to lack of a specimen prefix like `S-` or `P-`) and point-of-care tests (`-vieri`), which were correctly assigned `Blood capillary` as the system and `Test strip` as the method. The candidate lists were sufficient and accurate for this group.

